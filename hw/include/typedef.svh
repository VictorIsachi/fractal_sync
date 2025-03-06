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

`define FSYNC_TYPEDEF_SIG_T(fsync_sig_t, level_t, id_t) \
  typedef struct packed {                               \
    level_t aggr;                                       \
    id_t    id;                                         \
  } fsync_sig_t;

`define FYSNC_TYPEDEF_REQ_T(fsync_req_t, fsync_sig_t, fsync_src_t) \
  typedef struct packed {                                          \
    logic       sync;                                              \
    fsync_sig_t sig;                                               \
    fsync_src_t src;                                               \
  } fsync_req_t;

`define FSYNC_TYPEDEF_RSP_T(fsync_rsp_t, fsync_dst_t) \
  typedef struct packed {                             \
    logic       wake;                                 \
    fsync_dst_t dst;                                  \
    logic       error;                                \
  } fsycn_rsp_t;

`define FSYNC_TYPEDEF_ALL(__name, __level_t, __id_t, __src_t, __dst_t) \
  `FSYNC_TYPEDEF_SIG_T(__name``sig_t, __level_t, __id_t)               \
  `FYSNC_TYPEDEF_REQ_T(__name``req_t, __name``sig_t, __src_t)          \
  `FSYNC_TYPEDEF_RSP_T(__name``rsp_t, __dst_t)

`endif /* FSYNC_TYPEDEF_SVH_ */