﻿#include "image_handler.h"
#include "seam_carving.h"
#include "utils.h"

#include <stdio.h>
#include <stdlib.h>
#include <iostream>

#include "cuda_runtime.h"
#include "cuda_runtime_api.h"
#include "device_launch_parameters.h"

#define MAX_THREAD 1024


__device__ void grayValue(pixel_t *res, pel_t r, pel_t g, pel_t b) {
	int grayVal = (r + g + b) / 3;
	res->R = grayVal;
	res->G = grayVal;
	res->B = grayVal;
}

__global__ void toGrayScale_(pixel_t* img, energyPixel_t* imgGray, int imageSize)
{
	int id = blockIdx.x * blockDim.x + threadIdx.x;
	if(id == gridDim.x * 1024 + 1)
		printf("%d", gridDim.x);

	if (id < imageSize) {
		grayValue(&imgGray[id].pixel, img[id].R, img[id].G, img[id].B);
	}
}

void toGrayScale(pixel_t* img, energyPixel_t* imgGray, imgProp_t* imgProp) {
	dim3 blocks;
	blocks.x = imgProp->imageSize / 1024 + 1;

	toGrayScale_<< <blocks, 1024 >> > (img, imgGray, imgProp->imageSize);
	cudaDeviceSynchronize();
	writeBMP_pixel(strcat(SOURCE_PATH, "gray.bmp"), energy2pixel(imgGray, imgProp), imgProp);
}

void setupImgProp(imgProp_t* imgProp, FILE* f) {
	pel_t headerInfo[54];
	fread(headerInfo, sizeof(pel_t), 54, f);


	int width = *(int*)&headerInfo[18];
	int height = *(int*)&headerInfo[22];
	printf("#bytes: %d\n", *(int*)&headerInfo[34]);

	for (unsigned int i = 0; i < 54; i++)
		imgProp->headerInfo[i] = headerInfo[i];

	imgProp->height = height;
	imgProp->width = width;
	imgProp->imageSize = width * height;

	printf("Input BMP dimension: (%u x %u)\n", imgProp->width, imgProp->height);
	printf("IHeader[2] %d\n", *(int*)&headerInfo[2]);
}

void readBMP(FILE *f, pixel_t* img, imgProp_t* imgProp) {
	//img[0] = B
	//img[1] = G
	//img[2] = R
	//BMP LEGGE I PIXEL NEL FORMATO BGR
	for (unsigned int i = 0; i < imgProp->height * imgProp->width; i++) {
		fread(&img[i], sizeof(pel_t), sizeof(pixel_t), f);
	}
}

void writeBMP_pixel(char* p, pixel_t* img, imgProp_t* ip) {
	FILE* fw = fopen(p, "wb");

	fwrite(ip->headerInfo, sizeof(pel_t), 54, fw);
	fwrite(img, sizeof(pixel_t), ip->imageSize, fw);

	fclose(fw);
	printf("Immagine %s generata\n", p);
}

void writeBMP_energy(char* p, energyPixel_t* energyImg, imgProp_t* ip) {
	pixel_t* img;
	int sd = 1;
	img = (pixel_t*)malloc(ip->imageSize * sizeof(pixel_t));

	for (int i = 0; i < ip->imageSize; i++) {
		img[i].R = energyImg[i].energy;
		img[i].G = energyImg[i].energy;
		img[i].B = energyImg[i].energy;
	}

	writeBMP_pixel(p, img, ip);
}

void writeBMP_minimumSeam(char* p, energyPixel_t* energyImg, seam_t* minSeam, imgProp_t* imgProp) {
	for (int y = 0; y < imgProp->height; y++) {
		printf("PATH: %d\n", minSeam[0].ids[y]);
		energyImg[minSeam[0].ids[y]].pixel.R = 0;
		energyImg[minSeam[0].ids[y]].pixel.G = 255;
		energyImg[minSeam[0].ids[y]].pixel.B = 0;
	}
	writeBMP_pixel(strcat(SOURCE_PATH, "seams_map_minimum.bmp"), energy2pixel(energyImg, imgProp), imgProp);
}

pixel_t* energy2pixel(energyPixel_t* energyImg, imgProp_t* ip) {
	pixel_t* img;
	img = (pixel_t*)malloc(ip->imageSize * sizeof(pixel_t));

	for (int i = 0; i < ip->imageSize; i++) {
		img[i] = energyImg[i].pixel;
	}

	return img;
}


void writeBMPHeader(char* p, energyPixel_t* energyImg, imgProp_t* ip, int newSize) {

	printf("Original image size = %d\n", ip->imageSize);
	printf("new size byte= %d\n", newSize);
	pixel_t* img;

	printf("new image size = %d\n", (newSize -54 )/3);
	printf("new image size 2 = %d\n", (ip->imageSize - ip->height));

	
	ip->headerInfo[2] = (unsigned char)(newSize >> 0) & 0xff;
	ip->headerInfo[3] = (unsigned char)(newSize >> 8) & 0xff;
	ip->headerInfo[4] = (unsigned char)(newSize >> 16) & 0xff;
	ip->headerInfo[5] = (unsigned char)(newSize >> 24) & 0xff;


	
	//printf("#bytes: %x\n", *(int*)&(ip->headerInfo[2]));

	int newWidth = ip->width - 1;

	ip->imageSize =(newSize- 54) /3;
	ip->width = newWidth;

	//ip->headerInfo[18] = newWidth;

	ip->headerInfo[18] = (unsigned char)(newWidth >> 0) & 0xff;
	ip->headerInfo[19] = (unsigned char)(newWidth >> 8) & 0xff;
	ip->headerInfo[20] = (unsigned char)(newWidth >> 16) & 0xff;
	ip->headerInfo[21] = (unsigned char)(newWidth >> 24) & 0xff;
	
	//printf("newWidth  = %d\n", *(int*)&(ip->headerInfo[18]));
	img = (pixel_t*)malloc(ip->imageSize * sizeof(pixel_t));

	for (int i = 0; i < ip->imageSize; i++) {
		img[i].R = energyImg[i].energy;
		img[i].G = energyImg[i].energy;
		img[i].B = energyImg[i].energy;
	}

	//writeBMP_pixel(p, img, ip);*/
}

//void writeBMP_pel(char* p, imgProp imgProp, pel* img) {
//	FILE* fw = fopen(p, "wb");
//
//	//0000 0000 0001 0101 0001 0111 1010 0000
//	imgProp.headerInfo[34] = ip.imageSize >> 0;//0xa0;
//	imgProp.headerInfo[35] = ip.imageSize >> 8;//0x17;
//	imgProp.headerInfo[36] = ip.imageSize >> 16;//0x15;
//	imgProp.headerInfo[37] = ip.imageSize >> 24;//0x0;
//	
//	printf("%ld; %d", imgProp.headerInfo[34], imgProp.height * imgProp.width);
//	fwrite(imgProp.headerInfo, sizeof(pel), 54, fw);
//	fwrite(img, sizeof(pel), imgProp.height * imgProp.width, fw);
//
//	fclose(fw);
//}