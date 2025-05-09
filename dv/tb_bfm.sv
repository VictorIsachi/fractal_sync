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
 * TB for stand-alone fractal synchronization module
 *
 * WARRNING: Error injection testing must be performed
 */

module tb_bfm 
  import fractal_sync_pkg::*;
  import fractal_dv_pkg::*;
#(
)(
);
  
  `include "../hw/include/fractal_sync/typedef.svh"
  `include "../hw/include/fractal_sync/assign.svh"
  
  localparam int unsigned N_TESTS = 10;

  localparam int unsigned CU_L_REGS    = 1;
  localparam int unsigned CU_R_LINES   = 1;
  localparam int unsigned CU_AGGR_W    = 6;
  localparam int unsigned CU_ID_W      = 5;
  localparam int unsigned CU_FIFO_D    = 1;
  localparam int unsigned CU_IN_PORTS  = 2;
  localparam int unsigned CU_OUT_PORTS = CU_IN_PORTS/2;

  `FSYNC_TYPEDEF_ALL(cu_fsync_in, logic[CU_AGGR_W-1:0], logic[CU_ID_W-1:0], logic[1:0], logic[1:0])
  `FSYNC_TYPEDEF_ALL(cu_fsync_out, logic[CU_AGGR_W-2:0], logic[CU_ID_W-1:0], logic[3:0], logic[3:0])

  localparam int unsigned MIN_COMP_CYCLES = 10;
  localparam int unsigned MAX_COMP_CYCLES = 100;
  localparam int unsigned MAX_RAND_CYCLES = 10;

  logic clk, rstn;

  int unsigned comp_cycles[CU_IN_PORTS];
  int unsigned max_rand_cycles[CU_IN_PORTS];

  sync_transaction sync_req;
  sync_transaction sync_rsp[CU_IN_PORTS];

  cu_fsync_in_req_t  in_req[CU_IN_PORTS];
  cu_fsync_in_rsp_t  in_rsp[CU_IN_PORTS];
  cu_fsync_out_req_t out_req[CU_OUT_PORTS];
  cu_fsync_out_rsp_t out_rsp[CU_OUT_PORTS];

  fractal_sync_if #(.AGGR_WIDTH(CU_AGGR_W), .ID_WIDTH(CU_ID_W)) if_cu[CU_IN_PORTS]();

  cu_bfm #(.AGGR_WIDTH(CU_AGGR_W), .ID_WIDTH(CU_ID_W)) cu_bfms[CU_IN_PORTS];
  
  for (genvar i = 0; i < CU_IN_PORTS; i++) begin: gen_cu_bfm
    initial begin
      cu_bfms[i] = new(.instance_name($sformatf("cu_bfm_%0d", i)), .vif_master(if_cu[i]));
      cu_bfms[i].init();
    end
  end

  fractal_sync_1d #(
    .NODE_TYPE       ( fractal_sync_pkg::HOR_NODE ),
    .RF_TYPE         ( fractal_sync_pkg::CAM_RF   ),
    .N_LOCAL_REGS    ( CU_L_REGS                  ),
    .N_REMOTE_LINES  ( CU_R_LINES                 ),
    .AGGREGATE_WIDTH ( CU_AGGR_W                  ),
    .ID_WIDTH        ( CU_ID_W                    ),
    .fsync_req_in_t  ( cu_fsync_in_req_t          ),
    .fsync_rsp_in_t  ( cu_fsync_in_rsp_t          ),
    .fsync_req_out_t ( cu_fsync_out_req_t         ),
    .fsync_rsp_out_t ( cu_fsync_out_rsp_t         ),
    .FIFO_DEPTH      ( CU_FIFO_D                  ),
    .IN_PORTS        ( CU_IN_PORTS                ),
    .OUT_PORTS       ( CU_OUT_PORTS               )
  ) i_dut_fractal_sync_1d (
    .clk_i     ( clk     ),
    .rst_ni    ( rstn    ),
    .req_in_i  ( in_req  ),
    .rsp_in_o  ( in_rsp  ),
    .req_out_o ( out_req ),
    .rsp_out_i ( out_rsp )
  );

  for (genvar i = 0; i < CU_IN_PORTS; i++) begin
    `FSYNC_ASSIGN_I2S_REQ(if_cu[i], in_req[i])
    `FSYNC_ASSIGN_S2I_RSP(in_rsp[i], if_cu[i])
  end

  // for (genvar i = 0; i < CU_OUT_PORTS; i++) begin
  //   assign out_rsp[i].wake  = 1'b0;
  //   assign out_rsp[i].dst   = '0;
  //   assign out_rsp[i].error = 1'b0;
  // end
  
  always begin
    #5 clk = ~clk;
  end

  initial begin    
    clk = 1'b0;

    @(negedge clk);
    rstn = 1'b0;

    out_rsp[0].wake  = 1'b0;
    out_rsp[0].dst   = '0;
    out_rsp[0].error = 1'b0;

    repeat(4) @(negedge clk);
    rstn = 1'b1;

    repeat(4) @(negedge clk);
    out_rsp[0].wake  = 1'b1;
    out_rsp[0].dst   = 2;
    out_rsp[0].error = 1'b0;
    @(negedge clk);
    out_rsp[0].wake  = 1'b0;

    repeat(4) @(negedge clk);
    out_rsp[0].wake  = 1'b1;
    out_rsp[0].dst   = 3;
    out_rsp[0].error = 1'b0;
    @(negedge clk);
    out_rsp[0].wake  = 1'b0;

    for (int t = 0; t < N_TESTS; t++) begin
      sync_req = new();
      sync_req.set_uid();
      for (int i = 0; i < CU_IN_PORTS; i++)
        sync_rsp[i] = new();
      assert(sync_req.randomize() with { this.sync_level inside {2}; this.sync_aggregate inside {1}; this.sync_barrier_id inside {0}; }) else $error("Sync randomization failed");
      for (int i = 0; i < CU_IN_PORTS; i++) begin
        comp_cycles[i]     = $urandom_range(MIN_COMP_CYCLES, MAX_COMP_CYCLES);
        max_rand_cycles[i] = MAX_RAND_CYCLES;
      end
      fork begin
        for (int i = 0; i < CU_IN_PORTS; i++) begin
          fork
            automatic int j = i;
            cu_bfms[j].sync(sync_req, sync_rsp[j], comp_cycles[j], max_rand_cycles[j], clk);
          join_none
        end
        wait fork;
      end join
    end

    repeat(4) @(negedge clk);
    
    $info("Test finished");

    $stop;
  end
  
endmodule: tb_bfm
