// OpenGL Graphics includes
#include <GL/glew.h>
#if defined(WIN32) || defined(_WIN32) || defined(WIN64) || defined(_WIN64)
#include <GL/wglew.h>
#endif
#if defined(__APPLE__) || defined(__MACOSX)
  #pragma clang diagnostic ignored "-Wdeprecated-declarations"
  #include <GLUT/glut.h>
  #ifndef glutCloseFunc
  #define glutCloseFunc glutWMCloseFunc
  #endif
#else
#include <GL/freeglut.h>
#endif

// CUDA runtime
// CUDA utilities and system includes
#include <cuda_runtime.h>
#include <cuda_gl_interop.h>

#include <helper_functions.h>
#include <helper_cuda.h>
#include <helper_cuda_gl.h>
#include <rendercheck_gl.h>

// Includes
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cstdio>

FILE *stream ;
char g_ExecPath[300] ;

//OpenGL PBO and texture "names"
GLuint gl_PBO, gl_Tex, gl_Shader;
struct cudaGraphicsResource *cuda_pbo_resource; // handles OpenGL-CUDA exchange

//Source image on the host side
uchar4 *h_Src = 0;

// Destination image on the GPU side
uchar4 *d_dst = NULL;

int imageW = 800, imageH = 600;

StopWatchInterface *hTimer = NULL;

bool haveDoubles = false;
int numSMs = 0;          // number of multiprocessors
int version = 1;             // Compute Capability

unsigned int g_TotalErrors = 0;

int *pArgc = NULL;
char **pArgv = NULL;

#define REFRESH_DELAY     10 //ms

#ifndef MAX
#define MAX(a,b) ((a > b) ? a : b)
#endif
#define BUFFER_DATA(i) ((char *)0 + i)

__global__ void ImagePass(uchar4 *dst, int imageW, int imageH)
{
    const int ix = threadIdx.x + blockIdx.x * blockDim.x;
    const int iy = threadIdx.y + blockIdx.y * blockDim.y;
    int pixel = imageW * iy + ix;

    uchar4 color;

    color.x = 1;
    color.y = 0;
    color.z = 0;

    dst[pixel] = color;

//    dst[pixel].x = ix / imageW;
//    dst[pixel].y = iy / imageH;
//    dst[pixel].z = 1;

//    // loop until all blocks completed
//    for (unsigned int blockIndex=blockIdx.x; blockIndex < numBlocks; blockIndex += gridDim.x)
//    {
//        unsigned int blockX = blockIndex % gridWidth;
//        unsigned int blockY = blockIndex / gridWidth;
//
//        // process this block
//        const int ix = blockDim.x * blockX + threadIdx.x;
//        const int iy = blockDim.y * blockY + threadIdx.y;
//
//        if ((ix < imageW) && (iy < imageH))
//        {
//            // Calculate the location
//            const T xPos = (T)ix * scale + xOff;
//            const T yPos = (T)iy * scale + yOff;
//
//            // Calculate the Mandelbrot index for the current location
//            int m = CalcMandelbrot<T>(xPos, yPos, xJP, yJP, crunch, isJ);
//            //            int m = blockIdx.x;         // uncomment to see scheduling order
//            m = m > 0 ? crunch - m : 0;
//
//            // Convert the Mandelbrot index into a color
//            uchar4 color;
//
//            if (m)
//            {
//                m += animationFrame;
//                color.x = m * colors.x;
//                color.y = m * colors.y;
//                color.z = m * colors.z;
//            }
//            else
//            {
//                color.x = 0;
//                color.y = 0;
//                color.z = 0;
//            }
//
//            // Output the pixel
//            int pixel = imageW * iy + ix;
//
//            if (frame == 0)
//            {
//                color.w = 0;
//                dst[pixel] = color;
//            }
//            else
//            {
//                int frame1 = frame + 1;
//                int frame2 = frame1 / 2;
//                dst[pixel].x = (dst[pixel].x * frame + color.x + frame2) / frame1;
//                dst[pixel].y = (dst[pixel].y * frame + color.y + frame2) / frame1;
//                dst[pixel].z = (dst[pixel].z * frame + color.z + frame2) / frame1;
//            }
//        }
//
//    }

} // Mandelbrot0

#define BLOCKDIM_X 16
#define BLOCKDIM_Y 16

// Increase the grid size by 1 if the image width or height does not divide evenly
// by the thread block dimensions
inline int iDivUp(int a, int b)
{
    return ((a % b) != 0) ? (a / b + 1) : (a / b);
} // iDivUp

void renderImage()
{
	checkCudaErrors(cudaGraphicsMapResources(1, &cuda_pbo_resource, 0));
    size_t num_bytes;
    checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void **)&d_dst, &num_bytes, cuda_pbo_resource));


    dim3 threads(BLOCKDIM_X, BLOCKDIM_Y);
    dim3 grid(iDivUp(imageW, BLOCKDIM_X), iDivUp(imageH, BLOCKDIM_Y));

    int numWorkerBlocks = numSMs;

//    dim3 threads(BLOCKDIM_X, BLOCKDIM_Y);
//    dim3 grid(iDivUp(imageW, BLOCKDIM_X), iDivUp(imageH, BLOCKDIM_Y));

//	printf("pass\n");

	ImagePass<<<numWorkerBlocks, threads>>>(d_dst, imageW, imageH);

	cudaDeviceSynchronize();

	checkCudaErrors(cudaGraphicsUnmapResources(1, &cuda_pbo_resource, 0));

//#if RUN_TIMING
//    pass = 0;
//#endif
//	float timeEstimate;
//	int startPass = pass;
//	sdkResetTimer(&hTimer);
//
//	if (bUseOpenGL)
//	{
//		// DEPRECATED: checkCudaErrors(cudaGLMapBufferObject((void**)&d_dst, gl_PBO));
//		checkCudaErrors(cudaGraphicsMapResources(1, &cuda_pbo_resource, 0));
//		size_t num_bytes;
//		checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void **)&d_dst, &num_bytes, cuda_pbo_resource));
//	}
//
//	// Render anti-aliasing passes until we run out time (60fps approximately)
//	do
//	{
//		float xs, ys;
//
//		// Get the anti-alias sub-pixel sample location
//		GetSample(pass & 127, xs, ys);
//
//		// Get the pixel scale and offset
//		double s = scale / (float)imageW;
//		double x = (xs - (double)imageW * 0.5f) * s + xOff;
//		double y = (ys - (double)imageH * 0.5f) * s + yOff;
//
//
//		// Run the mandelbrot generator
//		if (pass && !startPass) // Use the adaptive sampling version when animating.
//			RunMandelbrot1(d_dst, imageW, imageH, crunch, x, y,
//						   xJParam, yJParam, s, colors, pass++, animationFrame, precisionMode, numSMs, g_isJuliaSet, version);
//		else
//			RunMandelbrot0(d_dst, imageW, imageH, crunch, x, y,
//						   xJParam, yJParam, s, colors, pass++, animationFrame, precisionMode, numSMs, g_isJuliaSet, version);
//
//		cudaDeviceSynchronize();
//
//		// Estimate the total time of the frame if one more pass is rendered
//		timeEstimate = 0.001f * sdkGetTimerValue(&hTimer) * ((float)(pass + 1 - startPass) / (float)(pass - startPass));
//	}
//	while ((pass < 128) && (timeEstimate < 1.0f / 60.0f) && !RUN_TIMING);
//
//	if (bUseOpenGL)
//	{
//		// DEPRECATED: checkCudaErrors(cudaGLUnmapBufferObject(gl_PBO));
//		checkCudaErrors(cudaGraphicsUnmapResources(1, &cuda_pbo_resource, 0));
//	}

}

// OpenGL display function
void displayFunc(void)
{
    sdkStartTimer(&hTimer);
//    printf("displayFunc\n");
    renderImage();

    glBindTexture(GL_TEXTURE_2D, gl_Tex);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, imageW, imageH, GL_RGBA, GL_UNSIGNED_BYTE, BUFFER_DATA(0));

    glBindProgramARB(GL_FRAGMENT_PROGRAM_ARB, gl_Shader);
    glEnable(GL_FRAGMENT_PROGRAM_ARB);
    glDisable(GL_DEPTH_TEST);

    glBegin(GL_QUADS);
    glTexCoord2f(0.0f, 0.0f);
    glVertex2f(0.0f, 0.0f);
    glTexCoord2f(1.0f, 0.0f);
    glVertex2f(1.0f, 0.0f);
    glTexCoord2f(1.0f, 1.0f);
    glVertex2f(1.0f, 1.0f);
    glTexCoord2f(0.0f, 1.0f);
    glVertex2f(0.0f, 1.0f);
    glEnd();

    glBindTexture(GL_TEXTURE_2D, 0);
    glDisable(GL_FRAGMENT_PROGRAM_ARB);

    sdkStopTimer(&hTimer);
    glutSwapBuffers();
}

void cleanup()
{
    if (h_Src)
    {
        free(h_Src);
        h_Src = 0;
    }

    sdkStopTimer(&hTimer);
    sdkDeleteTimer(&hTimer);

    //DEPRECATED: checkCudaErrors(cudaGLUnregisterBufferObject(gl_PBO));
    cudaGraphicsUnregisterResource(cuda_pbo_resource);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, 0);

    glDeleteBuffers(1, &gl_PBO);
    glDeleteTextures(1, &gl_Tex);
    glDeleteProgramsARB(1, &gl_Shader);
}

void initMenus() ;

void keyboardFunc(unsigned char k, int, int)
{
    switch (k)
    {
        case '\033':
        case 'q':
        case 'Q':
            printf("Shutting down...\n");

            cudaDeviceReset();
            exit(EXIT_SUCCESS);
            break;

        default:
            break;
    }

}

void clickFunc(int button, int state, int x, int y)
{

}

void motionFunc(int x, int y)
{
}

void timerEvent(int value)
{
    glutPostRedisplay();
    glutTimerFunc(REFRESH_DELAY, timerEvent, 0);
}

void mainMenu(int i)
{

}

void initMenus()
{
}

// gl_Shader for displaying floating-point texture
static const char *shader_code =
    "!!ARBfp1.0\n"
    "TEX result.color, fragment.texcoord, texture[0], 2D; \n"
    "END";

GLuint compileASMShader(GLenum program_type, const char *code)
{
    GLuint program_id;
    glGenProgramsARB(1, &program_id);
    glBindProgramARB(program_type, program_id);
    glProgramStringARB(program_type, GL_PROGRAM_FORMAT_ASCII_ARB, (GLsizei) strlen(code), (GLubyte *) code);

    GLint error_pos;
    glGetIntegerv(GL_PROGRAM_ERROR_POSITION_ARB, &error_pos);

    if (error_pos != -1)
    {
        const GLubyte *error_string;
        error_string = glGetString(GL_PROGRAM_ERROR_STRING_ARB);
        fprintf(stderr, "Program error at position: %d\n%s\n", (int)error_pos, error_string);
        return 0;
    }

    return program_id;
}

void initOpenGLBuffers(int w, int h)
{
    // delete old buffers
    if (h_Src)
    {
        free(h_Src);
        h_Src = 0;
    }

    if (gl_Tex)
    {
        glDeleteTextures(1, &gl_Tex);
        gl_Tex = 0;
    }

    if (gl_PBO)
    {
        //DEPRECATED: checkCudaErrors(cudaGLUnregisterBufferObject(gl_PBO));
        cudaGraphicsUnregisterResource(cuda_pbo_resource);
        glDeleteBuffers(1, &gl_PBO);
        gl_PBO = 0;
    }

    // check for minimized window
    if ((w==0) && (h==0))
    {
        return;
    }

    // allocate new buffers
    h_Src = (uchar4 *)malloc(w * h * 4);

    printf("Creating GL texture...\n");
    glEnable(GL_TEXTURE_2D);
    glGenTextures(1, &gl_Tex);
    glBindTexture(GL_TEXTURE_2D, gl_Tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, h_Src);
    printf("Texture created.\n");

    printf("Creating PBO...\n");
    glGenBuffers(1, &gl_PBO);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER_ARB, gl_PBO);
    glBufferData(GL_PIXEL_UNPACK_BUFFER_ARB, w * h * 4, h_Src, GL_STREAM_COPY);
    //While a PBO is registered to CUDA, it can't be used
    //as the destination for OpenGL drawing calls.
    //But in our particular case OpenGL is only used
    //to display the content of the PBO, specified by CUDA kernels,
    //so we need to register/unregister it only once.

    // DEPRECATED: checkCudaErrors( cudaGLRegisterBufferObject(gl_PBO) );
    checkCudaErrors(cudaGraphicsGLRegisterBuffer(&cuda_pbo_resource, gl_PBO,
                                                 cudaGraphicsMapFlagsWriteDiscard));
    printf("PBO created.\n");

    // load shader program
    gl_Shader = compileASMShader(GL_FRAGMENT_PROGRAM_ARB, shader_code);
}

void reshapeFunc(int w, int h)
{
    glViewport(0, 0, w, h);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0.0, 1.0, 0.0, 1.0, 0.0, 1.0);

    initOpenGLBuffers(w, h);
    imageW = w;
    imageH = h;
}

void initGL(int *argc, char **argv)
{
    printf("Initializing GLUT...\n");
    glutInit(argc, argv);

    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE);
    glutInitWindowSize(imageW, imageH);
    glutInitWindowPosition(0, 0);
    glutCreateWindow(argv[0]);

    glutDisplayFunc(displayFunc);
    glutKeyboardFunc(keyboardFunc);
    glutMouseFunc(clickFunc);
    glutMotionFunc(motionFunc);
    glutReshapeFunc(reshapeFunc);
    glutTimerFunc(REFRESH_DELAY, timerEvent, 0);
    initMenus();

    printf("Loading extensions: %s\n", glewGetErrorString(glewInit()));

    if (!glewIsSupported("GL_VERSION_1_5 GL_ARB_vertex_buffer_object GL_ARB_pixel_buffer_object"))
    {
        exit(EXIT_SUCCESS);
    }

    printf("OpenGL window created.\n");
}

void initData(int argc, char **argv)
{
    // check for hardware double precision support
    int dev = 0;
    dev = findCudaDevice(argc, (const char **)argv);

    cudaDeviceProp deviceProp;
    checkCudaErrors(cudaGetDeviceProperties(&deviceProp, dev));
    version = deviceProp.major*10 + deviceProp.minor;

    if (version < 11)
    {
        printf("GPU compute capability is too low (1.0), program is waived\n");
        exit(EXIT_WAIVED);
    }

    haveDoubles = (version >= 13);
    numSMs = deviceProp.multiProcessorCount;

    printf("Data initialization done.\n");
}


void chooseCudaDevice(int argc, const char **argv, bool bUseOpenGL)
{
    if (bUseOpenGL)
    {
        findCudaGLDevice(argc, argv);
    }
    else
    {
        findCudaDevice(argc, argv);
    }
}

int main(int argc, char **argv)
{
    pArgc = &argc;
    pArgv = argv;

    if (checkCmdLineFlag(argc, (const char **)argv, "help"))
    {
        exit(EXIT_SUCCESS);
    }

    int mode = 0;

    if (checkCmdLineFlag(argc, (const char **)argv, "file"))
    {
        // use command-line specified CUDA device, otherwise use device with highest Gflops/s
        findCudaDevice(argc, (const char **)argv); // no OpenGL usage

        // If the GPU does not meet SM1.1 capabilities, we will quit
        if (!checkCudaCapabilities(1,1))
        {
            exit(EXIT_SUCCESS);
        }

        cudaDeviceReset();
        exit(g_TotalErrors == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
    }
    else if (checkCmdLineFlag(argc, (const char **)argv, "benchmark"))
    {
        //run benchmark
        // use command-line specified CUDA device, otherwise use device with highest Gflops/s
        chooseCudaDevice(argc, (const char **)argv, false); // no OpenGL usage

        // If the GPU does not meet a minimum of SM1.1 capabilities, we will quit
        if (!checkCudaCapabilities(1,1))
        {
            exit(EXIT_SUCCESS);
        }

        cudaDeviceReset();
        exit(g_TotalErrors == 0 ? EXIT_SUCCESS : EXIT_FAILURE);
    }
    // use command-line specified CUDA device, otherwise use device with highest Gflops/s
    else if (checkCmdLineFlag(argc, (const char **)argv, "device"))
    {
        printf("[%s]\n", argv[0]);
        printf("   Does not explicitly support -device=n in OpenGL mode\n");
        printf("   To use -device=n, the sample must be running w/o OpenGL\n\n");
        printf(" > %s -device=n -file=<image_name>.ppm\n", argv[0]);
        printf("exiting...\n");
        exit(EXIT_SUCCESS);
    }

    // use command-line specified CUDA device, otherwise use device with highest Gflops/s
    chooseCudaDevice(argc, (const char **)argv, true); // yes to OpenGL usage

    // If the GPU does not meet SM1.1 capabilities, we quit
    if (!checkCudaCapabilities(1,1))
    {
        cudaDeviceReset();
        exit(EXIT_SUCCESS);
    }

    // Otherwise it succeeds, we will continue to run this sample
    initData(argc, argv);

    // Initialize OpenGL context first before the CUDA context is created.  This is needed
    // to achieve optimal performance with OpenGL/CUDA interop.
    initGL(&argc, argv);
    initOpenGLBuffers(imageW, imageH);

    sdkCreateTimer(&hTimer);
    sdkStartTimer(&hTimer);

#if defined (__APPLE__) || defined(MACOSX)
        atexit(cleanup);
#else
        glutCloseFunc(cleanup);
#endif

#if defined(WIN32) || defined(_WIN32) || defined(WIN64) || defined(_WIN64)
    setVSync(0) ;
#endif

    glutMainLoop();

    cudaDeviceReset();
}
