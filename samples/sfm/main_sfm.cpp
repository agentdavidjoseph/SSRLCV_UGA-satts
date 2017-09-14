/*
# Copyright (c) 2014-2015, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// standard includes:
#include <iostream>
#include <string>
#include <memory>
#include <vector>  // added by SSRL
#include <array>   // added by SSRL
#include <fstream> // added by SSRL

// NVidia, VisionWorks, OpenVX includes: 
#include <NVX/nvx.h>
#include <NVX/nvx_timer.hpp>
#include <NVX/sfm/sfm.h>
#include <VX/vx_types.h>

#include "NVX/Application.hpp"
#include "OVX/FrameSourceOVX.hpp"
#include "OVX/Render3DOVX.hpp"
#include "NVX/SyncTimer.hpp"
#include "OVX/UtilityOVX.hpp"

// Sample Includes:
#include "SfM.hpp"
#include "utils.hpp"

// SSRL includes:
//#include "ply.h"

// caleb added:
std::vector<std::array<float, 3>> aggrigate_cloud_vector;
int aggrigate_cloud_num = 0;
int frame_num = 0;
int frame_max = 50;
int frame_inc = 0; // set to 0 to run all frames. set to 1 to run to frame_max
float n_x = 0.0;
float inc = 0.5; //0.6
float n_y = 1.0;
float n_z = 1.0;
// :dedda belac

//
// main - Application entry point
//

int main(int argc, char* argv[])
{
    try
    {
        nvxio::Application &app = nvxio::Application::get();

        //
        // Parse command line arguments
        //

        // TODO: make this a command line arg"
	//std::string sourceUri = app.findSampleFilePath("sfm/Flock_2k_Launch.mp4");
	//std::string sourceUri = app.findSampleFilePath("sfm/carl1024.mp4");
	//std::string sourceUri = app.findSampleFilePath("sfm/bolbicube.mp4");
	std::string sourceUri = app.findSampleFilePath("sfm/bolbicube2.mp4");
	//std::string sourceUri = app.findSampleFilePath("sfm/teapot.mp4");
        //std::string sourceUri = app.findSampleFilePath("sfm/parking_sfm.mp4"); //default
        // TODO: make this a command line arg:
        std::string configFile = app.findSampleFilePath("sfm/sfm_config.ini");
        bool fullPipeline = false, noLoop = false;
        std::string maskFile;

        app.setDescription("This sample demonstrates Structure from Motion (SfM) algorithm");
        app.addOption(0, "mask", "Optional mask", nvxio::OptionHandler::string(&maskFile));
        app.addBooleanOption('f', "fullPipeline", "Run full SfM pipeline without using IMU data", &fullPipeline);
        app.addBooleanOption('n', "noLoop", "Run sample without loop", &noLoop);

        app.init(argc, argv);

        nvx_module_version_t sfmVersion;
        nvxSfmGetVersion(&sfmVersion);
        std::cout << "VisionWorks SFM version: " << sfmVersion.major << "." << sfmVersion.minor
                  << "." << sfmVersion.patch << sfmVersion.suffix << std::endl;

        std::string imuDataFile;
        std::string frameDataFile;
        if (!fullPipeline)
        {
            imuDataFile = app.findSampleFilePath("sfm/imu_data.txt");
            frameDataFile = app.findSampleFilePath("sfm/images_timestamps.txt");
        }

        if (app.getPreferredRenderName() != "default")
        {
            std::cerr << "The sample uses custom Render for GUI. --nvxio_render option is not supported!" << std::endl;
            return nvxio::Application::APP_EXIT_CODE_NO_RENDER;
        }

        //
        // Read SfMParams
        //

        nvx::SfM::SfMParams params;

        std::string msg;
        if (!read(configFile, params, msg))
        {
            std::cerr << msg << std::endl;
            return nvxio::Application::APP_EXIT_CODE_INVALID_VALUE;
        }

        //
        // Create OpenVX context
        //

        ovxio::ContextGuard context;

        NVXIO_SAFE_CALL( vxDirective(context, VX_DIRECTIVE_ENABLE_PERFORMANCE) );

        //
        // Messages generated by the OpenVX framework will be processed by nvxio::stdoutLogCallback
        //

        vxRegisterLogCallback(context, &ovxio::stdoutLogCallback, vx_false_e);

        //
        // Add SfM kernels
        //

        NVXIO_SAFE_CALL(nvxSfmRegisterKernels(context));

        //
        // Create a Frame Source
        //

        std::unique_ptr<ovxio::FrameSource> source(
             ovxio::createDefaultFrameSource(context, sourceUri));

        if (!source || !source->open())
        {
            std::cerr << "Can't open source file: " << sourceUri << std::endl;
            return nvxio::Application::APP_EXIT_CODE_NO_RESOURCE;
        }

        ovxio::FrameSource::Parameters sourceParams = source->getConfiguration();

        //
        // Create OpenVX Image to hold frames from video source
        //

        vx_image frame = vxCreateImage(context,sourceParams.frameWidth, sourceParams.frameHeight, sourceParams.format);
        NVXIO_CHECK_REFERENCE(frame);

        //
        // TODO: Do we need this? A Mask image should not be needed.
        // Load mask image if needed
        //

        vx_image mask = NULL;
        if (!maskFile.empty())
        {
            mask = ovxio::loadImageFromFile(context, maskFile, VX_DF_IMAGE_U8);

            vx_uint32 mask_width = 0, mask_height = 0;
            NVXIO_SAFE_CALL( vxQueryImage(mask, VX_IMAGE_ATTRIBUTE_WIDTH, &mask_width, sizeof(mask_width)) );
            NVXIO_SAFE_CALL( vxQueryImage(mask, VX_IMAGE_ATTRIBUTE_HEIGHT, &mask_height, sizeof(mask_height)) );

            if (mask_width != sourceParams.frameWidth || mask_height != sourceParams.frameHeight)
            {
                std::cerr << "The mask must have the same size as the input source." << std::endl;
                return nvxio::Application::APP_EXIT_CODE_INVALID_DIMENSIONS;
            }
        }

        //
        // Create 3D Render instance
        //
        std::unique_ptr<ovxio::Render3D> render3D(ovxio::createDefaultRender3D(context, 0, 0,
            "SfM Point Cloud", sourceParams.frameWidth, sourceParams.frameHeight));

        ovxio::Render::TextBoxStyle style = {{255, 255, 255, 255}, {0, 0, 0, 255}, {10, 10}};

        if (!render3D)
        {
            std::cerr << "Can't create a renderer" << std::endl;
            return nvxio::Application::APP_EXIT_CODE_NO_RENDER;
        }

        float fovYinRad = 2.f * atanf(sourceParams.frameHeight / 2.f / params.pFy);
        render3D->setDefaultFOV(180.f / ovxio::PI_F * fovYinRad);

        EventData eventData;
        render3D->setOnKeyboardEventCallback(eventCallback, &eventData);

        //
        // Create SfM class instance
        //

        std::unique_ptr<nvx::SfM> sfm(nvx::SfM::createSfM(context, params));

        //
        // TODO: Do we need this? fence detection is really for autonomous driving.
        // Create FenceDetectorWithKF class instance
        //
        FenceDetectorWithKF fenceDetector;


        ovxio::FrameSource::FrameStatus frameStatus;
        do
        {
            // NOTE: These frames are from the video source
            frameStatus = source->fetch(frame);
        }
        while (frameStatus == ovxio::FrameSource::TIMEOUT);

        if (frameStatus == ovxio::FrameSource::CLOSED)
        {
            std::cerr << "Source has no frames" << std::endl;
            return nvxio::Application::APP_EXIT_CODE_NO_FRAMESOURCE;
        }

        vx_status status = sfm->init(frame, mask, imuDataFile, frameDataFile);
        if (status != VX_SUCCESS)
        {
            std::cerr << "Failed to initialize the algorithm" << std::endl;
            return nvxio::Application::APP_EXIT_CODE_ERROR;
        }

        // TODO: figure out what's going on here
        const vx_size maxNumOfPoints = 2000;
        const vx_size maxNumOfPlanesVertices = 2000;

        vx_array filteredPoints = vxCreateArray(context, NVX_TYPE_POINT3F, maxNumOfPoints);
        NVXIO_CHECK_REFERENCE(filteredPoints);
        vx_array planesVertices = vxCreateArray(context, NVX_TYPE_POINT3F, maxNumOfPlanesVertices);
        NVXIO_CHECK_REFERENCE(planesVertices);

        //
        // Run processing loop
        //

        vx_matrix model = vxCreateMatrix(context, VX_TYPE_FLOAT32, 4, 4);
        float eye_data[4*4] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
        NVXIO_SAFE_CALL(vxWriteMatrix(model, eye_data));

        ovxio::Render3D::PointCloudStyle pcStyle = {0, 12};
        ovxio::Render3D::PlaneStyle fStyle = {0, 10};

        GroundPlaneSmoother groundPlaneSmoother(7);

        nvx::Timer totalTimer;
        totalTimer.tic();

        std::unique_ptr<nvxio::SyncTimer> syncTimer = nvxio::createSyncTimer();
        syncTimer->arm(1. / app.getFPSLimit());

        double proc_ms = 0.0;
        float yGroundPlane = 0.0f;

        // NOTE: Some of this section is needed, but not all of it.
        // We should start Identitying what we do and don't need
        while (!eventData.shouldStop)
        {
            if (!eventData.pause)
            {
                frameStatus = source->fetch(frame);

                if (frameStatus == ovxio::FrameSource::TIMEOUT)
                {
                    continue;
                }
                if (frameStatus == ovxio::FrameSource::CLOSED)
                {
                    if(noLoop) break;

                    if (!source->open())
                    {
                        std::cerr << "Failed to reopen the source" << std::endl;
                        break;
                    }

                    do
                    {
                        frameStatus = source->fetch(frame);
                    }
                    while (frameStatus == ovxio::FrameSource::TIMEOUT);

                    sfm->init(frame, mask, imuDataFile, frameDataFile);

                    fenceDetector.reset();

                    continue;
                }

                // Process
                nvx::Timer procTimer;
                procTimer.tic();
                sfm->track(frame, mask);
                proc_ms = procTimer.toc();
            }

            // Print performance results
            sfm->printPerfs();

            if (!eventData.showPointCloud)
            {
                render3D->disableDefaultKeyboardEventCallback();
                render3D->putImage(frame);
            }
            else
            {
                render3D->enableDefaultKeyboardEventCallback();
            }

            filterPoints(sfm->getPointCloud(), filteredPoints);
            render3D->putPointCloud(filteredPoints, model, pcStyle);

	    // aggrigate points here??
	    //============================================ begin C-lab

	    //if (aggrigate_cloud_num % 5 == 0)
	    n_x += inc; // because we're moving in the x direction
	    vx_size a_size = 0;
	    vx_array aggrigate_cloud = sfm->getPointCloud();
	    frame_num += frame_inc;

	    if (frame_num < frame_max){
	    NVXIO_SAFE_CALL( vxQueryArray(aggrigate_cloud, VX_ARRAY_ATTRIBUTE_NUMITEMS, &a_size, sizeof(a_size)) );
	    
	    if (a_size > 0)
	      {
		void *in_ptr = 0;
		vx_size in_stride = 0;
		
		NVXIO_SAFE_CALL( vxAccessArrayRange(aggrigate_cloud, 0, a_size, &in_stride, &in_ptr, VX_READ_ONLY) );
		
		for (vx_size i = 0; i < a_size; ++i)
		  {
		    nvx_point3f_t pt = vxArrayItem(nvx_point3f_t, in_ptr, i, in_stride);
		    
		    if (isPointValid(pt))
		      {
			//std::cout << "x: " << pt.x << std::endl;
			//std::cout << "y: " << pt.y << std::endl;
			//std::cout << "z: " << pt.z << std::endl; 			
			aggrigate_cloud_num++;
			// add them to a vector:
			//if (aggrigate_cloud_num % 5 == 0)
			aggrigate_cloud_vector.push_back({pt.x + n_x,pt.y * n_y,pt.z * n_z});
		      }
		  }
		
		NVXIO_SAFE_CALL( vxCommitArrayRange(aggrigate_cloud, 0, 0, in_ptr) );
	      }
	    }
	    
	    //============================================ end C-lab
	    
	    
            // NOTE: not needed
            if (eventData.showFences)
            {
                fenceDetector.getFencePlaneVertices(filteredPoints, planesVertices);
                render3D->putPlanes(planesVertices, model, fStyle);
            }

            // NOTE: not needed
            if (fullPipeline && eventData.showGP)
            {
                const float x1(-1.5f), x2(1.5f), z1(1.0f), z2(4.0f);

                vx_matrix gp = sfm->getGroundPlane();
                NVXIO_CHECK_REFERENCE(gp);

                yGroundPlane = groundPlaneSmoother.getSmoothedY(gp, x1, z1);

                nvx_point3f_t pt[4] = {{x1, yGroundPlane, z1},
                                       {x1, yGroundPlane, z2},
                                       {x2, yGroundPlane, z2},
                                       {x2, yGroundPlane, z1}};

                vx_array gpPoints = vxCreateArray(context, NVX_TYPE_POINT3F, 4);
                NVXIO_SAFE_CALL( vxAddArrayItems(gpPoints, 4, pt, sizeof(pt[0])) );

                render3D->putPlanes(gpPoints, model, fStyle);
                NVXIO_SAFE_CALL( vxReleaseArray(&gpPoints) );
            }

            // Add a delay to limit frame rate
            syncTimer->synchronize();

            double total_ms = totalTimer.toc();
            totalTimer.tic();

            std::string state = createInfo(fullPipeline, proc_ms, total_ms, eventData);
            render3D->putText(state.c_str(), style);

            if (!render3D->flush())
            {
                eventData.shouldStop = true;
            }
        }

//============================================ begin C-lab
        // try getting the point cloud here?
        vx_array cloud = sfm->getPointCloud();

	std::cout << "======= TESTING" << std::endl;
	
	std::cout << "sfm->getPointCloud(): ";  
        std::cout << sfm->getPointCloud() << std::endl;

	std::cout << "&filteredPoints: ";
	std::cout << &filteredPoints << std::endl;

	std::cout << "filteredPoints: ";
	std::cout << filteredPoints << std::endl;
	
	std::cout << "======= END TEST" << std::endl;

	std::cout << "========================" << std::endl;
	std::cout << "=>> point cloud info <<=\n";
	std::cout << "========================" << std::endl;

	// TODO: abstract the hell out of this
	
	typedef struct Vertex {
	  float x,y,z;             /* the usual 3-space position of a vertex */
	} Vertex;
	
	vx_size test_size = 0;
	std::vector<std::array<float, 3>> valid_point_vector;
	std::vector<std::array<float, 3>> total_point_vector;
	int valid_point_count = 0;
	int total_point_count = 0;
	NVXIO_SAFE_CALL( vxQueryArray(cloud, VX_ARRAY_ATTRIBUTE_NUMITEMS, &test_size, sizeof(test_size)) );
	
	if (test_size > 0)
	  {
	    void *in_ptr = 0;
	    vx_size in_stride = 0;
	    
	    NVXIO_SAFE_CALL( vxAccessArrayRange(cloud, 0, test_size, &in_stride, &in_ptr, VX_READ_ONLY) );

	    for (vx_size i = 0; i < test_size; ++i)
	      {
		nvx_point3f_t pt = vxArrayItem(nvx_point3f_t, in_ptr, i, in_stride);
		
		if (isPointValid(pt))
		  {
		    //std::cout << "x: " << pt.x << std::endl;
		    //std::cout << "y: " << pt.y << std::endl;
		    //std::cout << "z: " << pt.z << std::endl; 
		    
		    valid_point_count++;
		    // add them to a vector:
		    valid_point_vector.push_back({pt.x,pt.y,pt.z});
		  }
		// make total point cloud here:
		total_point_count++;
		total_point_vector.push_back({pt.x,pt.y,pt.z});
	      }
	    
	    NVXIO_SAFE_CALL( vxCommitArrayRange(cloud, 0, 0, in_ptr) );
	  }
	
	std::cout << "valid points: \t" << valid_point_count << std::endl;
	std::cout << "total points: \t" << total_point_count << std::endl;
	std::cout << "aggrigate points: \t" << aggrigate_cloud_num << std::endl;
	
	// output the 
	std::ofstream output_ply;
	output_ply.open("output_valid.ply");
	output_ply << "ply\nformat ascii 1.0\nelement vertex ";
	output_ply << valid_point_count << "\n";
	output_ply << "property float x\nproperty float y\nproperty float z\n";
	output_ply << "end_header\n";
	// add the points, don't judge me
	for(int i = 0; i < valid_point_vector.size(); i++){
	  output_ply << valid_point_vector[i][0] << " " << valid_point_vector[i][1] << " " << valid_point_vector[i][2] << "\n";
	} 
	output_ply.close();

	std::ofstream output_ply_2;
	output_ply_2.open("output_total.ply");
	output_ply_2 << "ply\nformat ascii 1.0\nelement vertex ";
	output_ply_2 << total_point_count << "\n";
	output_ply_2 << "property float x\nproperty float y\nproperty float z\n";
	output_ply_2 << "end_header\n";
	// add the points, don't judge me
	for(int i = 0; i < total_point_vector.size(); i++){
	  output_ply_2 << total_point_vector[i][0] << " " << total_point_vector[i][1] << " " << total_point_vector[i][2] << "\n";
	} 
	output_ply_2.close();

	std::ofstream output_ply_3;
	output_ply_3.open("output_aggrigate.ply");
	output_ply_3 << "ply\nformat ascii 1.0\nelement vertex ";
	output_ply_3 << aggrigate_cloud_num << "\n";
	output_ply_3 << "property float x\nproperty float y\nproperty float z\n";
	output_ply_3 << "end_header\n";
	// add the points, don't judge me
	for(int i = 0; i < aggrigate_cloud_vector.size(); i++){
	  output_ply_3 << aggrigate_cloud_vector[i][0] << " " << aggrigate_cloud_vector[i][1] << " " << aggrigate_cloud_vector[i][2] << "\n";
	}
	output_ply_3.close();
	
//============================================ end C-lab

	//
        // Release all objects
        //

        vxReleaseImage(&frame);
        vxReleaseImage(&mask);
        vxReleaseMatrix(&model);
        vxReleaseArray(&filteredPoints);
        vxReleaseArray(&planesVertices);
    }
    catch (const std::exception& e)
    {
        std::cerr << "Error: " << e.what() << std::endl;
        return nvxio::Application::APP_EXIT_CODE_ERROR;
    }

    return nvxio::Application::APP_EXIT_CODE_SUCCESS;
}
