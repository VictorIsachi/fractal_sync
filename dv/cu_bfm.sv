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
 * CU BFM VIP to check stand-alone fractal synchronization module
 */

import fractal_dv_pkg::*;

class cu_bfm #(
  parameter int unsigned VIF_WIDTH = 0
);

  string instance_name;
  
  virtual fractal_if.mst_port #(.LVL_WIDTH(VIF_WIDTH)) vif_master;

  function new(string instance_name, virtual fractal_if.mst_port #(.LVL_WIDTH(VIF_WIDTH)) vif_master);
    this.instance_name = instance_name;
    this.vif_master    = vif_master;
  endfunction: new

  task automatic init();
    vif_master.level = 1'b0;
    vif_master.sync  = 1'b0;
    vif_master.ack   = 1'b0;
  endtask: init
  
  task automatic sync_req(sync_transaction fsync, int unsigned comp_cycles, int unsigned max_rand_cycles, const ref logic clk);
    int unsigned rand_cycles = $urandom_range(0, max_rand_cycles);
    repeat (comp_cycles + max_rand_cycles) @(negedge clk);
    @(negedge clk);
    vif_master.level = fsync.transaction_error ? fsync.sync_level + $urandom_range(1, fractal_dv_pkg::MAX_ERROR) : fsync.sync_level;
    vif_master.sync  = 1'b1;
    @(negedge clk);
    vif_master.sync  = 1'b0;
  endtask: sync_req

  task automatic sync_ack(sync_transaction fsync_req, ref sync_transaction fsync_rsp, const ref logic clk);
    fsync_rsp.scp(fsync_req);
    do
      @(negedge clk);
    while (!vif_master.wake);
    fsync_rsp.update_error(vif_master.error);
    @(negedge clk);
    vif_master.ack = 1'b1;
    @(negedge clk);
    vif_master.ack = 1'b0;
  endtask: sync_ack

  task automatic sync(input sync_transaction fsync_req, ref sync_transaction fsync_rsp, input int unsigned comp_cycles, input int unsigned max_rand_cycles, const ref logic clk);
    fork
      begin
        $display("BFM instance [%s]: synchronization request", instance_name);
        fsync_req.print();
        sync_req(fsync_req, comp_cycles, max_rand_cycles, clk);
      end begin
        sync_ack(fsync_req, fsync_rsp, clk);
        $display("BFM instance [%s]: synchronization response", instance_name);
        fsync_rsp.print();
      end
    join
  endtask: sync
  
endclass: cu_bfm
