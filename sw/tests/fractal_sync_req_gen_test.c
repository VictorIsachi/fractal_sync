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
 * Fractal synchronization request (id, aggregate) generator test
 */

#define N_CUS (8)

#include <stdio.h>
#include "../fractal_sync_req_gen.c"

int main(void){
  
  // Define an array of CUs indicating ID and position (y, x)
  fsync_cu_t cus[N_CUS] = {
    {.cu_id = 0,  .y_pos = 0, .x_pos = 0},
    {.cu_id = 5,  .y_pos = 1, .x_pos = 1},
    {.cu_id = 2,  .y_pos = 0, .x_pos = 2},
    {.cu_id = 3,  .y_pos = 0, .x_pos = 3},
    {.cu_id = 8,  .y_pos = 2, .x_pos = 0},
    {.cu_id = 10, .y_pos = 2, .x_pos = 2},
    {.cu_id = 11, .y_pos = 2, .x_pos = 3},
    {.cu_id = 15, .y_pos = 3, .x_pos = 3}
  };

  // Initialize FractalSync synchronization requests to default values
  // NOTE: This step is optional for the programmer as it will be automatically done by the generator
  fsync_init_reqs(cus, N_CUS);

  // Generate the appropriate FractalSync synchronization request fields (id, aggregate)
  bool generated_reqs = fsync_gen_reqs(cus, N_CUS, h_fs_dir);

  // If generation was successful print the generated fields
  if (generated_reqs){
    printf("FractalSync requests generated.\n");
    for (int unsigned i = 0; i < N_CUS; i++){
      printf("fsync_req[%0d]:\n  cu_id: %0d\n  aggregate: 0x%0x\n  id: %0d\n  node: %s\n", 
      i, cus[i].cu_id, cus[i].fsync_req.fs_req_aggr, cus[i].fsync_req.fs_req_id, 
      cus[i].fsync_req.req_node == hv_fs_node ? "2D" : cus[i].fsync_req.req_node == h_fs_node ? "Horizontal" : "Vertical");
    }
  }
  else printf("FractalSync requests not generated.\n");

  return 0;
}