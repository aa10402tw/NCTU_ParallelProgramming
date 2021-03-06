/**********************************************************************
 * DESCRIPTION:
 *   Serial Concurrent Wave Equation - C Version
 *   This program implements the concurrent wave equation
 *********************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#define MAXPOINTS 1000000
#define MAXSTEPS 1000000
#define MINPOINTS 20
#define PI 3.14159265

void check_param(void);
void init_line(void);
void update(void);
void printfinal(void);


/**********************************************************************
 *  Checks input values from parameters
 *********************************************************************/
void check_param(int nsteps, int tpoints)
{
	char tchar[20];

	/* check number of points, number of iterations */
	while ((tpoints < MINPOINTS) || (tpoints > MAXPOINTS)) {
		printf("Enter number of points along vibrating string [%d-%d]: "
			, MINPOINTS, MAXPOINTS);
		scanf("%s", tchar);
		tpoints = atoi(tchar);
		if ((tpoints < MINPOINTS) || (tpoints > MAXPOINTS))
			printf("Invalid. Please enter value between %d and %d\n",
				MINPOINTS, MAXPOINTS);
	}
	while ((nsteps < 1) || (nsteps > MAXSTEPS)) {
		printf("Enter number of time steps [1-%d]: ", MAXSTEPS);
		scanf("%s", tchar);
		nsteps = atoi(tchar);
		if ((nsteps < 1) || (nsteps > MAXSTEPS))
			printf("Invalid. Please enter value between 1 and %d\n", MAXSTEPS);
	}

	printf("Using points = %d, steps = %d\n", tpoints, nsteps);

}

/**********************************************************************
 *     Initialize points on line
 *********************************************************************/
void init_line(float* oldval, float* values, int tpoints)
{
	int i, j;
	float x, fac, k, tmp;

	/* Calculate initial values based on sine curve */
	fac = 2.0 * PI;
	k = 0.0;
	tmp = tpoints - 1;
	for (j = 1; j <= tpoints; j++) {
		x = k / tmp;
		values[j] = sin(fac * x);
		k = k + 1.0;
	}

	/* Initialize old values array */
	for (i = 1; i <= tpoints; i++)
		oldval[i] = values[i];
}

/**********************************************************************
 *      Calculate new values using wave equation
 *********************************************************************/
void do_math(float* oldval, float* values, float* newval, int i)
{
	float dtime, c, dx, tau, sqtau;

	dtime = 0.3;
	c = 1.0;
	dx = 1.0;
	tau = (c * dtime / dx);
	sqtau = tau * tau;
	newval[i] = (2.0 * values[i]) - oldval[i] + (sqtau *  (-2.0)*values[i]);
}

/**********************************************************************
 *     Update all values along line a specified number of times
 *********************************************************************/
void update(float* oldval, float* values, float* newval, int nsteps, int tpoints)
{
	int i, j;

	/* Update values for each time step */
	for (i = 1; i <= nsteps; i++) {
		/* Update points along line for this time step */
		for (j = 1; j <= tpoints; j++) {
			/* global endpoints */
			if ((j == 1) || (j == tpoints))
				newval[j] = 0.0;
			else
				do_math(oldval, values, newval, j);
		}

		/* Update old values with new values */
		for (j = 1; j <= tpoints; j++) {
			oldval[j] = values[j];
			values[j] = newval[j];
		}
	}
}

/**********************************************************************
 *     Print final results
 *********************************************************************/
void printfinal(float* values, int tpoints)
{
	int i;

	for (i = 1; i <= tpoints; i++) {
		printf("%6.4f ", values[i]);
		if (i % 10 == 0)
			printf("\n");
	}
}

__global__ void init_line_kernel(float* oldval, float* values, int tpoints) {
	//int i, j;
	float x, fac, k, tmp;
	
	int tid = blockIdx.x * blockDim.x + threadIdx.x;
	int offset = blockDim.x * gridDim.x; // Total number of threads
	if (tid == 0) {
		printf("gridDim   (%d, %d, %d)\n", gridDim.x, gridDim.y, gridDim.z);
		printf("blockDim   (%d, %d, %d)\n", blockDim.x, blockDim.y, blockDim.z);
	}
	
	fac = 2.0 * PI;
	tmp = (float)(tpoints - 1);

	for (int idx = tid; idx <= tpoints; idx += offset) {
		if (idx >= 1) {
			k = (float)(idx - 1);
			x = k / tmp;
			values[idx] = __sinf(fac * x);
			oldval[idx] = values[idx];
		}	
	}
}

__global__ void update_kernel(float* oldval, float* values, float* newval, int nsteps, int tpoints)
{
	int i, j;
	int tid = blockIdx.x * blockDim.x + threadIdx.x; // threadId
	int offset = blockDim.x * gridDim.x; // Total number of threads

	/* Update values for each time step */
	for (i = 1; i <= nsteps; i++) {
		for (int j = tid; j <= tpoints; j += offset) {
			/* global endpoints */
			if ((j == 1) || (j == tpoints))
				newval[j] = 0.0;
			else {
				float dtime, c, dx, tau, sqtau;
				dtime = 0.3;
				c = 1.0;
				dx = 1.0;
				tau = (c * dtime / dx);
				sqtau = tau * tau;
				newval[j] = (2.0 * values[j]) - oldval[j] + (sqtau *  (-2.0)*values[j]);
			}
			/* Update old values with new values */
			oldval[j] = values[j];
			values[j] = newval[j];
		}
	}
}
void checkIsSame(float* A, float* B, int n) {
	for (int i = 0; i < n; i++) {
		// printf("%d : (%f, %f) [%f]\n", i, A[i], B[i], A[i]-B[i]);
		if ( A[i] - B[i] > 0.0001 || A[i] - B[i] < -0.0001) {
			printf("\n\nDifferent at %d (%f v.s %f)\n", i, A[i], B[i]);
			return;
		}
			
	}
	printf("\n\nIs Same\n");
}

/**********************************************************************
 *  Main program
 *********************************************************************/
int main(int argc, char *argv[])
{
	int nsteps,                     /* number of time steps */
		tpoints,					/* total points along string */
		rcode;                      /* generic return code */

	sscanf(argv[1], "%d", &tpoints);
	sscanf(argv[2], "%d", &nsteps);
	check_param(nsteps, tpoints);

	int threadsPerBlock = 512;
	int numBlocks = (tpoints / threadsPerBlock) + 1;

	threadsPerBlock = 10;
	numBlocks = 1;

	float *oldval, *values, *newval;
	float *cpu_val, *gpu_val;

	/******************/
	/* Initialization */
	/******************/
	// CPU
	printf("\n\n--- [CPU Version Init] ---\n");
	oldval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t-dt) */
	values = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time t */
	newval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t+dt) */
	init_line(oldval, values, tpoints);
	//printfinal(values, tpoints);

	// Debug
	cpu_val = (float*)malloc((MAXPOINTS + 2) * sizeof(float));
	for (int i = 0; i <= tpoints; i++)
		cpu_val[i] = values[i];

	// GPU 
	printf("\n\n--- [GPU Version Init] ---\n");
	oldval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t-dt) */
	values = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time t */
	newval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t+dt) */

	float *gpu_oldval, *gpu_values, *gpu_newval;
	cudaMalloc(&gpu_oldval, (MAXPOINTS + 2) * sizeof(float));
	cudaMalloc(&gpu_values, (MAXPOINTS + 2) * sizeof(float));
	cudaMalloc(&gpu_newval, (MAXPOINTS + 2) * sizeof(float));

	init_line_kernel <<<numBlocks, threadsPerBlock>>> (gpu_oldval, gpu_values, tpoints);

	cudaMemcpy(oldval, gpu_oldval, (MAXPOINTS + 2) * sizeof(float), cudaMemcpyDeviceToHost);
	cudaMemcpy(values, gpu_values, (MAXPOINTS + 2) * sizeof(float), cudaMemcpyDeviceToHost);
	cudaMemcpy(newval, gpu_newval, (MAXPOINTS + 2) * sizeof(float), cudaMemcpyDeviceToHost);
	// printfinal(values, tpoints);

	// Debug
	gpu_val = (float*)malloc((MAXPOINTS + 2) * sizeof(float));
	for (int i = 0; i <= tpoints; i++)
		gpu_val[i] = values[i];

	// Check 
	checkIsSame(cpu_val, gpu_val, tpoints+1);



	/**********/
	/* Update */
	/**********/

	// CPU
	printf("\n\n--- [CPU Version Update] ---\n");
	oldval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t-dt) */
	values = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time t */
	newval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t+dt) */
	init_line(oldval, values, tpoints);
	update(oldval, values, newval, nsteps, tpoints);
	//printfinal(values, tpoints);

	// Debug
	cpu_val = (float*)malloc((MAXPOINTS + 2) * sizeof(float));
	for (int i = 0; i <= tpoints; i++)
		cpu_val[i] = values[i];

	// GPU 
	printf("\n\n--- [GPU Version Update] ---\n");
	oldval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t-dt) */
	values = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time t */
	newval = (float*)malloc((MAXPOINTS + 2) * sizeof(float)); /* values at time (t+dt) */

	cudaMalloc(&gpu_oldval, (MAXPOINTS + 2) * sizeof(float));
	cudaMalloc(&gpu_values, (MAXPOINTS + 2) * sizeof(float));
	cudaMalloc(&gpu_newval, (MAXPOINTS + 2) * sizeof(float));

	//int threadsPerBlock = 10;
	//int numBlocks = (tpoints / threadsPerBlock) + 1;
	init_line_kernel <<<numBlocks, threadsPerBlock>>> (gpu_oldval, gpu_values, tpoints);
	update_kernel <<<numBlocks, threadsPerBlock >>> (gpu_oldval, gpu_values, gpu_newval, nsteps, tpoints);

	cudaMemcpy(oldval, gpu_oldval, (MAXPOINTS + 2) * sizeof(float), cudaMemcpyDeviceToHost);
	cudaMemcpy(values, gpu_values, (MAXPOINTS + 2) * sizeof(float), cudaMemcpyDeviceToHost);
	cudaMemcpy(newval, gpu_newval, (MAXPOINTS + 2) * sizeof(float), cudaMemcpyDeviceToHost);
	//printfinal(values, tpoints);

	// Debug
	gpu_val = (float*)malloc((MAXPOINTS + 2) * sizeof(float));
	for (int i = 0; i <= tpoints; i++)
		gpu_val[i] = values[i];

	// Check 
	checkIsSame(cpu_val, gpu_val, tpoints + 1);


	return 0;
}