#ifndef MSHADOW_TENSOR_GPU_INL_CUH
#define MSHADOW_TENSOR_GPU_INL_CUH
/*!
 * \file tensor_gpu-inl.cuh
 * \brief implementation of GPU code using CUDA
 * \author Bing Hsu, Tianqi Chen
 */
#include "../tensor.h"

namespace mshadow{
    namespace cuda{
        /* load unit for memory access */
        #if __CUDA_ARCH__>=200
        const int kMemUnitBits = 5;
        const int kMaxThreadsPerBlock = 1024;
        #else
        const int kMemUnitBits = 4;
        const int kMaxThreadsPerBlock = 512;
        #endif        
        /*! \brief number of units that can do synchronized update, half warp size */
        const int kMemUnit     = 1 << kMemUnitBits;
        /*! \brief mask that could be helpful sometime */
        const int kMemUnitMask = kMemUnit - 1;         
        /*! \brief suggested thread number(logscale) for mapping kernel */
        const int kBaseThreadBits = 8;
        /*! \brief suggested thread number for mapping kernel */
        const int kBaseThreadNum  = 1 << kBaseThreadBits;
        /*! \brief maximum value of grid */
        const int kMaxGridNum     = 65535;
    };

    namespace cuda {                
        template<typename Saver, typename Plan, int block_dim_bits>
        __global__ void MapPlanKernel(GTensor2D dst, const Plan exp){
            const index_t tid = (blockIdx.x << block_dim_bits) + threadIdx.x;
            const index_t xstride = dst.shape.stride_;
            const int y   = tid / xstride;
            const int x   = tid % xstride;
            if (y < dst.shape[1] && x < dst.shape[0]) {
                Saver::Save(dst[y][x], exp.eval(y,x));
            }
        }
        template<typename Saver, typename E>
        inline void MapPlan(GTensor2D dst, const expr::Plan<E> &plan ){
            const int num_block = (dst.shape.MSize() + kBaseThreadNum-1) / kBaseThreadNum;
            dim3 dimBlock(kBaseThreadNum, 1, 1);
            
            if (num_block < kMaxGridNum) {
                dim3 dimGrid(num_block, 1, 1);
                MapPlanKernel<Saver, expr::Plan<E>, kBaseThreadBits>   \
                    <<<dimGrid,dimBlock>>>(dst, plan);
            } else {
                utils::Error("not implemented");                
            }
        }
    }; // namespace cuda
}; // namespace mshadow
#endif // TENSOR_GPU_INL_H
