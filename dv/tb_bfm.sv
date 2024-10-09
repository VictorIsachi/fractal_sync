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
  import fractal_dv_pkg::*;
#(
)(
);
  
  localparam int unsigned N_TESTS = 10;

  localparam int unsigned LEVELS        = 2;
  localparam int unsigned CU_PORTS      = 2**LEVELS;
  localparam int unsigned SYNC_PORTS    = 2**LEVELS - 2;
  localparam int unsigned TOP_PORTS     = 1;
  localparam int unsigned CU_LVL_WIDTH  = LEVELS + 1;
  localparam int unsigned TOP_LVL_WIDTH = 2;

  localparam int unsigned MIN_COMP_CYCLES = 10;
  localparam int unsigned MAX_COMP_CYCLES = 100;
  localparam int unsigned MAX_RAND_CYCLES = 10;

  logic clk, rstn;

  int unsigned errors;
  int unsigned sync_errors;
  int unsigned monitor_errors;
  logic        sync_error;
  logic        monitor_error[TOP_PORTS];

  int unsigned comp_cycles[CU_PORTS];
  int unsigned max_rand_cycles[CU_PORTS];

  sync_transaction sync_req;
  sync_transaction sync_rsp[CU_PORTS];

  fractal_if #(.LVL_WIDTH(CU_LVL_WIDTH))    if_cu[CU_PORTS]();
  fractal_if #(.LVL_WIDTH(CU_LVL_WIDTH-1))  if_sync[SYNC_PORTS](); // NOTE: ONLY 1 LEVEL OF SYNC TREE
  fractal_if #(.LVL_WIDTH(TOP_LVL_WIDTH-1)) if_top[TOP_PORTS]();

  cu_bfm #(.VIF_WIDTH(CU_LVL_WIDTH)) cu_bfms[CU_PORTS];
  for (genvar i = 0; i < CU_PORTS; i++) begin: gen_cu_bfm
    initial begin
      cu_bfms[i] = new(.instance_name($sformatf("cu_bfm_%0d", i)), .vif_master(if_cu[i]));
      cu_bfms[i].init();
    end
  end
  
  // LEVEL 0 - CU's
  for (genvar i = 0; i < 2**(LEVELS-1); i++) begin: gen_cu_sync
    fractal_sync #(
      .SLV_WIDTH ( CU_LVL_WIDTH )
    ) i_cu_fractal_sync (
      .clk_i   ( clk                         ),
      .rstn_i  ( rstn                        ),
      .slaves  ( '{if_cu[2*i], if_cu[2*i+1]} ),
      .masters ( '{if_sync[i]}               )
    );
  end

  // LEVEL 1 - Sync tree
  for (genvar i = 0; i < 2**(LEVELS-2); i++) begin: gen_top_sync
    fractal_sync #(
      .SLV_WIDTH ( TOP_LVL_WIDTH )
    ) i_top_fractal_sync (
      .clk_i   ( clk                             ),
      .rstn_i  ( rstn                            ),
      .slaves  ( '{if_sync[2*i], if_sync[2*i+1]} ),
      .masters ( if_top                          )
    );
  end

  fractal_monitor #(
    .PORT_WIDTH(TOP_LVL_WIDTH-1)
  ) i_top_fractal_sync_monitor (
    .clk_i   ( clk           ),
    .rstn_i  ( rstn          ),
    .ports   ( if_top        ),
    .error_o ( monitor_error )
  );

  for (genvar i = 0; i < TOP_PORTS; i++) begin: gen_monitor_error_reporter
    always @(posedge monitor_error[i]) begin
      $error("[MONITOR %d ERROR]", i);
      monitor_errors++;
    end
  end

  always begin
    #1 errors = sync_errors + monitor_errors;
  end
  
  always begin
    #5 clk = ~clk;
  end

  initial begin    
    clk = 1'b0;

    @(negedge clk);
    rstn = 1'b0;

    repeat(4) @(negedge clk);
    rstn = 1'b1;

    sync_errors = 0;

    for (int t = 0; t < N_TESTS; t++) begin
      sync_req = new();
      sync_req.set_uid();
      for (int i = 0; i < CU_PORTS; i++)
        sync_rsp[i] = new();
      assert(sync_req.randomize() with { this.sync_level inside {1, 2}; this.transaction_error dist {1'b0:=4, 1'b1:=0}; }) else $error("Sync randomization failed");
      for (int i = 0; i < CU_PORTS; i++) begin
        comp_cycles[i]     = $urandom_range(MIN_COMP_CYCLES, MAX_COMP_CYCLES);
        max_rand_cycles[i] = MAX_RAND_CYCLES;
      end
      fork begin
        for (int i = 0; i < CU_PORTS; i++) begin
          fork
            automatic int j = i;
            cu_bfms[j].sync(sync_req, sync_rsp[j], comp_cycles[j], max_rand_cycles[j], clk);
          join_none
        end
        wait fork;
      end join

      sync_error = 1'b0;
      for (int i = 0; i < CU_PORTS; i++)
        if (sync_req.transaction_error != sync_rsp[i].transaction_error)
          sync_error = 1'b1;

      if (sync_error) begin
        $error("[FAIL] Incorrect result");
        sync_errors++;
      end else
        $info("[PASS] Correct result");
    end

    repeat(4) @(negedge clk);
    
    $info("%s Test finished with %d errors", (errors == 0) ? "[PASS]" : "[FAIL]", errors);

    $stop;
  end
  
endmodule: tb_bfm
