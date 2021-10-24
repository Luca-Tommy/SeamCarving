﻿#include "image_handler.h"
#include "seam_carving.h"
#include "utils.h"
#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "cuda_runtime.h"
#include "cuda_runtime_api.h"
#include "device_launch_parameters.h"

char* src_path;

void applySeamCarving(char *p, int iterations) {

	imgProp_t* imgProp;

	pixel_t* imgSrc;
	pixel_t* imgWithoutSeamSrc;
	
	energyPixel_t* imgGray;
	energyPixel_t* imgWithoutSeamGray;
	
	seam_t* seams;
	seam_t* minSeamsPerBlock;
	seam_t* minSeam;

	FILE* f = fopen(p, "rb");
	if (f == NULL) {
		printf("*** FILE NOT FOUND %s ***\n", p);
		exit(1);
	}

	gpuErrchk(cudaMallocManaged(&imgProp, sizeof(imgProp_t)));
	setupImgProp(imgProp, f);

	gpuErrchk(cudaMallocManaged(&imgSrc, imgProp->imageSize * sizeof(pixel_t)));
	gpuErrchk(cudaMallocManaged(&imgGray, imgProp->imageSize * sizeof(energyPixel_t)));
	gpuErrchk(cudaMallocManaged(&imgWithoutSeamSrc, (imgProp->imageSize - (imgProp->height * iterations)) * sizeof(pixel_t)));
	gpuErrchk(cudaMallocManaged(&imgWithoutSeamGray, imgProp->imageSize * sizeof(energyPixel_t)));

	gpuErrchk(cudaMallocManaged(&minSeam, sizeof(seam_t)));
	gpuErrchk(cudaMallocManaged(&minSeam->ids, imgProp->height * sizeof(int)));

	gpuErrchk(cudaMallocManaged(&seams, imgProp->width * sizeof(seam_t)));
	for (int i = 0; i < imgProp->width; i++)
		gpuErrchk(cudaMallocManaged(&seams[i].ids, imgProp->height * sizeof(int)));

	int numBlocks = imgProp->width / 1024 + 1;
	gpuErrchk(cudaMallocManaged(&minSeamsPerBlock, numBlocks * sizeof(seam_t)));
	for (int i = 0; i < numBlocks; i++)
		gpuErrchk(cudaMallocManaged(&minSeamsPerBlock[i].ids, imgProp->height * sizeof(int)));

	gpuErrchk(cudaMallocManaged(&imgWithoutSeamGray, imgProp->imageSize * sizeof(energyPixel_t)));

	readBMP(f, imgSrc, imgProp);
	toGrayScale(imgSrc, imgGray, imgProp);
	
	for (int i = 0; i < iterations; i++) {
		//energyMap(imgGray, imgProp);		
		//findSeams(imgGray, imgSrc, imgProp, minSeam, seams, minSeamsPerBlock);
		apply(imgGray, imgSrc, imgProp, minSeam, seams, minSeamsPerBlock, imgWithoutSeamGray);
		//removeSeam(imgGray, imgWithoutSeamGray, minSeam, imgProp);
		printf("ITERAZIONE %d COMPLETATA\n", i);
	}

	removePixelsFromSrc(imgSrc, imgWithoutSeamSrc, imgGray, imgProp);

	setBMP_header(imgProp, 0, imgProp->width);
	writeBMP_pixel("C:\\aa\\reduced.bmp", imgWithoutSeamSrc, imgProp);
		
	fclose(f);
}

int main(int argc, char** argv) {

	/*
		cudaDeviceProp deviceProp;
		cudaGetDeviceProperties(&deviceProp, dev);
	*/

	char* path = argv[1];
	int iterations = atoi(argv[2]);

	applySeamCarving(path, iterations);
	cudaDeviceReset();

	return 0;
}
