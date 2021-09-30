﻿#include "image_handler.h"

#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "cuda_runtime.h"
#include "cuda_runtime_api.h"
#include "device_launch_parameters.h"

ImgProp ip;

__global__ void toGrayScale()
{
	printf("%d", threadIdx.x);
}

void setupImgProp(ImgProp* ip, FILE* f) {
	pel headerInfo[54];
	fread(headerInfo, sizeof(pel), 54, f);

	int width = *(int*)&headerInfo[18];
	int height = *(int*)&headerInfo[22];
	int rowBytes = (width * 3 + 3) & (~3);

	for (unsigned int i = 0; i < 54; i++)
		ip->HeaderInfo[i] = headerInfo[i];

	ip->Vpixels = height;
	ip->Hpixels = width;
	ip->Hbytes = rowBytes;
}

pel** ReadBMP(char* p) {
	//BMP LEGGE I PIXEL NEL FORMATO BGR
	FILE* f = fopen(p, "rb");
	if (f == NULL) {
		printf("*** FILE NOT FOUND ***\n");
		exit(1);
	}

	//extract information from headerInfo
	setupImgProp(&ip, f);
	printf("Input BMP dimension: (%u x %u)\n", ip.Hpixels, ip.Vpixels);

	pel** img;

	cudaMallocManaged(&img, ip.Vpixels * sizeof(pel*), 0);
	for (unsigned int i = 0; i < ip.Hpixels; i++)
		cudaMallocManaged(&img[i], ip.Hbytes * sizeof(pel), 0);

	for (unsigned int i = 0; i < ip.Vpixels; i++) {
		fread(img[i], sizeof(pel), ip.Hbytes, f);
	}

	toGrayScale << <1, 50 >> > ();

	fclose(f);
	return img;
}