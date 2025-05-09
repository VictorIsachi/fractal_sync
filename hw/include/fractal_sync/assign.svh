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

`define FSYNC_ASSIGN_I2S_SIG(fractal_sync_if, sig_s) \
  assign sig_s.aggr = fractal_sync_if.aggr;          \
  assign sig_s.id   = fractal_sync_if.id;

`define FSYNC_ASSIGN_I2S_REQ(fractal_sync_if, req_s) \
  assign req_s.sync = fractal_sync_if.sync;          \
  `FSYNC_ASSIGN_I2S_SIG(fractal_sync_if, req_s.sig)  \
  assign req_s.src  = fractal_sync_if.src;

`define FSYNC_ASSIGN_I2S_RSP(fractal_sync_if, rsp_s) \
  assign rsp_s.wake  = fractal_sync_if.wake;         \
  assign rsp_s.dst   = fractal_sync_if.dst;          \
  assign rsp_s.error = fractal_sync_if.error;

`define FSYNC_ASSIGN_S2I_SIG(sig_s, fractal_sync_if) \
  assign fractal_sync_if.aggr = sig_s.aggr;          \
  assign fractal_sync_if.id   = sig_s.id;

`define FSYNC_ASSIGN_S2I_REQ(req_s, fractal_sync_if) \
  assign fractal_sync_if.sync = req_s.sync;          \
  `FSYNC_ASSIGN_S2I_SIG(req_s.sig, fractal_sync_if)  \
  assign fractal_sync_if.src  = req_s.src;

`define FSYNC_ASSIGN_S2I_RSP(rsp_s, fractal_sync_if) \
  assign fractal_sync_if.wake  = rsp_s.wake;         \
  assign fractal_sync_if.dst   = rsp_s.dst;          \
  assign fractal_sync_if.error = rsp_s.error;

`endif /* FSYNC_ASSIGN_SVH_ */