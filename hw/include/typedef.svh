/*
 * Copyright (C) 2023-2024 ETH Zurich and University of Bologna
 *
 * Licensed under the Solderpad Hardware License, Version 0.51 
 * (the "License"); you may not use this file except in compliance 
 * with the License. You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: SHL-0.51
 *
 * Authors: Victor Isachi <victor.isachi@unibo.it>
 *
 * Macros for the definition of FractalSync interface channels
 */

`ifndef FSYNC_TYPEDEF_SVH_
`define FSYNC_TYPEDEF_SVH_

`define FSYNC_TYPEDEF_MST_SIG_T(fsync_mst_sig_t, level_t, id_t) \
  typedef struct packed {                                       \
    level_t level;                                              \
    id_t    id;                                                 \
  } fsync_mst_sig_t;

`define FSYNC_TYPEDEF_SLV_SIG_T(fsync_slv_sig_t, level_t, id_t) \
  typedef struct packed {                                       \
    level_t level;                                              \
    id_t    id;                                                 \
  } fsync_slv_sig_t;

`define FYSNC_TYPEDEF_REQ_T(fsync_req_t, fsync_mst_sig_t) \
  typedef struct packed {                                 \
    logic           sync;                                 \
    fsync_mst_sig_t mst_sig;                              \
  } fsync_req_t;

`define FSYNC_TYPEDEF_RSP_T(fsync_rsp_t, fsync_slv_sig_t) \
  typedef struct packed {                                 \
    logic           wake;                                 \
    fsync_slv_sig_t slv_sig;                              \
    logic           error;                                \
  } fsycn_rsp_t;

`define FSYNC_TYPEDEF_ALL(__name, __mst_level_t, __mst_id_t, __slv_level_t, __slv_id_t) \
  `FSYNC_TYPEDEF_MST_SIG_T(__name``mst_sig_t, __mst_level_t, __mst_id_t)                \
  `FSYNC_TYPEDEF_SLV_SIG_T(__name``slv_sig_t, __slv_level_t, __slv_id_t)                \
  `FYSNC_TYPEDEF_REQ_T(__name``req_t, __name``mst_sig_t)                                \
  `FSYNC_TYPEDEF_RSP_T(__name``rsp_t, __name``slv_sig_t)

`endif /* FSYNC_TYPEDEF_SVH_ */