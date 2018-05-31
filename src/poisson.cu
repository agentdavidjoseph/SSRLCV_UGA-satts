#include "poisson.cuh"

using namespace std;

// Define this to turn on error checking
#define CUDA_ERROR_CHECK

#define CudaSafeCall( err ) __cudaSafeCall( err, __FILE__, __LINE__ )
#define CudaCheckError()    __cudaCheckError( __FILE__, __LINE__ )


inline void __cudaSafeCall(cudaError err, const char *file, const int line) {
#ifdef CUDA_ERROR_CHECK
  if (cudaSuccess != err) {
      fprintf(stderr, "cudaSafeCall() failed at %s:%i : %s\n",
      file, line, cudaGetErrorString(err));
      exit(-1);
  }
#endif

  return;
}
inline void __cudaCheckError(const char *file, const int line) {
#ifdef CUDA_ERROR_CHECK
  cudaError err = cudaGetLastError();
  if (cudaSuccess != err) {
    fprintf(stderr, "cudaCheckError() failed at %s:%i : %s\n",
    file, line, cudaGetErrorString(err));
    exit(-1);
  }

  // More careful checking. However, this will affect performance.
  // Comment away if needed.
  //err = cudaDeviceSynchronize();
  if (cudaSuccess != err) {
    fprintf(stderr, "cudaCheckError() with sync failed at %s:%i : %s\n",
    file, line, cudaGetErrorString(err));
    exit(-1);
  }
#endif

  return;
}

__device__ __host__ float3 operator+(const float3 &a, const float3 &b) {
  return {a.x+b.x, a.y+b.y, a.z+b.z};
}
__device__ __host__ float3 operator-(const float3 &a, const float3 &b) {
  return {a.x-b.x, a.y-b.y, a.z-b.z};
}
__device__ __host__ float3 operator/(const float3 &a, const float3 &b) {
  return {a.x/b.x, a.y/b.y, a.z/b.z};
}
__device__ __host__ float3 operator*(const float3 &a, const float3 &b) {
  return {a.x*b.x, a.y*b.y, a.z*b.z};
}
__device__ __host__ float dotProduct(const float3 &a, const float3 &b){
  return (a.x*b.x) + (a.y*b.y) + (a.z*b.z);
}
__device__ __host__ float3 operator+(const float3 &a, const float &b){
  return {a.x+b, a.y+b, a.z+b};
}
__device__ __host__ float3 operator-(const float3 &a, const float &b){
  return {a.x-b, a.y-b, a.z-b};

}
__device__ __host__ float3 operator/(const float3 &a, const float &b){
  return {a.x/b, a.y/b, a.z/b};

}
__device__ __host__ float3 operator*(const float3 &a, const float &b){
  return {a.x*b, a.y*b, a.z*b};
}
__device__ __host__ float3 operator+(const float &a, const float3 &b) {
  return {a+b.x, a+b.y, a+b.z};
}
__device__ __host__ float3 operator-(const float &a, const float3 &b) {
  return {a-b.x, a-b.y, a-b.z};
}
__device__ __host__ float3 operator/(const float &a, const float3 &b) {
  return {a/b.x, a/b.y, a/b.z};
}
__device__ __host__ float3 operator*(const float &a, const float3 &b) {
  return {a*b.x, a*b.y, a*b.z};
}

__device__ __host__ float3 blender(const float3 &a, const float3 &b, const float &bw){
  float3 t = (a-b)/bw;
  if((t.x > 0.0f && t.x <= 1.5) && (t.x > 0.0f && t.x <= 1.5) && (t.x > 0.0f && t.x <= 1.5)){
    return ((0.5*t*t*t) + (2.5*t*t) + (4.0f*t) + 2.0f)/(bw*bw*bw);
  }
  else if((t.x <= 0.0f && t.x >= -1.5) && (t.x <= 0.0f && t.x >= -1.5) && (t.x <= 0.0f && t.x >= -1.5)){
    return ((-0.5*t*t*t) + (2.5*t*t) + (-4.0f*t) + 2.0f)/(bw*bw*bw);
  }
  else{
    return {0.0f,0.0f,0.0f};
  }
}
__device__ __host__ float3 blenderPrime(const float3 &a, const float3 &b, const float &bw){
  float3 t = (a-b)/bw;
  if((t.x > 0.0f && t.x <= 1.5) && (t.x > 0.0f && t.x <= 1.5) && (t.x > 0.0f && t.x <= 1.5)){
    return ((1.5*t*t) + (5.0f*t) + 4.0f)/(bw*bw*bw);
  }
  else if((t.x <= 0.0f && t.x >= -1.5) && (t.x <= 0.0f && t.x >= -1.5) && (t.x <= 0.0f && t.x >= -1.5)){
    return ((-1.5*t*t) + (5.0f*t) - 4.0f)/(bw*bw*bw);
  }
  else{
    return {0.0f,0.0f,0.0f};
  }
}
__device__ __host__ float3 blenderPrimePrime(const float3 &a, const float3 &b, const float &bw){
  float3 t = (a-b)/bw;
  if((t.x > 0.0f && t.x <= 1.5) && (t.x > 0.0f && t.x <= 1.5) && (t.x > 0.0f && t.x <= 1.5)){
    return ((3.0f*t) + 5.0f)/(bw*bw*bw);
  }
  else if((t.x <= 0.0f && t.x >= -1.5) && (t.x <= 0.0f && t.x >= -1.5) && (t.x <= 0.0f && t.x >= -1.5)){
    return ((-3.0f*t) + 5.0f)/(bw*bw*bw);
  }
  else{
    return {0.0f,0.0f,0.0f};
  }
}

__global__ void computeVectorFeild(Node* nodeArray, int numFinestNodes, float3* vectorField, float3* normals, float3* points){
  int blockID = blockIdx.y * gridDim.x + blockIdx.x;
  if(blockID < numFinestNodes){
    __shared__ float3 vec;
    vec = {0.0f, 0.0f, 0.0f};
    __syncthreads();
    int neighborIndex = nodeArray[blockID].neighbors[threadIdx.x];
    if(neighborIndex != -1){
      int currentPoint = nodeArray[neighborIndex].pointIndex;
      int stopIndex = nodeArray[neighborIndex].numPoints + currentPoint;
      float3 blend = {0.0f,0.0f,0.0f};
      float width = nodeArray[blockID].width;
      float3 center = nodeArray[blockID].center;
      for(int i = currentPoint; i < stopIndex; ++i){
        //n = 2 Fo(q) make bounds {0.0f, 1.0f}
          //blend = 1.0f - blend;
        //n = 2 Fo(q) make bounds {-1.0f, 0.0f}
          //blend = blend + 1.0f;
        //n currently = 3
        blend = blender(points[i],center,width)*normals[i];
        if(blend.x == 0.0f && blend.y == 0.0f && blend.z == 0.0f) continue;
        atomicAdd(&vec.x, blend.x);
        atomicAdd(&vec.y, blend.y);
        atomicAdd(&vec.z, blend.z);
      }
    }
    __syncthreads();
    if(threadIdx.x == 0){
      vectorField[blockID] = vec;
    }
  }
}
__global__ void computeDivergenceFine(Node* nodeArray, int numNodes, int depthIndex, float3* vectorField, float* divCoeff, float* fPrimeLUT){
  int blockID = blockIdx.y * gridDim.x + blockIdx.x;
  if(blockID < numNodes){
    __shared__ float coeff;
    int neighborIndex = nodeArray[blockID + depthIndex].neighbors[threadIdx.x];
    int numFinestChildren = nodeArray[neighborIndex].numFinestChildren;
    int finestChildIndex = nodeArray[neighborIndex].finestChildIndex;
    int x1,x2,y1,y2,z1,z2;

    for(int i = finestChildIndex; i < finestChildIndex + numFinestChildren; ++i){
      //atomicAdd(&coeff, dotProduct(vectorField[i], fPrimeLUT[]));
    }
    __syncthreads();
    if(threadIdx.x == 0){
      divCoeff[blockID + depthIndex] = coeff;
    }
  }
}
__global__ void findRelatedChildren(Node* nodeArray, int numNodes, int depthIndex, int2* relativityIndicators){
  int blockID = blockIdx.y * gridDim.x + blockIdx.x;
  if(blockID < numNodes){
    __shared__ int numRelativeChildren;
    __shared__ int firstRelativeChild;
    numRelativeChildren = 0;
    int neighborIndex = nodeArray[blockID + depthIndex].neighbors[threadIdx.x];
    if(neighborIndex != -1){
      atomicAdd(&numRelativeChildren, nodeArray[neighborIndex].numFinestChildren);
      atomicMin(&firstRelativeChild, nodeArray[neighborIndex].finestChildIndex);
    }
    __syncthreads();
    if(threadIdx.x == 0){
      relativityIndicators[blockID].x = firstRelativeChild;
      relativityIndicators[blockID].y = numRelativeChildren;
    }
  }
}
__global__ void computeDivergenceCoarse(Node* nodeArray, int2* relativityIndicators, int currentNode, float3* vectorField, float* divCoeff, float* fPrimeLUT){
  int globalID = blockIdx.x * blockDim.x + threadIdx.x;
  if(globalID < relativityIndicators[currentNode].y){
    globalID += relativityIndicators[currentNode].x;
    //TODO try and find a way to optimize this so that it is not using atomics and global memory
    //atomicAdd(&divCoeff[currentNode], dotProduct(vectorField[globalID],fPrimeLUT[]));
  }
}

__global__ void updateDivergence(Node* nodeArray, int numNodes, int depthIndex, float* divCoeff, float* fLUT, float* fPrimePrimeLUT, float* nodeImplicit){
  int blockID = blockIdx.y * gridDim.x + blockIdx.x;
  if(blockID < numNodes){
    int parent = nodeArray[blockID + depthIndex].parent;
    int parentNeighbor = nodeArray[parent].neighbors[threadIdx.x];
    float nodeImplicitValue = nodeImplicit[parentNeighbor];
    //float laplacianValue = (fPrimePrimeLUT[]*fLUT[]*fLUT[])+(fLUT[]*fPrimePrimeLUT[]*fLUT[])+(fLUT[]*fLUT[]*fPrimePrimeLUT[]);
    //atomicAdd(&divCoeff[blockID + depthIndex], -1.0f*laplacianValue*nodeImplicitValue);
  }
}

Poisson::Poisson(Octree* octree){
  this->octree = octree;
  float* divergenceVector = new float[this->octree->totalNodes];
  for(int i = 0; i < this->octree->totalNodes; ++i){
    divergenceVector[i] = 0.0f;
  }
  CudaSafeCall(cudaMalloc((void**)&this->divergenceVectorDevice, this->octree->totalNodes*sizeof(float)));
  CudaSafeCall(cudaMemcpy(this->divergenceVectorDevice, divergenceVector, this->octree->totalNodes*sizeof(float), cudaMemcpyHostToDevice));

}

Poisson::~Poisson(){
  //TODO delete octree;
}

//TODO make sure this is correct and put some part of it on gpu (too slow)
void Poisson::computeLUTs(){
  clock_t timer;
  timer = clock();

  unsigned int size = (pow(2, this->octree->depth + 1) - 1);
  this->fLUT = new float[size*size];
  this->fPrimeLUT = new float[size*size];
  this->fPrimePrimeLUT = new float[size*size];

  float currentWidth = this->octree->width;
  float3 currentCenter = this->octree->center;
  float3 tempCenter = {0.0f,0.0f,0.0f};
  int pow2 = 1;
  vector<float3> centers;
  queue<float3> centersTemp;
  centersTemp.push(currentCenter);
  for(int d = 0; d <= this->octree->depth; ++d){
    for(int i = 0; i < pow2; ++i){
      tempCenter = centersTemp.front();
      centersTemp.pop();
      centers.push_back(tempCenter);
      centersTemp.push(tempCenter - (currentWidth/4));
      centersTemp.push(tempCenter + (currentWidth/4));
    }
    currentWidth /= 2;
    pow2 *= 2;
  }

  float totalWidth = this->octree->width;
  int pow2i = 1;
  int offseti = 0;
  int pow2j = 1;
  int offsetj = 0;
  for(int i = 0; i <= this->octree->depth; ++i){
    offseti = pow2i - 1;
    pow2j = 1;
    for(int j = 0; j <= this->octree->depth; ++j){
      offsetj = pow2j - 1;
      for(int k = offseti; k < offseti + pow2i; ++k){
        for(int l = offsetj; l < offsetj + pow2j; ++l){
          this->fLUT[k*pow2j] = dotProduct(blender(centers[l],centers[k],totalWidth/pow2i),blender(centers[k],centers[l],totalWidth/pow2j));
          this->fPrimeLUT[k*pow2j] = dotProduct(blender(centers[l],centers[k],totalWidth/pow2i),blenderPrime(centers[k],centers[l],totalWidth/pow2j));
          this->fPrimePrimeLUT[k*pow2j] = dotProduct(blender(centers[l],centers[k],totalWidth/pow2i),blenderPrimePrime(centers[k],centers[l],totalWidth/pow2j));
        }
      }
      pow2j *= 2;
    }
    pow2i *= 2;
  }
  timer = clock() - timer;
  printf("blending LUT generation took %f seconds fully on the CPU.\n\n",((float) timer)/CLOCKS_PER_SEC);
}

//TODO should optimize computeDivergenceCoarse
void Poisson::computeDivergenceVector(){
  clock_t cudatimer;
  cudatimer = clock();
  /*
  FIRST COMPUTE VECTOR FIELD
  */

  int numNodesAtDepth = 0;
  dim3 grid = {1,1,1};
  dim3 block = {1,1,1};
  numNodesAtDepth = this->octree->depthIndex[1];
  if(numNodesAtDepth < 65535) grid.x = (unsigned int) numNodesAtDepth;
  else{
    grid.x = 65535;
    while(grid.x*grid.y < numNodesAtDepth){
      ++grid.y;
    }
    while(grid.x*grid.y > numNodesAtDepth){
      --grid.x;

    }
    if(grid.x*grid.y < numNodesAtDepth){
      ++grid.x;
    }
  }
  block.x = 27;
  float3* vectorField = new float3[numNodesAtDepth];
  for(int i = 0; i < numNodesAtDepth; ++i){
    vectorField[i] = {0.0f,0.0f,0.0f};
  }
  float3* vectorFieldDevice;
  CudaSafeCall(cudaMalloc((void**)&vectorFieldDevice, numNodesAtDepth*sizeof(float3)));
  CudaSafeCall(cudaMemcpy(vectorFieldDevice, vectorField, numNodesAtDepth*sizeof(float3), cudaMemcpyHostToDevice));
  computeVectorFeild<<<grid,block>>>(this->octree->finalNodeArrayDevice, numNodesAtDepth, vectorFieldDevice, this->octree->normalsDevice, this->octree->pointsDevice);
  cudaDeviceSynchronize();
  CudaCheckError();
  /*
  CudaSafeCall(cudaMemcpy(vectorField, vectorFieldDevice, numNodesAtDepth*sizeof(float3), cudaMemcpyDeviceToHost));
  for(int i = 0; i < numNodesAtDepth; ++i){
    if(vectorField[i].x != 0.0f && vectorField[i].y != 0.0f && vectorField[i].z != 0.0f){
      cout<<vectorField[i].x<<","<<vectorField[i].y<<","<<vectorField[i].z<<endl;
    }
  }
  */
  delete[] vectorField;
  cudatimer = clock() - cudatimer;
  printf("Vector field generation kernel took %f seconds.\n\n",((float) cudatimer)/CLOCKS_PER_SEC);
  cudatimer = clock();
  /*
  NOW COMPUTE DIVERGENCE VECTOR AFTER FINDING VECTOR FIELD
  */

  unsigned int size = (pow(2, this->octree->depth + 1) - 1);
  CudaSafeCall(cudaMalloc((void**)&this->fPrimeLUTDevice, size*size*sizeof(float)));
  CudaSafeCall(cudaMemcpy(this->fPrimeLUTDevice, this->fPrimeLUT, size*size*sizeof(float), cudaMemcpyHostToDevice));

  int2* relativityIndicators;
  int2* relativityIndicatorsDevice;
  for(int d = 0; d <= this->octree->depth; ++d){
    block = {27,1,1};
    grid = {1,1,1};
    if(d != this->octree->depth){
      numNodesAtDepth = this->octree->depthIndex[d + 1] - this->octree->depthIndex[d];
    }
    else numNodesAtDepth = 1;

    if(numNodesAtDepth < 65535) grid.x = (unsigned int) numNodesAtDepth;
    else{
      grid.x = 65535;
      while(grid.x*grid.y < numNodesAtDepth){
        ++grid.y;
      }
      while(grid.x*grid.y > numNodesAtDepth){
        --grid.x;
        if(grid.x*grid.y < numNodesAtDepth){
          ++grid.x;//to ensure that numThreads > numNodesAtDepth
          break;
        }
      }
    }
    if(d <= 5){//evaluate divergence coefficients at finer depths
      computeDivergenceFine<<<grid, block>>>(this->octree->finalNodeArrayDevice, numNodesAtDepth, this->octree->depthIndex[d], vectorFieldDevice, this->divergenceVectorDevice, this->fPrimeLUTDevice);
      CudaCheckError();
    }
    else{//evaluate divergence coefficients at coarser depths
      relativityIndicators = new int2[numNodesAtDepth];
      for(int i = 0; i < numNodesAtDepth; ++i){
        relativityIndicators[i] = {0,0};
      }
      CudaSafeCall(cudaMalloc((void**)&relativityIndicatorsDevice, numNodesAtDepth*sizeof(int2)));
      CudaSafeCall(cudaMemcpy(relativityIndicatorsDevice, relativityIndicators, numNodesAtDepth*sizeof(int2), cudaMemcpyHostToDevice));
      findRelatedChildren<<<grid, block>>>(this->octree->finalNodeArrayDevice, numNodesAtDepth, this->octree->depthIndex[d], relativityIndicatorsDevice);
      CudaCheckError();
      CudaSafeCall(cudaMemcpy(relativityIndicators, relativityIndicatorsDevice, numNodesAtDepth*sizeof(int2), cudaMemcpyDeviceToHost));
      for(int currentNode = 0; currentNode < numNodesAtDepth; ++currentNode){
        block.x = 1;
        if(relativityIndicators[currentNode].y < 65535) grid.x = (unsigned int) relativityIndicators[currentNode].y;
        else{
          grid.x = 65535;
          while(grid.x*block.x < relativityIndicators[currentNode].y){
            ++block.x ;
          }
          while(grid.x*block.x > relativityIndicators[currentNode].y){
            --grid.x;
            if(grid.x*block.x < relativityIndicators[currentNode].y){
              ++grid.x;//to ensure that numThreads > totalNodes
              break;
            }
          }
        }
        computeDivergenceCoarse<<<grid, block>>>(this->octree->finalNodeArrayDevice, relativityIndicatorsDevice, this->octree->depthIndex[d] + currentNode, vectorFieldDevice, this->divergenceVectorDevice, this->fPrimeLUTDevice);
        CudaCheckError();
      }
      CudaSafeCall(cudaFree(relativityIndicatorsDevice));
      delete[] relativityIndicators;
    }
  }
  CudaSafeCall(cudaFree(vectorFieldDevice));
  CudaSafeCall(cudaFree(this->fPrimeLUTDevice));
  delete[] this->fPrimeLUT;

  cudatimer = clock() - cudatimer;
  printf("Divergence vector generation kernel took %f seconds.\n\n",((float) cudatimer)/CLOCKS_PER_SEC);
}

void Poisson::computeImplicitFunction(){
  unsigned int size = (pow(2, this->octree->depth + 1) - 1);
  float* nodeImplicit = new float[this->octree->totalNodes];
  for(int i = 0; i < this->octree->totalNodes; ++i){
    nodeImplicit[i] = 0.0f;
  }
  CudaSafeCall(cudaMalloc((void**)&this->fLUTDevice, size*size*sizeof(float)));
  CudaSafeCall(cudaMalloc((void**)&this->fPrimePrimeLUTDevice, size*size*sizeof(float)));
  CudaSafeCall(cudaMalloc((void**)&this->nodeImplicitDevice, this->octree->totalNodes*sizeof(float)));
  CudaSafeCall(cudaMemcpy(this->fLUTDevice, this->fLUT, size*size*sizeof(float), cudaMemcpyHostToDevice));
  CudaSafeCall(cudaMemcpy(this->fPrimePrimeLUTDevice, this->fPrimePrimeLUT, size*size*sizeof(float), cudaMemcpyHostToDevice));
  CudaSafeCall(cudaMemcpy(this->nodeImplicitDevice, nodeImplicit, this->octree->totalNodes*sizeof(float), cudaMemcpyHostToDevice));

  int numNodesAtDepth = 0;

  for(int d = this->octree->depth; d >= 0; --d){
    //update divergence coefficients based on solutions at coarser depths
    dim3 grid = {1,1,1};
    dim3 block = {27,1,1};
    if(d != this->octree->depth){
      numNodesAtDepth = this->octree->depthIndex[this->octree->depth - d] - this->octree->depthIndex[(this->octree->depth - d) + 1];
      if(numNodesAtDepth < 65535) grid.x = (unsigned int) numNodesAtDepth;
      else{
        grid.x = 65535;
        while(grid.x*grid.y < numNodesAtDepth){
          ++grid.y;
        }
        while(grid.x*grid.y > numNodesAtDepth){
          --grid.x;

        }
        if(grid.x*grid.y < numNodesAtDepth){
          ++grid.x;
        }
      }
      for(int dcoarse = d + 1; dcoarse <= this->octree->depth; ++dcoarse){
        updateDivergence<<<grid, block>>>(this->octree->finalNodeArrayDevice, numNodesAtDepth,
          this->octree->depthIndex[this->octree->depth - d], this->divergenceVectorDevice,
          this->fLUTDevice, this->fPrimePrimeLUTDevice, this->nodeImplicitDevice);
        CudaCheckError();
      }
    }

    //multigridsolver for that depth
    //TODO implement or use library for sparse matrices

  }


  CudaSafeCall(cudaFree(this->fLUTDevice));
  CudaSafeCall(cudaFree(this->fPrimePrimeLUTDevice));
  delete[] this->fLUT;
  delete[] this->fPrimePrimeLUT;
}
void Poisson::marchingCubes(){

}
