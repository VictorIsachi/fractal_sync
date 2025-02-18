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

`define FSYNC_ASSIGN_I2S_MST_SIG(fractal_sync_if, mst_sig_s) \
  assign mst_sig_s.level = fractal_sync_if.level_mst;        \
  assign mst_sig_s.id    = fractal_sync_if.id_mst;

`define FSYNC_ASSIGN_I2S_SLV_SIG(fractal_sync_if, slv_sig_s) \
  assign slv_sig_s.level = fractal_sync_if.level_slv;        \
  assign slv_sig_s.id    = fractal_sync_if.id_slv;

`define FSYNC_ASSIGN_I2S_REQ(fractal_sync_if, req_s)        \
  assign req_s.sync = fractal_sync_if.sync;                 \
  `FSYNC_ASSIGN_I2S_MST_SIG(fractal_sync_if, req_s.mst_sig)

`define FSYNC_ASSIGN_I2S_RSP(fractal_sync_if, rsp_s)        \
  assign rsp_s.wake  = fractal_sync_if.wake;                \
  `FSYNC_ASSIGN_I2S_SLV_SIG(fractal_sync_if, rsp_s.slv_sig) \
  assign rsp_s.error = fractal_sync_if.error;

`define FSYNC_ASSIGN_S2I_MST_SIG(mst_sig_s, fractal_sync_if) \
  assign fractal_sync_if.level_mst = mst_sig_s.level;        \
  assign fractal_sync_if.id_mst    = mst_sig_s.id;

`define FSYNC_ASSIGN_S2I_SLV_SIG(slv_sig_s, fractal_sync_if) \
  assign fractal_sync_if.level_slv = slv_sig_s.level;        \
  assign fractal_sync_if.id_slv    = slv_sig_s.id;

`define FSYNC_ASSIGN_S2I_REQ(req_s, fractal_sync_if)        \
  assign fractal_sync_if.sync = req_s.sync;                 \
  `FSYNC_ASSIGN_S2I_MST_SIG(req_s.mst_sig, fractal_sync_if)

`define FSYNC_ASSIGN_S2I_RSP(rsp_s, fractal_sync_if)        \
  assign fractal_sync_if.wake  = rsp_s.wake;                \
  `FSYNC_ASSIGN_S2I_SLV_SIG(rsp_s.slv_sig, fractal_sync_if) \
  assign fractal_sync_if.error = rsp_s.error;

`endif /* FSYNC_ASSIGN_SVH_ */