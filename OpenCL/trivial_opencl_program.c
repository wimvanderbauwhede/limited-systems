// Taken from https://wiki.aalto.fi/display/t1065450/opencl+tutorial+2015
#include <stdio.h>
#include <stdlib.h>
#define CL_USE_DEPRECATED_OPENCL_1_1_APIS  
#ifdef __APPLE__
#include <OpenCL/opencl.h>
#else
#include <CL/cl.h>
#endif
 
/* A kernel which does nothing */
const char * source_str  = "__kernel void foo(void)"
                           "{"
                           "/* do nothing */"
                           "}";
 
int main(void) {
 
    /* Get platform and device information */
    cl_platform_id platform_id = NULL;
    cl_device_id device_id = NULL;   
    cl_uint num_devices;
    cl_uint num_platforms;
    cl_int ret = clGetPlatformIDs(1, &platform_id, &num_platforms);
    ret = clGetDeviceIDs( platform_id, CL_DEVICE_TYPE_CPU, 1, &device_id, &num_devices);
  
    /* Create an OpenCL context */
    cl_context context = clCreateContext( NULL, 1, &device_id, NULL, NULL, &ret);
  
    /* Create a command queue */
    cl_command_queue command_queue = clCreateCommandQueue(context, device_id, 0, &ret);
  
    /* Create a program from the kernel source */
    cl_program program = clCreateProgramWithSource(context, 1, &source_str, NULL, &ret);
  
    /* Build the program */
    ret = clBuildProgram(program, 1, &device_id, NULL, NULL, NULL);
  
    /* Create the OpenCL kernel */
    cl_kernel kernel = clCreateKernel(program, "foo", &ret);
  
    /* Execute the OpenCL kernel */
    size_t global_item_size = 1;
    size_t local_item_size = 1;
    ret = clEnqueueNDRangeKernel(command_queue, kernel, 1, NULL, 
            &global_item_size, &local_item_size, 0, NULL, NULL);
 
    ret = clFlush(command_queue);
    ret = clFinish(command_queue);
 
    if (ret == CL_SUCCESS)
        printf("Success\n");
    else
        printf("OpenCL error executing kernel: %d\n", ret); 
  
    /* Clean up */
    ret = clReleaseKernel(kernel);
    ret = clReleaseProgram(program);
    ret = clReleaseCommandQueue(command_queue);
    ret = clReleaseContext(context);
    return 0;
}
