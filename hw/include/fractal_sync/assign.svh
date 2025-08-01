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
 * Macros for the assignment of FractalSync struct/interface channels
 */

`ifndef FSYNC_ASSIGN_SVH_
`define FSYNC_ASSIGN_SVH_

`define FSYNC_ASSIGN_I2S_REQ_SIG(fractal_sync_if, req_sig_s) \
  assign req_sig_s.aggr = fractal_sync_if.aggr_req;          \
  assign req_sig_s.id   = fractal_sync_if.id_req;

`define FSYNC_ASSIGN_I2S_REQ(fractal_sync_if, req_s)    \
  assign req_s.sync = fractal_sync_if.sync;             \
  assign req_s.lock = fractal_sync_if.lock;             \
  assign req_s.free = fractal_sync_if.free;             \
  `FSYNC_ASSIGN_I2S_REQ_SIG(fractal_sync_if, req_s.sig)

`define FSYNC_ASSIGN_I2S_RSP_SIG(fractal_sync_if, rsp_sig_s) \
  assign rsp_sig_s.aggr = fractal_sync_if.aggr_rsp;          \
  assign rsp_sig_s.id   = fractal_sync_if.id_rsp;

`define FSYNC_ASSIGN_I2S_RSP(fractal_sync_if, rsp_s)    \
  assign rsp_s.wake  = fractal_sync_if.wake;            \
  assign rsp_s.grant = fractal_sync_if.grant;           \
  `FSYNC_ASSIGN_I2S_RSP_SIG(fractal_sync_if, rsp_s.sig) \
  assign rsp_s.error = fractal_sync_if.error;

`define FSYNC_ASSIGN_S2I_REQ_SIG(req_sig_s, fractal_sync_if) \
  assign fractal_sync_if.aggr_req = req_sig_s.aggr;          \
  assign fractal_sync_if.id_req   = req_sig_s.id;

`define FSYNC_ASSIGN_S2I_REQ(req_s, fractal_sync_if)    \
  assign fractal_sync_if.sync = req_s.sync;             \
  assign fractal_sync_if.lock = req_s.lock;             \
  assign fractal_sync_if.free = req_s.free;             \
  `FSYNC_ASSIGN_S2I_REQ_SIG(req_s.sig, fractal_sync_if)

`define FSYNC_ASSIGN_S2I_RSP_SIG(rsp_sig_s, fractal_sync_if) \
  assign fractal_sync_if.aggr_rsp = rsp_sig_s.aggr;          \
  assign fractal_sync_if.id_rsp   = rsp_sig_s.id;

`define FSYNC_ASSIGN_S2I_RSP(rsp_s, fractal_sync_if)    \
  assign fractal_sync_if.wake  = rsp_s.wake;            \
  assign fractal_sync_if.grant = rsp_s.grant;           \
  `FSYNC_ASSIGN_S2I_RSP_SIG(rsp_s.sig, fractal_sync_if) \
  assign fractal_sync_if.error = rsp_s.error;

`endif /* FSYNC_ASSIGN_SVH_ */