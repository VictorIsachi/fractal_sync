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
 * Fractal synchronization request (id, aggregate) generator
 */

#include "fractal_sync_req_gen.h"

static inline bool fsync_nbr_node(const unsigned int pos1, const unsigned int pos2){
  return (pos1 < pos2) ? pos1 & 1 : pos2 & 1;
} 

static inline bool fsync_same_subtree(const unsigned int pos1, const unsigned int pos2, const unsigned int threshold){
  if ((pos1 < threshold && pos2 < threshold) || (pos1 >= threshold && pos2 >= threshold)) return true;
  return false;
}

static inline unsigned int fsync_update_pos(unsigned int *pos, const unsigned int threshold){
  *pos = (*pos < threshold) ? *pos : *pos - threshold;
  return threshold/2;
}

bool fsync_partition_h_cus(fsync_cu_t **cus, const unsigned int num_cus, const unsigned int threshold, fsync_cu_t **l_cus, unsigned int *num_l_cus, fsync_cu_t **h_cus, unsigned int *num_h_cus){
  for (unsigned int i = 0; i < num_cus; i++){
    if (cus[i]->x_pos < threshold) l_cus[(*num_l_cus)++] = cus[i];
    else                           h_cus[(*num_h_cus)++] = cus[i];                          
  }
  return (*num_l_cus > 0) && (*num_h_cus > 0);
}

bool fsync_partition_v_cus(fsync_cu_t **cus, const unsigned int num_cus, const unsigned int threshold, fsync_cu_t **l_cus, unsigned int *num_l_cus, fsync_cu_t **h_cus, unsigned int *num_h_cus){
  for (unsigned int i = 0; i < num_cus; i++){
    if (cus[i]->y_pos < threshold) l_cus[(*num_l_cus)++] = cus[i];
    else                           h_cus[(*num_h_cus)++] = cus[i];
  }
  return (*num_l_cus > 0) && (*num_h_cus > 0);
}

unsigned int fsync_update_h_poss(fsync_cu_t **cus, const unsigned int num_cus, const unsigned int threshold){
  for (unsigned int i = 0; i < num_cus; i++)
    fsync_update_pos(&(cus[i]->x_pos), threshold);
  return threshold/2;
}

unsigned int fsync_update_v_poss(fsync_cu_t **cus, const unsigned int num_cus, const unsigned int threshold){
  for (unsigned int i = 0; i < num_cus; i++)
    fsync_update_pos(&(cus[i]->y_pos), threshold);
  return threshold/2;
}

void fsync_update_cus_req(fsync_cu_t **cus, const unsigned int num_cus, const fsync_dir dir, const fsync_node node, const bool node_active){
  for (unsigned int i = 0; i < num_cus; i++){
    cus[i]->fsync_req.fs_req_aggr <<= 1;
    cus[i]->fsync_req.fs_req_aggr |= node_active ? 1 : 0;
    if ((cus[i]->fsync_req.req_node == null_fs_node) && node_active){
      cus[i]->fsync_req.req_node = node;
      cus[i]->fsync_req.fs_req_id = (dir == h_fs_dir) ? 0 : 1;
    }
  }
}

bool fsync_partition_subtree(fsync_cu_t **cus, const unsigned int num_cus, const fsync_dir dir, const unsigned int threshold, const fsync_node node){
  if (threshold < 1) return false;

  if (node == hv_fs_node){
    fsync_cu_t **h_l_cus = malloc(num_cus*sizeof(fsync_cu_t*));
    fsync_cu_t **h_h_cus = malloc(num_cus*sizeof(fsync_cu_t*));
    fsync_cu_t **v_l_cus = malloc(num_cus*sizeof(fsync_cu_t*));
    fsync_cu_t **v_h_cus = malloc(num_cus*sizeof(fsync_cu_t*));
    if (h_l_cus == NULL || h_h_cus == NULL || v_l_cus == NULL || v_h_cus == NULL) return false;
    unsigned int num_h_l_cus = 0;
    unsigned int num_h_h_cus = 0;
    unsigned int num_v_l_cus = 0;
    unsigned int num_v_h_cus = 0;

    bool h_node_active = fsync_partition_h_cus(cus, num_cus, threshold, h_l_cus, &num_h_l_cus, h_h_cus, &num_h_h_cus);
    bool v_node_active = fsync_partition_v_cus(cus, num_cus, threshold, v_l_cus, &num_v_l_cus, v_h_cus, &num_v_h_cus);
    bool node_active = h_node_active && v_node_active;

    bool l_subtree_active;
    bool h_subtree_active;
    if (node_active || (!h_node_active && !v_node_active)){
      if (dir == h_fs_dir){
        fsync_update_cus_req(v_l_cus, num_v_l_cus, dir, node, node_active);
        fsync_update_cus_req(v_h_cus, num_v_h_cus, dir, node, node_active);
        fsync_update_v_poss(v_h_cus, num_v_h_cus, threshold);
        l_subtree_active = fsync_partition_subtree(v_l_cus, num_v_l_cus, h_fs_dir, threshold, h_fs_node);
        h_subtree_active = fsync_partition_subtree(v_h_cus, num_v_h_cus, h_fs_dir, threshold, h_fs_node);
      }else{
        fsync_update_cus_req(h_l_cus, num_h_l_cus, dir, node, node_active);
        fsync_update_cus_req(h_h_cus, num_h_h_cus, dir, node, node_active);
        fsync_update_h_poss(h_h_cus, num_h_h_cus, threshold);
        l_subtree_active = fsync_partition_subtree(h_l_cus, num_h_l_cus, v_fs_dir, threshold, v_fs_node);
        h_subtree_active = fsync_partition_subtree(h_h_cus, num_h_h_cus, v_fs_dir, threshold, v_fs_node);
      }
    }else if(h_node_active){
      fsync_update_cus_req(v_l_cus, num_v_l_cus, dir, node, node_active);
      fsync_update_cus_req(v_h_cus, num_v_h_cus, dir, node, node_active);
      fsync_update_v_poss(v_h_cus, num_v_h_cus, threshold);
      l_subtree_active = fsync_partition_subtree(v_l_cus, num_v_l_cus, h_fs_dir, threshold, h_fs_node);
      h_subtree_active = fsync_partition_subtree(v_h_cus, num_v_h_cus, h_fs_dir, threshold, h_fs_node);
    }else{
      fsync_update_cus_req(h_l_cus, num_h_l_cus, dir, node, node_active);
      fsync_update_cus_req(h_h_cus, num_h_h_cus, dir, node, node_active);
      fsync_update_h_poss(h_h_cus, num_h_h_cus, threshold);
      l_subtree_active = fsync_partition_subtree(h_l_cus, num_h_l_cus, v_fs_dir, threshold, v_fs_node);
      h_subtree_active = fsync_partition_subtree(h_h_cus, num_h_h_cus, v_fs_dir, threshold, v_fs_node);
    }
    
    free(h_l_cus);
    free(h_h_cus);
    free(v_l_cus);
    free(v_h_cus);

    return node_active || l_subtree_active || h_subtree_active;
  }else{
    fsync_cu_t **l_cus = malloc(num_cus*sizeof(fsync_cu_t*));
    fsync_cu_t **h_cus = malloc(num_cus*sizeof(fsync_cu_t*));
    if (l_cus == NULL || h_cus == NULL) return false;
    unsigned int num_l_cus = 0;
    unsigned int num_h_cus = 0;

    bool node_active = (dir == h_fs_dir) ? fsync_partition_h_cus(cus, num_cus, threshold, l_cus, &num_l_cus, h_cus, &num_h_cus) :
                                           fsync_partition_v_cus(cus, num_cus, threshold, l_cus, &num_l_cus, h_cus, &num_h_cus);
    fsync_update_cus_req(l_cus, num_l_cus, dir, node, node_active);
    fsync_update_cus_req(h_cus, num_h_cus, dir, node, node_active);
    unsigned int subtree_threshold = (dir == h_fs_dir) ? fsync_update_h_poss(h_cus, num_h_cus, threshold) :
                                                         fsync_update_v_poss(h_cus, num_h_cus, threshold);

    bool l_subtree_active = fsync_partition_subtree(l_cus, num_l_cus, dir, subtree_threshold, hv_fs_node);
    bool h_subtree_active = fsync_partition_subtree(h_cus, num_h_cus, dir, subtree_threshold, hv_fs_node);

    free (l_cus);
    free (h_cus);

    return node_active || l_subtree_active || h_subtree_active;
  }
}

void fsync_init_reqs(fsync_cu_t *cus, const unsigned int num_cus){
  for (unsigned int i = 0; i < num_cus; i++){
    cus[i].fsync_req.fs_req_aggr = 0;
    cus[i].fsync_req.fs_req_id   = 0;
    cus[i].fsync_req.req_node    = null_fs_node;
  }
}

bool fsync_gen_reqs(fsync_cu_t *cus, const unsigned int num_cus, const fsync_dir default_dir){
  fsync_init_reqs(cus, num_cus);
  
  if (num_cus < 2) return false;

  if (num_cus == 2){
    unsigned int x_dist = abs_diff(cus[0].x_pos, cus[1].x_pos);
    unsigned int y_dist = abs_diff(cus[0].y_pos, cus[1].y_pos);
    unsigned int dist   = x_dist + y_dist;
    fsync_dir    dir;

    if (dist == 0) return false;

    if (x_dist > y_dist){
      dir = h_fs_dir;
      cus[0].fsync_req.req_node = h_fs_node; cus[1].fsync_req.req_node = h_fs_node;
    }else if(x_dist == y_dist){
      dir = default_dir;
      cus[0].fsync_req.req_node = hv_fs_node; cus[1].fsync_req.req_node = hv_fs_node; 
    }else{
      dir = v_fs_dir;
      cus[0].fsync_req.req_node = v_fs_node; cus[1].fsync_req.req_node = v_fs_node; 
    }

    if (dist == 1){
      cus[0].fsync_req.fs_req_aggr = 0b1; cus[1].fsync_req.fs_req_aggr = 0b1;
      if (dir == h_fs_dir){
        if (fsync_nbr_node(cus[0].x_pos, cus[1].x_pos)){
          cus[0].fsync_req.fs_req_id = 2; cus[1].fsync_req.fs_req_id = 2;  
        }else{
          cus[0].fsync_req.fs_req_id = 0; cus[1].fsync_req.fs_req_id = 0;
        }
      }else{
        if (fsync_nbr_node(cus[0].y_pos, cus[1].y_pos)){
          cus[0].fsync_req.fs_req_id = 3; cus[1].fsync_req.fs_req_id = 3;
        }else{
          cus[0].fsync_req.fs_req_id = 1; cus[1].fsync_req.fs_req_id = 1;
        }
      }
    }else{
      unsigned int hops = __FSYNC_N_LVL__;
      unsigned int x_th = __FSYNC_N_CU_X__/2;
      unsigned int y_th = __FSYNC_N_CU_Y__/2;
      unsigned int x_p0 = cus[0].x_pos;
      unsigned int x_p1 = cus[1].x_pos;
      unsigned int y_p0 = cus[0].y_pos;
      unsigned int y_p1 = cus[1].y_pos;
      bool done = false;
      while (!done){
        if (fsync_same_subtree(x_p0, x_p1, x_th) && x_th > 0){
          fsync_update_pos(&x_p0, x_th);
          x_th = fsync_update_pos(&x_p1, x_th);
          --hops;
        } else done = true;
        if (fsync_same_subtree(y_p0, y_p1, y_th) && y_th >0){
          fsync_update_pos(&y_p0, y_th);
          y_th = fsync_update_pos(&y_p1, y_th);
          --hops;
        } else done = true;
      }

      if (hops > 1){
        unsigned int aggregate = 0b1 << (hops-1);
        cus[0].fsync_req.fs_req_aggr = aggregate; cus[1].fsync_req.fs_req_aggr = aggregate;
        if (dir == h_fs_dir){
          cus[0].fsync_req.fs_req_id = 0;         cus[1].fsync_req.fs_req_id = 0;
          cus[0].fsync_req.req_node  = h_fs_node; cus[1].fsync_req.req_node  = h_fs_node;
        }else{
          cus[0].fsync_req.fs_req_id = 1;         cus[1].fsync_req.fs_req_id = 1;
          cus[0].fsync_req.req_node  = v_fs_node; cus[1].fsync_req.req_node  = v_fs_node;
        }
      }else return false;
    }
    return true;
  }

  fsync_cu_t *temp_cus = malloc(num_cus*sizeof(fsync_cu_t));
  if (temp_cus == NULL) return false;
  for (unsigned int i = 0; i < num_cus; i++) temp_cus[i] = cus[i];

  fsync_cu_t **cus_ptr = malloc(num_cus*sizeof(fsync_cu_t*));
  if (cus_ptr == NULL) return false;
  for (unsigned int i = 0; i < num_cus; i++) cus_ptr[i] = &temp_cus[i];

  bool generated_reqs = fsync_partition_subtree(cus_ptr, num_cus, default_dir, __FSYNC_DEFAULT_TH__, hv_fs_node);

  for (unsigned int i = 0; i < num_cus; i++){
    cus[i].fsync_req.fs_req_aggr = temp_cus[i].fsync_req.fs_req_aggr;
    cus[i].fsync_req.fs_req_id   = temp_cus[i].fsync_req.fs_req_id;
    cus[i].fsync_req.req_node    = temp_cus[i].fsync_req.req_node;
  }

  free(cus_ptr);
  free(temp_cus);

  return generated_reqs;
}
