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
 * CU BFM VIP to check FractalSync networks
 */

import fractal_dv_pkg::*;

class cu_bfm #(
  parameter int unsigned FSYNC_TREE_AGGR_WIDTH  = 0,
  parameter int unsigned FSYNC_TREE_LVL_WIDTH   = 0,
  parameter int unsigned FSYNC_TREE_ID_WIDTH    = 0,
  parameter int unsigned FSYNC_NBR_AGGR_WIDTH = 0,
  parameter int unsigned FSYNC_NBR_LVL_WIDTH  = 0,
  parameter int unsigned FSYNC_NBR_ID_WIDTH   = 0
);

  string instance_name;
  
  virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_TREE_AGGR_WIDTH), .LVL_WIDTH(FSYNC_TREE_LVL_WIDTH), .ID_WIDTH(FSYNC_TREE_ID_WIDTH)) vif_master_h_tree;
  virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_TREE_AGGR_WIDTH), .LVL_WIDTH(FSYNC_TREE_LVL_WIDTH), .ID_WIDTH(FSYNC_TREE_ID_WIDTH)) vif_master_v_tree;
  virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_NBR_AGGR_WIDTH),  .LVL_WIDTH(FSYNC_NBR_LVL_WIDTH),  .ID_WIDTH(FSYNC_NBR_ID_WIDTH))  vif_master_h_nbr;
  virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_NBR_AGGR_WIDTH),  .LVL_WIDTH(FSYNC_NBR_LVL_WIDTH),  .ID_WIDTH(FSYNC_NBR_ID_WIDTH))  vif_master_v_nbr;

  function new(string instance_name, 
               virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_TREE_AGGR_WIDTH), .LVL_WIDTH(FSYNC_TREE_LVL_WIDTH), .ID_WIDTH(FSYNC_TREE_ID_WIDTH)) vif_master_h_tree,
               virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_TREE_AGGR_WIDTH), .LVL_WIDTH(FSYNC_TREE_LVL_WIDTH), .ID_WIDTH(FSYNC_TREE_ID_WIDTH)) vif_master_v_tree,
               virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_NBR_AGGR_WIDTH),  .LVL_WIDTH(FSYNC_NBR_LVL_WIDTH),  .ID_WIDTH(FSYNC_NBR_ID_WIDTH))  vif_master_h_nbr,
               virtual fractal_sync_if.mst_port #(.AGGR_WIDTH(FSYNC_NBR_AGGR_WIDTH),  .LVL_WIDTH(FSYNC_NBR_LVL_WIDTH),  .ID_WIDTH(FSYNC_NBR_ID_WIDTH))  vif_master_v_nbr);
    this.instance_name    = instance_name;
    this.vif_master_h_tree = vif_master_h_tree;
    this.vif_master_v_tree = vif_master_v_tree;
    this.vif_master_h_nbr  = vif_master_h_nbr;
    this.vif_master_v_nbr  = vif_master_v_nbr;
  endfunction: new

  task automatic init();
    vif_master_h_tree.sync   = 1'b0;
    vif_master_h_tree.aggr   = '0;
    vif_master_h_tree.id_req = '0;
    vif_master_v_tree.sync   = 1'b0;
    vif_master_v_tree.aggr   = '0;
    vif_master_v_tree.id_req = '0;
    vif_master_h_nbr.sync    = 1'b0;
    vif_master_h_nbr.aggr    = '0;
    vif_master_h_nbr.id_req  = '0;
    vif_master_v_nbr.sync    = 1'b0;
    vif_master_v_nbr.aggr    = '0;
    vif_master_v_nbr.id_req  = '0;
  endtask: init
  
  task automatic sync_req(sync_transaction fsync, int unsigned comp_cycles, int unsigned max_rand_cycles, const ref logic clk);
    int unsigned rand_cycles = $urandom_range(0, max_rand_cycles);
    repeat (comp_cycles + rand_cycles) @(negedge clk);
    @(negedge clk);
    if (fsync.sync_level == 1) begin
      case (fsync.sync_barrier_id)
        2'b00: begin
          vif_master_h_tree.aggr   = (1'b1 << (fsync.sync_level-1)) | fsync.sync_aggregate;
          vif_master_h_tree.id_req = fsync.sync_barrier_id;
          vif_master_h_tree.sync   = 1'b1;
        end
        2'b01: begin
          vif_master_v_tree.aggr   = (1'b1 << (fsync.sync_level-1)) | fsync.sync_aggregate;
          vif_master_v_tree.id_req = fsync.sync_barrier_id;
          vif_master_v_tree.sync   = 1'b1;
        end
        2'b10: begin
          vif_master_h_nbr.aggr   = (1'b1 << (fsync.sync_level-1)) | fsync.sync_aggregate;
          vif_master_h_nbr.id_req = fsync.sync_barrier_id;
          vif_master_h_nbr.sync   = 1'b1;
        end
        2'b11: begin
          vif_master_v_nbr.aggr   = (1'b1 << (fsync.sync_level-1)) | fsync.sync_aggregate;
          vif_master_v_nbr.id_req = fsync.sync_barrier_id;
          vif_master_v_nbr.sync   = 1'b1;
        end
        default: $fatal("Detected synchronization request at level 1 with invalid barrier ID!!!");
      endcase
    end else if (fsync.sync_level > 1) begin
      if (fsync.sync_barrier_id[0] == 1'b0) begin
        vif_master_h_tree.aggr   = (1'b1 << (fsync.sync_level-1)) | fsync.sync_aggregate;
        vif_master_h_tree.id_req = fsync.sync_barrier_id;
        vif_master_h_tree.sync   = 1'b1;
      end else begin
        vif_master_v_tree.aggr   = (1'b1 << (fsync.sync_level-1)) | fsync.sync_aggregate;
        vif_master_v_tree.id_req = fsync.sync_barrier_id;
        vif_master_v_tree.sync   = 1'b1;
      end
    end else $fatal("Detected synchronization request at level 0!!!");
    @(negedge clk);
    vif_master_h_tree.sync  = 1'b0;
    vif_master_v_tree.sync  = 1'b0;
    vif_master_h_nbr.sync = 1'b0;
    vif_master_v_nbr.sync = 1'b0;
  endtask: sync_req

  task automatic sync_rsp(ref sync_transaction fsync_rsp, const ref logic clk);
    bit detected_single_wake = 0;
    do
      @(negedge clk);
    while (!vif_master_h_tree.wake && !vif_master_v_tree.wake && !vif_master_h_nbr.wake && !vif_master_v_nbr.wake);
    if (vif_master_h_tree.wake) begin
      if (detected_single_wake == 1'b0) detected_single_wake = 1'b1;
      else $fatal("Detected synchronization wakes from multiple interfaces!!!");
      fsync_rsp.set(vif_master_h_tree.lvl, 0, vif_master_h_tree.id_rsp);
    end else if (vif_master_v_tree.wake) begin
      if (detected_single_wake == 1'b0) detected_single_wake = 1'b1;
      else $fatal("Detected synchronization wakes from multiple interfaces!!!");
      fsync_rsp.set(vif_master_v_tree.lvl, 0, vif_master_v_tree.id_rsp);
    end else if (vif_master_h_nbr.wake) begin
      if (detected_single_wake == 1'b0) detected_single_wake = 1'b1;
      else $fatal("Detected synchronization wakes from multiple interfaces!!!");
      fsync_rsp.set(vif_master_h_nbr.lvl, 0, vif_master_h_nbr.id_rsp);
    end else if (vif_master_v_nbr.wake) begin
      if (detected_single_wake == 1'b0) detected_single_wake = 1'b1;
      else $fatal("Detected synchronization wakes from multiple interfaces!!!");
      fsync_rsp.set(vif_master_v_nbr.lvl, 0, vif_master_v_nbr.id_rsp);
    end else $fatal("Detected synchronization wake at unidentified interface!!!");
  endtask: sync_rsp

  task automatic sync(input sync_transaction fsync_req, ref sync_transaction fsync_rsp, input int unsigned comp_cycles, input int unsigned max_rand_cycles, const ref logic clk);
    fork
      begin
        $display("BFM instance [%s]: synchronization request", instance_name);
        fsync_req.print();
        sync_req(fsync_req, comp_cycles, max_rand_cycles, clk);
      end begin
        sync_rsp(fsync_rsp, clk);
        $display("BFM instance [%s]: synchronization response", instance_name);
        fsync_rsp.print();
      end
    join
  endtask: sync
  
endclass: cu_bfm
