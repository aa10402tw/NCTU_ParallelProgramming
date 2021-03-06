#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

// Kernel function
__global__ void VecAdd(float* A, float* B, float* C) 
{
	int i = threadIdx.x;
	C[i] = A[i] + B[i];
}

int main() 
{
	int N = 10;

	// Allocate CPU Memory
	float* A = (float*)malloc(N * sizeof(float));
	float* B = (float*)malloc(N * sizeof(float));
	float* C = (float*)malloc(N * sizeof(float));

	// Allocate GPU Memory
	float *gpu_A, *gpu_B, *gpu_C;
	cudaMalloc(&gpu_A, N * sizeof(float));
	cudaMalloc(&gpu_B, N * sizeof(float));
	cudaMalloc(&gpu_C, N * sizeof(float));

	// Init value
	for (int i = 0; i < N; i++) {
		A[i] = i;
		B[i] = 2 * i;
		C[i] = 0;
	}

	// Copy Data from CPU memory to GPU memory
	cudaMemcpy(gpu_A, A, N * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(gpu_B, B, N * sizeof(float), cudaMemcpyHostToDevice);
	cudaMemcpy(gpu_C, C, N * sizeof(float), cudaMemcpyHostToDevice);

	// GPU function (launch kernel function)
	VecAdd <<<1, N>>> (gpu_A, gpu_B, gpu_C);

	// Copy Data from GPU memory to CPU memory
	cudaMemcpy(A, gpu_A, N * sizeof(float), cudaMemcpyDeviceToHost);
	cudaMemcpy(B, gpu_B, N * sizeof(float), cudaMemcpyDeviceToHost);
	cudaMemcpy(C, gpu_C, N * sizeof(float), cudaMemcpyDeviceToHost);

	// Print Result
	for (int i = 0; i < N; i++) {
		printf("%f,", C[i]);
	}
	return 0;
}