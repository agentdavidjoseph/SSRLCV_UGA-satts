#include "common_includes.h"
#include "Image.cuh"
#include "io_util.h"
#include "SIFT_FeatureFactory.cuh"
#include "MatchFactory.cuh"
#include "PointCloudFactory.cuh"
#include "MeshFactory.cuh"

//TODO fix gaussian operators - currently creating very low values

int main(int argc, char *argv[]){
  try{
    //CUDA INITIALIZATION
    cuInit(0);
    clock_t totalTimer = clock();
    clock_t partialTimer = clock();


    // test bundle adjustment here

    std::cout << "=========================== TEST 01 ===========================" << std::endl;
    std::cout << "Making fake image guys ..." << std::endl;
    std::vector<ssrlcv::Image*> images_vec;

    ssrlcv::Image* image0 = new ssrlcv::Image();
    ssrlcv::Image* image1 = new ssrlcv::Image();
    images_vec.push_back(image0);
    images_vec.push_back(image1);

    // fill the test camera params
    std::cout << "Filling in Test Camera Params ..." << std::endl;

    images_vec[0]->id = 0;
    images_vec[0]->camera.size = {1024,1024};
    images_vec[0]->camera.cam_pos = {0.0,0.0,8.0};
    images_vec[0]->camera.cam_rot = {1.57079632679, 0.0, 0.0};
    images_vec[0]->camera.fov = {0.392699081699,0.392699081699};
    images_vec[0]->camera.foc = 0.25;
    images_vec[1]->id = 1;
    images_vec[1]->camera.size = {1024,1024};
    images_vec[1]->camera.cam_pos = {0.0,-7.8784620241,-1.38918542134};
    images_vec[1]->camera.cam_rot = {1.74532925199, 0.0, 0.0};
    images_vec[1]->camera.fov = {0.392699081699,0.392699081699};
    images_vec[1]->camera.foc = 0.25;

    /*
    images_vec[0]->id = 0;
    images_vec[0]->camera.size = {2,2};
    images_vec[0]->camera.cam_pos = {2.0,-2.0,2.0};
    images_vec[0]->camera.cam_rot = {3.0 * (M_PI/2.0),0.0f,0.0f};
    images_vec[0]->camera.fov = {(M_PI/8),(M_PI/8)};
    images_vec[0]->camera.foc = 0.25;

    images_vec[1]->id = 1;
    images_vec[1]->camera.size = {2,2};
    images_vec[1]->camera.cam_pos = {-2.0,2.0,2.0};
    images_vec[1]->camera.cam_rot = {3.0 * (M_PI/2), 0.0, 3.0 * (M_PI/2)};
    images_vec[1]->camera.fov = {(M_PI/8),(M_PI/8)};
    images_vec[1]->camera.foc = 0.25;
    */

    // fill the test match points
    std::cout << "Filling in Matches ..." << std::endl;
    ssrlcv::Match* matches_host = new ssrlcv::Match[9];
    ssrlcv::Unity<ssrlcv::Match>* matches = new ssrlcv::Unity<ssrlcv::Match>(matches_host, 9, ssrlcv::cpu);

    // auto generated from util/cube_gen.py
    matches->host[0].keyPoints[0].parentId = 0;
    matches->host[0].keyPoints[1].parentId = 1;
    matches->host[0].keyPoints[0].loc = {226.000242226,797.999757774};
    matches->host[0].keyPoints[1].loc = {219.870706692,850.418912358};
    matches->host[1].keyPoints[0].parentId = 0;
    matches->host[1].keyPoints[1].parentId = 1;
    matches->host[1].keyPoints[0].loc = {797.999757774,797.999757774};
    matches->host[1].keyPoints[1].loc = {804.129293308,850.418912358};
    matches->host[2].keyPoints[0].parentId = 0;
    matches->host[2].keyPoints[1].parentId = 1;
    matches->host[2].keyPoints[0].loc = {797.999757774,226.000242226};
    matches->host[2].keyPoints[1].loc = {793.051504692,284.022380804};
    matches->host[3].keyPoints[0].parentId = 0;
    matches->host[3].keyPoints[1].parentId = 1;
    matches->host[3].keyPoints[0].loc = {226.000242226,226.000242226};
    matches->host[3].keyPoints[1].loc = {230.948495308,284.022380804};
    matches->host[4].keyPoints[0].parentId = 0;
    matches->host[4].keyPoints[1].parentId = 1;
    matches->host[4].keyPoints[0].loc = {144.286025719,879.713974281};
    matches->host[4].keyPoints[1].loc = {135.769459951,817.183005098};
    matches->host[5].keyPoints[0].parentId = 0;
    matches->host[5].keyPoints[1].parentId = 1;
    matches->host[5].keyPoints[0].loc = {879.713974281,879.713974281};
    matches->host[5].keyPoints[1].loc = {888.230540049,817.183005098};
    matches->host[6].keyPoints[0].parentId = 0;
    matches->host[6].keyPoints[1].parentId = 1;
    matches->host[6].keyPoints[0].loc = {879.713974281,144.286025719};
    matches->host[6].keyPoints[1].loc = {870.054660824,97.209454661};
    matches->host[7].keyPoints[0].parentId = 0;
    matches->host[7].keyPoints[1].parentId = 1;
    matches->host[7].keyPoints[0].loc = {144.286025719,144.286025719};
    matches->host[7].keyPoints[1].loc = {153.945339176,97.209454661};
    matches->host[8].keyPoints[0].parentId = 0;
    matches->host[8].keyPoints[1].parentId = 1;
    matches->host[8].keyPoints[0].loc = {512.0,512.0};
    matches->host[8].keyPoints[1].loc = {512.0,512.0};

    /*
    matches->host[0].keyPoints[0].loc = {1.0,1.0}; // at the center
    matches->host[0].keyPoints[1].loc = {1.0,1.0}; // at the center
    */

    /*
    matches->host[1].keyPoints[0].parentId = 0;
    matches->host[1].keyPoints[1].parentId = 1;
    matches->host[1].keyPoints[0].loc = {1.0,2.0}; // at the center top
    matches->host[1].keyPoints[1].loc = {1.0,2.0}; // at the center top
    */

    // start testing reprojection
    ssrlcv::PointCloudFactory demPoints = ssrlcv::PointCloudFactory();

    //match interpolation method will take the place of this here.
    ssrlcv::MatchSet matchSet;
    matchSet.keyPoints = new ssrlcv::Unity<ssrlcv::KeyPoint>(nullptr,matches->size()*2,ssrlcv::cpu);
    matchSet.matches = new ssrlcv::Unity<ssrlcv::MultiMatch>(nullptr,matches->size(),ssrlcv::cpu);
    for(int i = 0; i < matches->size(); ++i){
      matchSet.keyPoints->host[i*2] = matches->host[i].keyPoints[0];
      matchSet.keyPoints->host[i*2 + 1] = matches->host[i].keyPoints[1];
      matchSet.matches->host[i] = {2,i*2};
    }

    // test the prefect case
    std::cout << "Testing perfect case ..." << std::endl;

    ssrlcv::Unity<float>* errors       = new ssrlcv::Unity<float>(nullptr,matchSet.matches->size(),ssrlcv::cpu);
    float* linearError                 = (float*) malloc(sizeof(float));
    float* linearErrorCutoff           = (float*) malloc(sizeof(float));
    *linearError                       = 0;
    *linearErrorCutoff                 = 9001;
    ssrlcv::BundleSet bundleSet        = demPoints.generateBundles(&matchSet,images_vec);
    ssrlcv::Unity<float3>* test_points = demPoints.twoViewTriangulate(bundleSet, errors, linearError, linearErrorCutoff);

    std::cout << "<lines start>" << std::endl;
    for(int i = 0; i < bundleSet.bundles->size(); i ++){
      for (int j = bundleSet.bundles->host[i].index; j < bundleSet.bundles->host[i].index + bundleSet.bundles->host[i].numLines; j++){
        std::cout << "(" << bundleSet.lines->host[j].pnt.x << "," << bundleSet.lines->host[j].pnt.y << "," << bundleSet.lines->host[j].pnt.z << ")\t\t";
        std::cout << "<" << bundleSet.lines->host[j].vec.x << "," << bundleSet.lines->host[j].vec.y << "," << bundleSet.lines->host[j].vec.z << ">" << std::endl;
      }
      std::cout << std::endl;
    }
    std::cout << "</lines end>" << std::endl;

    std::cout << "Prefect points:" << std::endl;
    //std::cout << "\t( " << test_point->host[0].x << ",  " << test_point->host[0].y << ", " << test_point->host[0].z << " )" << std::endl;
    //std::cout << "\t( " << test_point->host[1].x << ",  " << test_point->host[1].y << ", " << test_point->host[1].z << " )" << std::endl;
    std::cout << "\tLinear Error: " << *linearError << std::endl;

    ssrlcv::writePLY("out/test_points.ply",test_points);

    // a test of the new PLY writer
    struct colorPoint* cpoints =  (colorPoint*) malloc(sizeof(10 * struct colorPoint));
    for (int k = 0; k < 10; k++){
      cpoints[k] = {k,k/2,k/4,0,255,32};
    }
    ssrlcv::writePLY("colorPointTest", cpoints, (size_t) 10);

    std::cout << "Cube Points: " << std::endl;
    for (int i = 0; i < test_points->size(); i++){
      std::cout << "\t(" << test_points->host[i].x << "," << test_points->host[i].y << "," << test_points->host[i].z << ")" << std::endl;
    }

    // add some random errors into the camera stuff
    std::vector<ssrlcv::Image*> images_vec_err;

    ssrlcv::Image* image0_err = new ssrlcv::Image();
    ssrlcv::Image* image1_err = new ssrlcv::Image();
    images_vec_err.push_back(image0_err);
    images_vec_err.push_back(image1_err);

    std::default_random_engine generator;
    std::normal_distribution<float> distribution(0.0,0.00001);

    // std::cout << "Sample Errors to add:" << std::endl;
    // for (int i = 0; i < 5; i ++){
    //   float n = distribution(generator);
    //   std::cout << n << ", ";
    // }
    // std::cout << std::endl;

    // addint noise to camera
    std::cout << "Filling in Test Camera Params ..." << std::endl;
    images_vec_err[0]->id = images_vec[0]->id;
    images_vec_err[0]->camera.size = images_vec[0]->camera.size;
    float3 err0 = {0.0001,0.0,0.0};
    images_vec_err[0]->camera.cam_pos = images_vec[0]->camera.cam_pos + err0;
    images_vec_err[0]->camera.cam_rot = images_vec[0]->camera.cam_rot;
    images_vec_err[0]->camera.fov = images_vec[0]->camera.fov;
    images_vec_err[0]->camera.foc = images_vec[0]->camera.foc;

    images_vec_err[1]->id = images_vec[1]->id;
    images_vec_err[1]->camera.size = images_vec[1]->camera.size;
    images_vec_err[1]->camera.cam_pos = images_vec[1]->camera.cam_pos;
    float3 err1 = {0.0000001,0.0,0.0};
    images_vec_err[1]->camera.cam_rot = images_vec[1]->camera.cam_rot + err1;
    images_vec_err[1]->camera.fov = images_vec[1]->camera.fov;
    images_vec_err[1]->camera.foc = images_vec[1]->camera.foc;

    // test the prefect case
    std::cout << "Testing error case ..." << std::endl;

    ssrlcv::Unity<float>* errors_err      = new ssrlcv::Unity<float>(nullptr,matchSet.matches->size(),ssrlcv::cpu);
    float* linearError_err                = (float*) malloc(sizeof(float));
    float* linearErrorCutoff_err          = (float*) malloc(sizeof(float));
    *linearError_err                      = 0;
    *linearErrorCutoff_err                = 9001;
    ssrlcv::BundleSet bundleSet_err       = demPoints.generateBundles(&matchSet,images_vec_err);
    ssrlcv::Unity<float3>* test_point_err = demPoints.twoViewTriangulate(bundleSet_err, errors_err, linearError_err, linearErrorCutoff_err);

    std::cout << "Errored points:" << std::endl;
    //std::cout << "\t( " << test_point_err->host[0].x << ",  " << test_point_err->host[0].y << ", " << test_point_err->host[0].z << " )" << std::endl;
    //std::cout << "\t( " << test_point_err->host[1].x << ",  " << test_point_err->host[1].y << ", " << test_point_err->host[1].z << " )" << std::endl;
    std::cout << "\tLinear Error: " << *linearError_err << std::endl;



    //std::cout << "Attempting Bundle Adjustment ..." << std::endl;
    // ssrlcv::Unity<float3>* bundleAdjustedPoints = demPoints.BundleAdjustTwoView(&matchSet,images_vec_err);

    //ARG PARSING

    // // ========================== REAL BUNDLE ADJUSTMENT ATTEMPT START
    // std::map<std::string,ssrlcv::arg*> args = ssrlcv::parseArgs(argc,argv);
    // if(args.find("dir") == args.end()){
    //   std::cerr<<"ERROR: SFM executable requires a directory of images"<<std::endl;
    //   exit(-1);
    // }
    // ssrlcv::SIFT_FeatureFactory featureFactory = ssrlcv::SIFT_FeatureFactory(1.5f,6.0f);
    // ssrlcv::MatchFactory<ssrlcv::SIFT_Descriptor> matchFactory = ssrlcv::MatchFactory<ssrlcv::SIFT_Descriptor>(0.6f,250.0f*250.0f);
    // bool seedProvided = false;
    // ssrlcv::Unity<ssrlcv::Feature<ssrlcv::SIFT_Descriptor>>* seedFeatures = nullptr;
    // if(args.find("seed") != args.end()){
    //   seedProvided = true;
    //   std::string seedPath = ((ssrlcv::img_arg*)args["seed"])->path;
    //   ssrlcv::Image* seed = new ssrlcv::Image(seedPath,-1);
    //   seedFeatures = featureFactory.generateFeatures(seed,false,2,0.8);
    //   matchFactory.setSeedFeatures(seedFeatures);
    //   delete seed;
    // }
    // std::vector<std::string> imagePaths = ((ssrlcv::img_dir_arg*)args["dir"])->paths;
    // int numImages = (int) imagePaths.size();
    // std::cout<<"found "<<numImages<<" in directory given"<<std::endl;
    //
    // std::vector<ssrlcv::Image*> images;
    // std::vector<ssrlcv::Unity<ssrlcv::Feature<ssrlcv::SIFT_Descriptor>>*> allFeatures;
    // for(int i = 0; i < numImages; ++i){
    //   ssrlcv::Image* image = new ssrlcv::Image(imagePaths[i],i);
    //   ssrlcv::Unity<ssrlcv::Feature<ssrlcv::SIFT_Descriptor>>* features = featureFactory.generateFeatures(image,false,2,0.8);
    //   features->transferMemoryTo(ssrlcv::cpu);
    //   images.push_back(image);
    //   allFeatures.push_back(features);
    // }
    //
    // /*
    // MATCHING
    // */
    // //seeding with false photo
    //
    // std::cout << "Starting matching..." << std::endl;
    // ssrlcv::Unity<float>* seedDistances = (seedProvided) ? matchFactory.getSeedDistances(allFeatures[0]) : nullptr;
    // ssrlcv::Unity<ssrlcv::DMatch>* distanceMatches = matchFactory.generateDistanceMatches(images[0],allFeatures[0],images[1],allFeatures[1],seedDistances);
    // if(seedDistances != nullptr) delete seedDistances;
    //
    // distanceMatches->transferMemoryTo(ssrlcv::cpu);
    // float maxDist = 0.0f;
    // for(int i = 0; i < distanceMatches->size(); ++i){
    //   if(maxDist < distanceMatches->host[i].distance) maxDist = distanceMatches->host[i].distance;
    // }
    // printf("max euclidean distance between features = %f\n",maxDist);
    // if(distanceMatches->getMemoryState() != ssrlcv::gpu) distanceMatches->setMemoryState(ssrlcv::gpu);
    // ssrlcv::Unity<ssrlcv::Match>* matches = matchFactory.getRawMatches(distanceMatches);
    // delete distanceMatches;
    // std::string delimiter = "/";
    // std::string matchFile = imagePaths[0].substr(0,imagePaths[0].rfind(delimiter)) + "/matches.txt";
    // ssrlcv::writeMatchFile(matches, matchFile);
    //
    // // HARD CODED FOR 2 VIEW
    // // Need to fill into to MatchSet boi
    // std::cout << "Generating MatchSet ..." << std::endl;
    // ssrlcv::MatchSet matchSet;
    // matchSet.keyPoints = new ssrlcv::Unity<ssrlcv::KeyPoint>(nullptr,matches->size()*2,ssrlcv::cpu);
    // matchSet.matches = new ssrlcv::Unity<ssrlcv::MultiMatch>(nullptr,matches->size(),ssrlcv::cpu);
    // matches->setMemoryState(ssrlcv::cpu);
    // for(int i = 0; i < matchSet.matches->size(); i++){
    //   matchSet.keyPoints->host[i*2] = matches->host[i].keyPoints[0];
    //   matchSet.keyPoints->host[i*2 + 1] = matches->host[i].keyPoints[1];
    //   matchSet.matches->host[i] = {2,i*2};
    // }
    // std::cout << "Generated MatchSet ..." << std::endl << "Total Matches: " << matches->size() << std::endl << std::endl;
    //
    // /*
    // attempted bundle adjustment
    // */
    //
    // ssrlcv::PointCloudFactory pc = ssrlcv::PointCloudFactory();
    //
    //
    // ssrlcv::Unity<float3>* points = pc.BundleAdjustTwoView(&matchSet,images);
    //
    // ssrlcv::writePLY("out/bundleAdjustedPoints.ply",points);
    // // points->clear();
    // // ========================== REAL BUNDLE ADJUSTMENT ATTEMPT START


    /*
    2 View Reprojection
    */
    // ssrlcv::PointCloudFactory demPoints = ssrlcv::PointCloudFactory();
    //
    // // bunlde adjustment loop would be here. images_vec woudl be modified to minimize the boi
    // unsigned long long int* linearError = (unsigned long long int*) malloc(sizeof(unsigned long long int));
    // float* linearErrorCutoff = (float*) malloc(sizeof(float));
    // ssrlcv::BundleSet bundleSet = demPoints.generateBundles(&matchSet,images);
    //
    // // the version that will be used normally
    // ssrlcv::Unity<float3>* points = demPoints.twoViewTriangulate(bundleSet, linearError);
    // std::cout << "Total Linear Error: " << *linearError << std::endl;
    //
    // // here is a version that will give me individual linear errors
    // ssrlcv::Unity<float>* errors = new ssrlcv::Unity<float>(nullptr,matches->numElements,ssrlcv::cpu);
    // *linearErrorCutoff = 620.0;
    // ssrlcv::Unity<float3>* points2 = demPoints.twoViewTriangulate(bundleSet, errors, linearError, linearErrorCutoff);
    // // then I write them to a csv to see what to heck is goin on
    // ssrlcv::writeCSV(errors->host, (int) errors->numElements, "individualLinearErrors");

    // optional stereo disparity here
    // /*
    // STEREODISPARITY
    // */
    // ssrlcv::PointCloudFactory demPoints = ssrlcv::PointCloudFactory();
    // ssrlcv::Unity<float3>* points = demPoints.stereo_disparity(matches,8.0);
    //

    // delete matches;
    // ssrlcv::writePLY("out/unfiltered.ply",points);
    // delete points;
    // ssrlcv::writePLY("out/filtered.ply",points2);
    // delete points2;

    // clean up the images
    // for(int i = 0; i < imagePaths.size(); ++i){
    //   delete images[i];
    //   delete allFeatures[i];
    // }

    return 0;
  }
  catch (const std::exception &e){
      std::cerr << "Caught exception: " << e.what() << '\n';
      std::exit(1);
  }
  catch (...){
      std::cerr << "Caught unknown exception\n";
      std::exit(1);
  }

}

























































// yeet
