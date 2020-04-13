/** \file Octree.cuh
* \brief This file contains everything related to the CUDA Octree
*/
#ifndef OCTREE_CUH
#define OCTREE_CUH

#include "common_includes.h"
#include <thrust/sort.h>
#include <thrust/pair.h>
#include <thrust/unique.h>
#include <thrust/gather.h>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/device_vector.h>
#include <thrust/scan.h>
#include <thrust/device_ptr.h>
#include <thrust/copy.h>
#include <cublas_v2.h>
#include <cusolverDn.h>

#include "tinyply.h"

namespace ssrlcv{
  /**
  * \ingroup trees
  */
  /**
  * \brief data parallel octree
  *
  * \detail this class is used for quick near neighbor searches
  * as well as a tool for surface reconstruction
  * \todo update with new unity
  */
  class Octree{

  private:

    /*
    OCTREE GENERATION PREREQUISITE FUNCTIONS
    */
    void createFinestNodes();

    /*
    FILL OCTREE METHODS
    */
    void fillInCoarserDepths();//also allocates/copies deviceIndices
    void fillNeighborhoods();

    /*
    OCTREE UNIT TESTING
    */
    void checkForGeneralNodeErrors();

  public:

    /** \brief most basic part of octree*/
    struct Node{
      uchar3 color;
      int pointIndex;
      float3 center;
      float width;
      int key;
      int numPoints;
      int depth;
      int numFinestChildren;
      int finestChildIndex;
      int parent;
      int children[8];
      int neighbors[27];
      int edges[12];
      int vertices[8];
      int faces[6];
      __device__ __host__ Node();
    };
    /** \brief holds cubic vertex data */
    struct Vertex{
      uchar3 color;
      float3 coord;
      int nodes[8];
      int depth;
      __device__ __host__ Vertex();
    };
    /** \brief holds cubic edge data */
    struct Edge{
      uchar3 color;
      int v1;
      int v2;
      int depth;
      int nodes[4];
      __device__ __host__ Edge();
    };
    /** \brief hold cubic face data */
    struct Face{
      uchar3 color;
      int e1;
      int e2;
      int e3;
      int e4;
      int depth;
      int nodes[2];
      __device__ __host__ Face();
    };

    std::string name;
    std::string pathToFile;

    float3 center;
    float3 min;
    float3 max;
    float width;
    int depth;

    Unity<float3>* points;

    Unity<float3>* normals;

    Unity<Node>* nodes;
    Unity<Vertex>* vertices;
    Unity<Edge>* edges;
    Unity<Face>* faces;

    //length = # points, value = node containing point
    //ie value = index of node point is in
    Unity<unsigned int>* pointNodeIndex;

    //depth index carriers
    Unity<unsigned int>* nodeDepthIndex;
    Unity<unsigned int>* vertexDepthIndex;
    Unity<unsigned int>* edgeDepthIndex;
    Unity<unsigned int>* faceDepthIndex;

    // =============================================================================================================
    //
    // Constructors and Destructors
    //
    // =============================================================================================================

    Octree();
    ~Octree();

    Octree(std::string pathToFile, int depth);
    Octree(int numfloat3s, float3* points, int depth, bool createVEF);
    Octree(int numfloat3s, float3* points, float deepestWidth, bool createVEF);

    Octree(Unity<float3>* points, int depth, bool createVEF);
    Octree(Unity<float3>* points, float deepestWidth, bool createVEF);

    // =============================================================================================================
    //
    // Octree Host Methods
    //
    // =============================================================================================================

    void computeVertexArray();
    void computeEdgeArray();
    void computeFaceArray();
    void createVEFArrays();

    // =============================================================================================================
    //
    // Normal Caclulation Methods
    //
    // =============================================================================================================

    /**
    * Computes normals for the points within the input points cloud
    * @param minNeighForNorms the minimum number of neighbors to consider for normal calculation
    * @param maxNeighbors the maximum number of neightbors to consider for normal calculation
    */
    void computeNormals(int minNeighForNorms, int maxNeighbors);

    /**
    * Computes normals for the points within the input points cloud
    * @param minNeighForNorms the minimum number of neighbors to consider for normal calculation
    * @param maxNeighbors the maximum number of neightbors to consider for normal calculation
    * @param numCameras the total number of cameras which resulted in the point cloud
    * @param cameraPositions the x,y,z coordinates of the cameras
    */
    void computeNormals(int minNeighForNorms, int maxNeighbors, unsigned int numCameras, float3* cameraPositions);

    /**
    * Computes the average normal of the input points. This is only useful if you can make a "planar" assumption about
    * the input points, that is the points are mostly aligned along a plane. For use in reconstructon filtering should occur
    * before one considers using this method
    * @param minNeighForNorms the minimum number of neighbors to consider for normal calculation
    * @param maxNeighbors the maximum number of neightbors to consider for normal calculation
    * @param numCameras the total number of cameras which resulted in the point cloud
    * @param cameraPositions the x,y,z coordinates of the cameras
    */
    void computeAverageNormal(int minNeighForNorms, int maxNeighbors, unsigned int numCameras, float3* cameraPositions);


    // =============================================================================================================
    //
    // PLY writers
    //
    // =============================================================================================================

    void writeVertexPLY(bool binary = false);
    void writeEdgePLY(bool binary = false);
    void writeCenterPLY(bool binary = false);
    void writepointsPLY(bool binary = false);
    void writeNormalPLY(bool binary = false);
    void writeDepthPLY(int d, bool binary = false);
  };

  static const int3 coordPlacementIdentity_host[8] {
    {-1,-1,-1},
    {-1,-1,1},
    {-1,1,-1},
    {-1,1,1},
    {1,-1,-1},
    {1,-1,1},
    {1,1,-1},
    {1,1,1}
  };
  static const int2 vertexEdgeIdentity_host[12] {
    {0,1},
    {0,2},
    {1,3},
    {2,3},
    {0,4},
    {1,5},
    {2,6},
    {3,7},
    {4,5},
    {4,6},
    {5,7},
    {6,7}
  };
  static const int4 vertexFaceIdentity_host[6] {
    {0,1,2,3},
    {0,1,4,5},
    {0,2,4,6},
    {1,3,5,7},
    {2,3,6,7},
    {4,5,6,7}
  };
  static const int4 edgeFaceIdentity_host[6] {
    {0,1,2,3},
    {0,4,5,8},
    {1,4,6,9},
    {2,5,7,10},
    {3,6,7,11},
    {8,9,10,11}
  };

  /* CUDA variable, method and kernel defintions */

  namespace{
    struct is_not_neg{
      __host__ __device__
      bool operator()(const int x)
      {
        return (x >= 0);
      }
    };
  }

  // =============================================================================================================
  //
  // Device Kernels
  //
  // =============================================================================================================

  __device__ __host__ float3 getVoidCenter(const Octree::Node &node, int neighbor);
  __device__ __host__ float3 getVoidChildCenter(const Octree::Node &parent, int child);
  __device__ __forceinline__ int floatToOrderedInt(float floatVal);
  __device__ __forceinline__ float orderedIntToFloat(int intVal);
  //prints the bits of any data type
  __device__ __host__ void printBits(size_t const size, void const * const ptr);

  //gets the keys of each node in a top down manor
  __global__ void getNodeKeys(float3* points, float3* nodeCenters, int* nodeKeys, float3 c, float W, int numPoints, int D);

  //following methods are used to fill in the node array in a top down manor
  __global__ void findAllNodes(int numUniqueNodes, int* nodeNumbers, Octree::Node* uniqueNodes);
  void calculateNodeAddresses(dim3 grid, dim3 block,int numUniqueNodes, Octree::Node* uniqueNodes, int* nodeAddresses_device, int* nodeNumbers_device);
  __global__ void fillBlankNodeArray(Octree::Node* uniqueNodes, int* nodeNumbers, int* nodeAddresses, Octree::Node* outputNodeArray, int numUniqueNodes, int currentDepth, float totalWidth);
  __global__ void fillFinestNodeArrayWithUniques(Octree::Node* uniqueNodes, int* nodeAddresses, Octree::Node* outputNodeArray, int numUniqueNodes, unsigned int* pointNodeIndex);
  __global__ void fillNodeArrayWithUniques(Octree::Node* uniqueNodes, int* nodeAddresses, Octree::Node* outputNodeArray, Octree::Node* childNodeArray ,int numUniqueNodes);
  __global__ void generateParentalUniqueNodes(Octree::Node* uniqueNodes, Octree::Node* nodeArrayD, int numNodesAtDepth, float totalWidth, const int3* __restrict__ coordPlacementIdentity);
  __global__ void computeNeighboringNodes(Octree::Node* nodeArray, int numNodes, int depthIndex, int* parentLUT, int* childLUT, int childDepthIndex);

  __global__ void findNormalNeighborsAndComputeCMatrix(int numNodesAtDepth, int depthIndex, int maxNeighbors, Octree::Node* nodeArray, float3* points, float* cMatrix, int* neighborIndices, int* numNeighbors);
  __global__ void transposeFloatMatrix(int m, int n, float* matrix);
  __global__ void setNormal(int currentPoint, float* vt, float3* normals);
  __global__ void checkForAbiguity(int numPoints, int numCameras, float3* normals, float3* points, float3* cameraPositions, bool* ambiguous);
  __global__ void reorient(int numNodesAtDepth, int depthIndex, Octree::Node* nodeArray, int* numNeighbors, int maxNeighbors, float3* normals, int* neighborIndices, bool* ambiguous);

  __global__ void findVertexOwners(Octree::Node* nodeArray, int numNodes, int depthIndex, int* vertexLUT, int* numVertices, int* ownerInidices, int* vertexPlacement);
  __global__ void fillUniqueVertexArray(Octree::Node* nodeArray, Octree::Vertex* vertexArray, int numVertices, int vertexIndex,int depthIndex, int depth, float width, int* vertexLUT, int* ownerInidices, int* vertexPlacement, const int3* __restrict__ coordPlacementIdentity);
  __global__ void findEdgeOwners(Octree::Node* nodeArray, int numNodes, int depthIndex, int* edgeLUT, int* numEdges, int* ownerInidices, int* edgePlacement);
  __global__ void fillUniqueEdgeArray(Octree::Node* nodeArray, Octree::Edge* edgeArray, int numEdges, int edgeIndex,int depthIndex, int depth, float width, int* edgeLUT, int* ownerInidices, int* edgePlacement, const int2* __restrict__ vertexEdgeIdentity);
  __global__ void findFaceOwners(Octree::Node* nodeArray, int numNodes, int depthIndex, int* faceLUT, int* numFaces, int* ownerInidices, int* facePlacement);
  __global__ void fillUniqueFaceArray(Octree::Node* nodeArray, Octree::Face* faceArray, int numFaces, int faceIndex,int depthIndex, int depth, float width, int* faceLUT, int* ownerInidices, int* facePlacement, const int4* __restrict__ edgeFaceIdentity);

}


#endif /* OCTREE_CUH */
