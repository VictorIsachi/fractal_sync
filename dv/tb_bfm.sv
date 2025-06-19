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
 * TB for FractalSync networks
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
  
  // Testbench parameters
  parameter int unsigned N_TESTS = 7;

  parameter int unsigned N_CU_Y = 16;
  parameter int unsigned N_CU_X = 16;

  parameter int unsigned MIN_COMP_CYCLES = 0;
  parameter int unsigned MAX_COMP_CYCLES = 0;
  parameter int unsigned MAX_RAND_CYCLES = 0;

  // Testbench localparams - DO NOT CHANGE
  localparam int unsigned N_CU  = N_CU_Y*N_CU_X;
  localparam int unsigned N_LVL = $clog2(N_CU);

  localparam int unsigned ROOT_AGGR_W = 1;
  localparam int unsigned CU_AGGR_W   = ROOT_AGGR_W+N_LVL;
  localparam int unsigned CU_LVL_W    = $clog2(CU_AGGR_W-1);
  localparam int unsigned CU_ID_W     = N_LVL-1 >= 2 ? N_LVL-1 : 2;
  localparam int unsigned ROOT_LVL_W  = CU_LVL_W;
  localparam int unsigned ROOT_ID_W   = CU_ID_W;
  localparam int unsigned NBR_AGGR_W  = 1;
  localparam int unsigned NBR_LVL_W   = 1;
  localparam int unsigned NBR_ID_W    = 2;

  // Testbench type definitions
  `FSYNC_TYPEDEF_ALL(ht_cu_fsync,  logic[CU_AGGR_W-1:0],   logic[CU_LVL_W-1:0],   logic[CU_ID_W-1:0])
  `FSYNC_TYPEDEF_ALL(vt_cu_fsync,  logic[CU_AGGR_W-1:0],   logic[CU_LVL_W-1:0],   logic[CU_ID_W-1:0])
  `FSYNC_TYPEDEF_ALL(hn_cu_fsync,  logic[NBR_AGGR_W-1:0],  logic[NBR_LVL_W-1:0],  logic[NBR_ID_W-1:0])
  `FSYNC_TYPEDEF_ALL(vn_cu_fsync,  logic[NBR_AGGR_W-1:0],  logic[NBR_LVL_W-1:0],  logic[NBR_ID_W-1:0])
  `FSYNC_TYPEDEF_ALL(h_root_fsync, logic[ROOT_AGGR_W-1:0], logic[ROOT_LVL_W-1:0], logic[ROOT_ID_W-1:0])
  `FSYNC_TYPEDEF_ALL(v_root_fsync, logic[ROOT_AGGR_W-1:0], logic[ROOT_LVL_W-1:0], logic[ROOT_ID_W-1:0])

  // Testbench internal signals
  logic clk, rstn;

  int unsigned comp_cycles[N_CU];
  int unsigned max_rand_cycles[N_CU];

  sync_transaction sync_req[N_CU];
  sync_transaction sync_rsp[N_CU];

  int unsigned detected_errors;
  time         sync_time;

  ht_cu_fsync_req_t  ht_cu_fsync_req[N_CU][1]; // Single link CU-FSync interface
  ht_cu_fsync_rsp_t  ht_cu_fsync_rsp[N_CU][1]; // Single link CU-FSync interface
  vt_cu_fsync_req_t  vt_cu_fsync_req[N_CU][1]; // Single link CU-FSync interface
  vt_cu_fsync_rsp_t  vt_cu_fsync_rsp[N_CU][1]; // Single link CU-FSync interface
  hn_cu_fsync_req_t  hn_cu_fsync_req[N_CU];
  hn_cu_fsync_rsp_t  hn_cu_fsync_rsp[N_CU];
  vn_cu_fsync_req_t  vn_cu_fsync_req[N_CU];
  vn_cu_fsync_rsp_t  vn_cu_fsync_rsp[N_CU];
  h_root_fsync_req_t h_root_fsync_req[1][1]; // Single node, single link root node out interface
  h_root_fsync_rsp_t h_root_fsync_rsp[1][1]; // Single node, single link root node out interface
  v_root_fsync_req_t v_root_fsync_req[1][1]; // Single node, single link root node out interface
  v_root_fsync_rsp_t v_root_fsync_rsp[1][1]; // Single node, single link root node out interface

  // CU-FractalSync network interfaces
  fractal_sync_if #(.AGGR_WIDTH(CU_AGGR_W),  .LVL_WIDTH(CU_LVL_W),  .ID_WIDTH(CU_ID_W))  if_cu_h_tree[N_CU]();
  fractal_sync_if #(.AGGR_WIDTH(CU_AGGR_W),  .LVL_WIDTH(CU_LVL_W),  .ID_WIDTH(CU_ID_W))  if_cu_v_tree[N_CU]();
  fractal_sync_if #(.AGGR_WIDTH(NBR_AGGR_W), .LVL_WIDTH(NBR_LVL_W), .ID_WIDTH(NBR_ID_W)) if_cu_h_nbr[N_CU]();
  fractal_sync_if #(.AGGR_WIDTH(NBR_AGGR_W), .LVL_WIDTH(NBR_LVL_W), .ID_WIDTH(NBR_ID_W)) if_cu_v_nbr[N_CU]();

  // Interface - Req/Rsp conversion
  for (genvar i = 0; i < N_CU; i++) begin
    `FSYNC_ASSIGN_I2S_REQ(if_cu_h_tree[i],       ht_cu_fsync_req[i][0])
    `FSYNC_ASSIGN_S2I_RSP(ht_cu_fsync_rsp[i][0], if_cu_h_tree[i])
    `FSYNC_ASSIGN_I2S_REQ(if_cu_v_tree[i],       vt_cu_fsync_req[i][0])
    `FSYNC_ASSIGN_S2I_RSP(vt_cu_fsync_rsp[i][0], if_cu_v_tree[i])
    `FSYNC_ASSIGN_I2S_REQ(if_cu_h_nbr[i],        hn_cu_fsync_req[i])
    `FSYNC_ASSIGN_S2I_RSP(hn_cu_fsync_rsp[i],    if_cu_h_nbr[i])
    `FSYNC_ASSIGN_I2S_REQ(if_cu_v_nbr[i],        vn_cu_fsync_req[i])
    `FSYNC_ASSIGN_S2I_RSP(vn_cu_fsync_rsp[i],    if_cu_v_nbr[i])
  end

  // Hardwired synchronization tree root signals
  assign h_root_fsync_rsp[0][0].wake    = 1'b0;
  assign h_root_fsync_rsp[0][0].sig.lvl = '0;
  assign h_root_fsync_rsp[0][0].sig.id  = '0;
  assign h_root_fsync_rsp[0][0].error   = 1'b0;
  assign v_root_fsync_rsp[0][0].wake    = 1'b0;
  assign v_root_fsync_rsp[0][0].sig.lvl = '0;
  assign v_root_fsync_rsp[0][0].sig.id  = '0;
  assign v_root_fsync_rsp[0][0].error   = 1'b0;

  // BFMs of CUs
  cu_bfm #(.FSYNC_TREE_AGGR_WIDTH(CU_AGGR_W), .FSYNC_TREE_LVL_WIDTH(CU_LVL_W), .FSYNC_TREE_ID_WIDTH(CU_ID_W),
           .FSYNC_NBR_AGGR_WIDTH(NBR_AGGR_W), .FSYNC_NBR_LVL_WIDTH(NBR_LVL_W), .FSYNC_NBR_ID_WIDTH(NBR_ID_W)) cu_bfms[N_CU];
  
  // Create and initialize CU BFMs
  for (genvar y = 0; y < N_CU_Y; y++) begin: gen_y_cu_bfm
    for (genvar x = 0; x < N_CU_X; x++) begin: gen_x_cu_bfm
      initial begin
        cu_bfms[y*N_CU_X+x] = new(.instance_name($sformatf("cu_bfm_%0d(%0d,%0d)", y*N_CU_X+x, y, x)),
                                  .vif_master_h_tree(if_cu_h_tree[y*N_CU_X+x]),
                                  .vif_master_v_tree(if_cu_v_tree[y*N_CU_X+x]),
                                  .vif_master_h_nbr(if_cu_h_nbr[y*N_CU_X+x]),
                                  .vif_master_v_nbr(if_cu_v_nbr[y*N_CU_X+x]));
        cu_bfms[y*N_CU_X+x].init();
      end
    end
  end

  // Testbench subroutines
  function automatic void set_req_timing();
    for (int i = 0; i < N_CU; i++) begin
      comp_cycles[i]     = $urandom_range(MIN_COMP_CYCLES, MAX_COMP_CYCLES);
      max_rand_cycles[i] = MAX_RAND_CYCLES;
    end
  endfunction: set_req_timing

  function automatic void get_sync_time(int unsigned transaction_idx);
    sync_time = cu_bfms[0].get_time(transaction_idx);
    for (int i = 1; i < N_CU; i++)
      if (cu_bfms[i].get_time(transaction_idx) > sync_time)
        sync_time = cu_bfms[i].get_time(transaction_idx);
  endfunction: get_sync_time

  function automatic void get_errors();
    detected_errors = 0;
    for (int i = 0; i < N_CU; i++) detected_errors += cu_bfms[i].get_errors();
  endfunction: get_errors

  task automatic run_test();
    fork begin
      for (int i = 0; i < N_CU; i++) begin
        fork
          automatic int j = i;
          cu_bfms[j].sync(sync_req[j], sync_rsp[j], comp_cycles[j], max_rand_cycles[j], clk);
        join_none
      end
      wait fork;
    end join
  endtask: run_test
  
  // Clock
  always begin
    #5 clk = ~clk;
  end

  // Reset and clock init
  initial begin
    clk = 1'b0;

    @(negedge clk);
    rstn = 1'b0;

    repeat(4) @(negedge clk);
    rstn = 1'b1;
  end

  // DUT
  if ((N_CU_Y == 2) && (N_CU_X == 2)) begin: gen_dut_2x2
    fractal_sync_2x2 i_sync_network_dut (
      .clk_i             ( clk              ),
      .rst_ni            ( rstn             ),
      .h_1d_fsync_req_i  ( ht_cu_fsync_req  ),
      .h_1d_fsync_rsp_o  ( ht_cu_fsync_rsp  ),
      .v_1d_fsync_req_i  ( vt_cu_fsync_req  ),
      .v_1d_fsync_rsp_o  ( vt_cu_fsync_rsp  ),
      .h_nbr_fsycn_req_i ( hn_cu_fsync_req  ),
      .h_nbr_fsycn_rsp_o ( hn_cu_fsync_rsp  ),
      .v_nbr_fsycn_req_i ( vn_cu_fsync_req  ),
      .v_nbr_fsycn_rsp_o ( vn_cu_fsync_rsp  ),
      .h_2d_fsync_req_o  ( h_root_fsync_req ),
      .h_2d_fsync_rsp_i  ( h_root_fsync_rsp ),
      .v_2d_fsync_req_o  ( v_root_fsync_req ),
      .v_2d_fsync_rsp_i  ( v_root_fsync_rsp )
    );
  end else if ((N_CU_Y == 4) && (N_CU_X == 4)) begin: gen_dut_4x4
    fractal_sync_4x4 i_sync_network_dut (
      .clk_i             ( clk              ),
      .rst_ni            ( rstn             ),
      .h_1d_fsync_req_i  ( ht_cu_fsync_req  ),
      .h_1d_fsync_rsp_o  ( ht_cu_fsync_rsp  ),
      .v_1d_fsync_req_i  ( vt_cu_fsync_req  ),
      .v_1d_fsync_rsp_o  ( vt_cu_fsync_rsp  ),
      .h_nbr_fsycn_req_i ( hn_cu_fsync_req  ),
      .h_nbr_fsycn_rsp_o ( hn_cu_fsync_rsp  ),
      .v_nbr_fsycn_req_i ( vn_cu_fsync_req  ),
      .v_nbr_fsycn_rsp_o ( vn_cu_fsync_rsp  ),
      .h_2d_fsync_req_o  ( h_root_fsync_req ),
      .h_2d_fsync_rsp_i  ( h_root_fsync_rsp ),
      .v_2d_fsync_req_o  ( v_root_fsync_req ),
      .v_2d_fsync_rsp_i  ( v_root_fsync_rsp )
    );
  end else if ((N_CU_Y == 8) && (N_CU_X == 8)) begin: gen_dut_8x8
    fractal_sync_8x8 i_sync_network_dut (
      .clk_i             ( clk              ),
      .rst_ni            ( rstn             ),
      .h_1d_fsync_req_i  ( ht_cu_fsync_req  ),
      .h_1d_fsync_rsp_o  ( ht_cu_fsync_rsp  ),
      .v_1d_fsync_req_i  ( vt_cu_fsync_req  ),
      .v_1d_fsync_rsp_o  ( vt_cu_fsync_rsp  ),
      .h_nbr_fsycn_req_i ( hn_cu_fsync_req  ),
      .h_nbr_fsycn_rsp_o ( hn_cu_fsync_rsp  ),
      .v_nbr_fsycn_req_i ( vn_cu_fsync_req  ),
      .v_nbr_fsycn_rsp_o ( vn_cu_fsync_rsp  ),
      .h_2d_fsync_req_o  ( h_root_fsync_req ),
      .h_2d_fsync_rsp_i  ( h_root_fsync_rsp ),
      .v_2d_fsync_req_o  ( v_root_fsync_req ),
      .v_2d_fsync_rsp_i  ( v_root_fsync_rsp )
    );
  end else if ((N_CU_Y == 16) && (N_CU_X == 16)) begin: gen_dut_16x16
    fractal_sync_16x16 i_sync_network_dut (
      .clk_i             ( clk              ),
      .rst_ni            ( rstn             ),
      .h_1d_fsync_req_i  ( ht_cu_fsync_req  ),
      .h_1d_fsync_rsp_o  ( ht_cu_fsync_rsp  ),
      .v_1d_fsync_req_i  ( vt_cu_fsync_req  ),
      .v_1d_fsync_rsp_o  ( vt_cu_fsync_rsp  ),
      .h_nbr_fsycn_req_i ( hn_cu_fsync_req  ),
      .h_nbr_fsycn_rsp_o ( hn_cu_fsync_rsp  ),
      .v_nbr_fsycn_req_i ( vn_cu_fsync_req  ),
      .v_nbr_fsycn_rsp_o ( vn_cu_fsync_rsp  ),
      .h_2d_fsync_req_o  ( h_root_fsync_req ),
      .h_2d_fsync_rsp_i  ( h_root_fsync_rsp ),
      .v_2d_fsync_req_o  ( v_root_fsync_req ),
      .v_2d_fsync_rsp_i  ( v_root_fsync_rsp )
    );
  end else $fatal("Detected unsupported synchronization network configuration!!!");
  
  // Tests
  task automatic same_rand_sync();
    sync_req[0] = new();
    sync_req[0].set_uid();
    assert(sync_req[0].randomize() with {this.sync_level inside {2}; this.sync_aggregate inside {'b1}; this.sync_barrier_id inside {0};}) else $error("Sync randomization failed");
    sync_rsp[0] = new();
    for (int i = 1; i < N_CU; i++) begin
      sync_req[i].scp(sync_req[0]);
      sync_rsp[i] = new();
    end
  endtask: same_rand_sync

  task automatic distinct_2x2_sync();
    for (int i = 0; i < N_CU; i++) begin
      sync_req[i] = new();
      sync_req[i].set_uid();
      sync_rsp[i] = new();
      case (i)
        0:  assert(sync_req[i].randomize() with {this.sync_level inside {2}; this.sync_aggregate inside {'b1}; this.sync_barrier_id inside {0};}) else $error("Sync randomization failed");
        1:  assert(sync_req[i].randomize() with {this.sync_level inside {2}; this.sync_aggregate inside {'b1}; this.sync_barrier_id inside {0};}) else $error("Sync randomization failed");
        2:  assert(sync_req[i].randomize() with {this.sync_level inside {2}; this.sync_aggregate inside {'b1}; this.sync_barrier_id inside {0};}) else $error("Sync randomization failed");
        3:  assert(sync_req[i].randomize() with {this.sync_level inside {2}; this.sync_aggregate inside {'b1}; this.sync_barrier_id inside {0};}) else $error("Sync randomization failed");
      endcase
    end
  endtask: distinct_2x2_sync
  
  task automatic distinct_4x4_sync();
    for (int i = 0; i < N_CU; i++) begin
      sync_req[i] = new();
      sync_req[i].set_uid();
      sync_rsp[i] = new();
      case (i)
        0:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        1:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        2:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        3:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        4:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        5:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        6:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        7:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        8:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        9:  assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        10: assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        11: assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        12: assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        13: assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        14: assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
        15: assert(sync_req[i].randomize() with {this.sync_level inside {4}; this.sync_aggregate inside {'b111}; this.sync_barrier_id inside {7};}) else $error("Sync randomization failed");
      endcase
    end
  endtask: distinct_4x4_sync

  task automatic nbr_h_sync();
    localparam int unsigned level     = 1;
    localparam bit[31:0]    aggregate = 0;
    localparam int unsigned id        = 0;
    for (int i = 0; i < N_CU; i++) begin
      sync_req[i] = new();
      sync_req[i].set_uid();
      assert(sync_req[i].randomize() with {this.sync_level inside {level}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id};}) else $error("Sync randomization failed");
      sync_rsp[i] = new();
    end
  endtask: nbr_h_sync
  
  task automatic nbr_h_tor_sync();
    localparam int unsigned level_h   = 1;
    localparam bit[31:0]    aggregate = 0;
    localparam int unsigned id_h      = 2;
    for (int i = 0; i < N_CU; i++) begin
      sync_req[i] = new();
      sync_req[i].set_uid();
      if (!(i%N_CU_X inside {0, N_CU_X-1})) begin
        assert(sync_req[i].randomize() with {this.sync_level inside {level_h}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id_h};}) else $error("Sync randomization failed");
      end else begin
        int unsigned level = N_LVL-1;
        int unsigned id    = 2*((i/N_CU_X)%(N_CU_Y/2));
        assert(sync_req[i].randomize() with {this.sync_level inside {level}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id};}) else $error("Sync randomization failed");
      end
      sync_rsp[i] = new();
    end
  endtask: nbr_h_tor_sync

  task automatic nbr_v_sync();
    localparam int unsigned level     = 1;
    localparam bit[31:0]    aggregate = 0;
    localparam int unsigned id        = 1;
    for (int i = 0; i < N_CU; i++) begin
      sync_req[i] = new();
      sync_req[i].set_uid();
      assert(sync_req[i].randomize() with {this.sync_level inside {level}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id};}) else $error("Sync randomization failed");
      sync_rsp[i] = new();
    end
  endtask: nbr_v_sync

  task automatic nbr_v_tor_sync();
    localparam int unsigned level_v   = 1;
    localparam bit[31:0]    aggregate = 0;
    localparam int unsigned id_v      = 3;
    for (int i = 0; i < N_CU; i++) begin
      sync_req[i] = new();
      sync_req[i].set_uid();
      if (!(i/N_CU_X inside {0, N_CU_Y-1})) begin
        assert(sync_req[i].randomize() with {this.sync_level inside {level_v}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id_v};}) else $error("Sync randomization failed");
      end else begin
        int unsigned level = N_LVL-1;
        int unsigned id    = 2*((i%N_CU_X)%(N_CU_X/2))+1;
        assert(sync_req[i].randomize() with {this.sync_level inside {level}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id};}) else $error("Sync randomization failed");
      end
      sync_rsp[i] = new();
    end
  endtask: nbr_v_tor_sync
  
  task automatic row_sync();
    localparam int unsigned level     = N_LVL-1;
               bit[31:0]    aggregate = 0;
    for (int i = 0; i < level/2; i++) aggregate |= (1'b1 << 2*i);
    for (int i = 0; i < N_CU; i++) begin
      int unsigned id = 2*((i/N_CU_X)%(N_CU_Y/2));
      sync_req[i] = new();
      sync_req[i].set_uid();
      assert(sync_req[i].randomize() with {this.sync_level inside {level}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id};}) else $error("Sync randomization failed");
      sync_rsp[i] = new();
    end
  endtask: row_sync

  task automatic col_sync();
    localparam int unsigned level     = N_LVL-1;
               bit[31:0]    aggregate = 0;
    for (int i = 0; i < level/2; i++) aggregate |= (1'b1 << 2*i);
    for (int i = 0; i < N_CU; i++) begin
      int unsigned id = 2*((i%N_CU_X)%(N_CU_X/2))+1;
      sync_req[i] = new();
      sync_req[i].set_uid();
      assert(sync_req[i].randomize() with {this.sync_level inside {level}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id};}) else $error("Sync randomization failed");
      sync_rsp[i] = new();
    end
  endtask: col_sync

  task automatic global_sync();
    localparam int unsigned level     = N_LVL;
    localparam bit[31:0]    aggregate = {(N_LVL-1){1'b1}};
    localparam int unsigned id        = 2**(N_LVL-1)-1;
    for (int i = 0; i < N_CU; i++) begin
      sync_req[i] = new();
      sync_req[i].set_uid();
      assert(sync_req[i].randomize() with {this.sync_level inside {level}; this.sync_aggregate inside {aggregate}; this.sync_barrier_id inside {id};}) else $error("Sync randomization failed");
      sync_rsp[i] = new();
    end
  endtask: global_sync
  
  // Run test
  initial begin    
    // Wait for reset
    repeat(10) @(negedge clk);

    for (int t = 0; t < N_TESTS; t++) begin
      // Generate synchronization requests
      //same_rand_sync();
      //distinct_2x2_sync();
      //distinct_4x4_sync();
      if (t == 0) begin nbr_h_sync();     $display("\n  --> STARTED TEST: %s", "nbr_h_sync");     end
      if (t == 1) begin nbr_h_tor_sync(); $display("\n  --> STARTED TEST: %s", "nbr_h_tor_sync"); end
      if (t == 2) begin nbr_v_sync();     $display("\n  --> STARTED TEST: %s", "nbr_v_sync");     end
      if (t == 3) begin nbr_v_tor_sync(); $display("\n  --> STARTED TEST: %s", "nbr_v_tor_sync"); end
      if (t == 4) begin row_sync();       $display("\n  --> STARTED TEST: %s", "row_sync");       end
      if (t == 5) begin col_sync();       $display("\n  --> STARTED TEST: %s", "col_sync");       end
      if (t == 6) begin global_sync();    $display("\n  --> STARTED TEST: %s", "global_sync");    end

      // Set random synchronization request delay
      set_req_timing();

      // Send synchronization requests and wait for responses
      run_test();

      // Update synchronization time
      get_sync_time(t);
      $display("\n  <-- ENDED TEST: synchronization time %0tns", sync_time);
    end
    get_errors();

    repeat(4) @(negedge clk);
    
    $info("Test finished with %0d errors: %s", detected_errors, detected_errors ? "[FAIL]" : "[PASS]");

    $stop;
  end
  
endmodule: tb_bfm
