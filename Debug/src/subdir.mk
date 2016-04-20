################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
CU_SRCS += \
../src/Mandelbrot.cu \
../src/Mandelbrot_cuda.cu 

CPP_SRCS += \
../src/Mandelbrot_gold.cpp 

OBJS += \
./src/Mandelbrot.o \
./src/Mandelbrot_cuda.o \
./src/Mandelbrot_gold.o 

CU_DEPS += \
./src/Mandelbrot.d \
./src/Mandelbrot_cuda.d 

CPP_DEPS += \
./src/Mandelbrot_gold.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.cu
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	/Developer/NVIDIA/CUDA-7.5/bin/nvcc -I"/Developer/NVIDIA/CUDA-7.5/samples/common/inc" -I"/Users/admin/cuda-workspace/CUDAMachineLearning" -G -g -O0 -gencode arch=compute_30,code=sm_30  -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	/Developer/NVIDIA/CUDA-7.5/bin/nvcc -I"/Developer/NVIDIA/CUDA-7.5/samples/common/inc" -I"/Users/admin/cuda-workspace/CUDAMachineLearning" -G -g -O0 --compile --relocatable-device-code=false -gencode arch=compute_30,code=compute_30 -gencode arch=compute_30,code=sm_30  -x cu -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/%.o: ../src/%.cpp
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	/Developer/NVIDIA/CUDA-7.5/bin/nvcc -I"/Developer/NVIDIA/CUDA-7.5/samples/common/inc" -I"/Users/admin/cuda-workspace/CUDAMachineLearning" -G -g -O0 -gencode arch=compute_30,code=sm_30  -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	/Developer/NVIDIA/CUDA-7.5/bin/nvcc -I"/Developer/NVIDIA/CUDA-7.5/samples/common/inc" -I"/Users/admin/cuda-workspace/CUDAMachineLearning" -G -g -O0 --compile  -x c++ -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


