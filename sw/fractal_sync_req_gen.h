/*
 * Copyright (C) 2023-2024 ETH Zurich and University of Bologna
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Authors: Victor Isachi <victor.isachi@unibo.it>
 * 
 * Fractal synchronization request (id, aggregate) generator header
 */

#ifndef FSYNC_REQ_GEN_H
#define FSYNC_REQ_GEN_H

#include <stdlib.h>
#include <stdbool.h>

#define __FSYNC_N_CU_X__     (4)
#define __FSYNC_N_CU_Y__     (4)
#define __FSYNC_N_CU__       (__FSYNC_N_CU_X__*__FSYNC_N_CU_Y__)
#define __FSYNC_N_LVL__      (4)
#define __FSYNC_DEFAULT_TH__ (__FSYNC_N_CU_X__/2)

#define abs_diff(x, y) (((x) > (y)) ? ((x) - (y)) : ((y) - (x)))

typedef enum {h_fs_dir, v_fs_dir} fsync_dir;
typedef enum {null_fs_node, h_fs_node, v_fs_node, hv_fs_node} fsync_node;

typedef struct fsync_req{
  unsigned int fs_req_aggr;
  unsigned int fs_req_id;
  fsync_node   req_node;
} fsync_req_t;

typedef struct fsync_cu{
  unsigned int cu_id;
  unsigned int y_pos;
  unsigned int x_pos;
  fsync_req_t  fsync_req;
} fsync_cu_t;

/**
 * @brief initialize array of CUs with default FractalSync request values
 * @param cus array of CUs
 * @param num_cus size of the array of CUs
 * @return no return value
 */
void fsync_init_reqs(fsync_cu_t *cus, const unsigned int num_cus);

/**
 * @brief set the FractalSync request fields (id, aggregate) of the CUs so that they all synchronize at the same barrier
 * @param cus array of CUs
 * @param num_cus size of the array of CUs
 * @param default_dir default barrier direction when the barrier can be reached both horizontaly and vertically (i.e. synchronization at 2D node)
 * @return true if synchronization requests have been generated properly, false otherwise (e.g. degenerate array of CUs)
 */
bool fsync_gen_reqs(fsync_cu_t *cus, const unsigned int num_cus, const fsync_dir default_dir);

#endif /*FSYNC_REQ_GEN_H*/