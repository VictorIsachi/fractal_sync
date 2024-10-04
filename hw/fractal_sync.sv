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
 * Fractal synchronization module
 * Asynchronous valid low reset
 *
 * Parameters:
 *  SLV_WIDTH - LVL_WIDTH of slave ports
 *
 * Interface signals:
 *  Slave ports for synchronization request/response
 *  Master port for synchronization propagation
 *
 * WARRNING: Proper measures for error detection and handling must be implemented
 */

module fractal_sync #(
  parameter int unsigned SLV_WIDTH  = 0,
  localparam int unsigned SLV_PORTS = 2,
  localparam int unsigned MST_PORTS = 1,
  localparam bit          SPD_COMB  = 0,
  localparam bit          APD_COMB  = 1
)(
  input  logic        clk_i,
  input  logic        rstn_i,
  fractal_if.slv_port slaves [SLV_PORTS],
  fractal_if.mst_port masters[MST_PORTS]
);
  
  initial FRACTAL_SYNC_SLV_WIDTH: assert (SLV_WIDTH > 0) else $fatal("SLV_WIDTH must be > 0");

  localparam int unsigned MST_WIDTH = SLV_WIDTH - 1;
  
  logic[SLV_WIDTH-1:0] slv_level_d[SLV_PORTS], slv_level_q[SLV_PORTS];

  logic valid_level;
  logic local_sync;

  logic[SLV_PORTS-1:0] slv_syncs;
  logic                slv_sync;
  logic                clear_sync_detector;
  logic[SLV_PORTS-1:0] slv_acks;
  logic                slv_ack;
  logic                clear_ack_detector;
  logic                slv_wake;
  logic                slv_error_d, slv_error_q;

  logic                mst_sync;
  logic                mst_ack;
  logic[MST_PORTS-1:0] mst_wakes;
  logic                mst_wake;
  logic[MST_PORTS-1:0] mst_errors;
  logic                mst_error;

  typedef enum logic[1:0] {
    IDLE,
    SYNC,
    PROPAGATE
  } state_e;

  state_e c_state, n_state;

  for (genvar i = 0; i < SLV_PORTS; i++) begin: level_sampler
    assign slv_level_d[i] = slaves[i].level;
    always_ff @(posedge clk_i, negedge rstn_i) begin: level_register
      if      (!rstn_i)      slv_level_q[i] <= '0;
      else if (slv_syncs[i]) slv_level_q[i] <= slv_level_d[i];
    end
  end

  for (genvar i = 0; i < MST_PORTS; i++) begin: mst_level_generator
    if (MST_WIDTH)
      assign masters[i].level = slv_level_q[0][(SLV_WIDTH-1)-:MST_WIDTH];
    else
      assign masters[i].level = 1'b0;
  end

  assign local_sync = MST_WIDTH ? slv_level_q[0][0] : 1'b1;

  always_comb begin: level_validator
    valid_level = 1'b1;
    for (int i = 0; i < SLV_PORTS-1; i++)
      if (slv_level_q[i] != slv_level_q[i+1])
        valid_level = 1'b0;
  end

  for (genvar i = 0; i < SLV_PORTS; i++) begin
    assign slv_syncs[i] = slaves[i].sync;
    assign slv_acks[i]  = slaves[i].ack;
  end
  
  presence_detector #(
    .PARTICIPANTS ( SLV_PORTS ),
    .COMB         ( SPD_COMB  )
  ) i_sync_detector (
    .clk_i                                ,
    .rstn_i                               ,
    .clear_i       ( clear_sync_detector ),
    .present_i     ( slv_syncs           ),
    .all_present_o ( slv_sync            )
  );
  
  presence_detector #(
    .PARTICIPANTS ( SLV_PORTS ),
    .COMB         ( APD_COMB  )
  ) i_ack_detector (
    .clk_i                               ,
    .rstn_i                              ,
    .clear_i       ( clear_ack_detector ),
    .present_i     ( slv_acks           ),
    .all_present_o ( slv_ack            )
  );

  for (genvar i = 0; i < SLV_PORTS; i++) begin: gen_slv_wake_error_generator
    assign slaves[i].wake  = slv_wake;
    assign slaves[i].error = slv_error_q;
  end

  for (genvar i = 0; i < MST_PORTS; i++) begin: gen_mst_sync_ack_generator
    assign masters[i].sync = mst_sync;
    assign masters[i].ack  = mst_ack;
  end
  
  for (genvar i = 0; i < MST_PORTS; i++) begin
    assign mst_wakes[i]  = masters[i].wake;
    assign mst_errors[i] = masters[i].error;
  end
  
  always_comb begin: mst_wake_generator
    mst_wake = 1'b1;
    for (int i = 0; i < MST_PORTS; i++)
      if (mst_wakes[i] != 1'b1)
        mst_wake = 1'b0;
  end

  always_comb begin: mst_error_generator
    mst_error = 1'b0;
    for (int i = 0; i < MST_PORTS; i++)
      if (mst_errors[i] == 1'b1)
        mst_error = 1'b1;
  end

  always_ff @(posedge clk_i, negedge rstn_i) begin: fsm_state_register
    if (!rstn_i) begin
      c_state     <= IDLE;
      slv_error_q <= 1'b0;
    end else begin
      c_state     <= n_state;
      slv_error_q <= slv_error_d;
    end
  end

  always_comb begin: fsm_next_state_logic
    n_state     = c_state;
    slv_error_d = slv_error_q;

    unique case (c_state)
      IDLE     : if      (slv_sync & (local_sync | ~valid_level)) begin n_state = SYNC;      slv_error_d = slv_error_q | ~valid_level; end
                 else if (slv_sync & ~local_sync & valid_level)   begin n_state = PROPAGATE;                                           end
      SYNC     : if      (slv_ack)                                begin n_state = IDLE;      slv_error_d = 1'b0;                       end
      PROPAGATE: if      (mst_wake)                               begin n_state = SYNC;      slv_error_d = slv_error_q | mst_error;    end
      default  :                                                  begin n_state = IDLE;      slv_error_d = 1'b0;                       end
    endcase
  end

  always_comb begin: fsm_output_logic
    clear_sync_detector = 1'b0;
    clear_ack_detector  = 1'b0;
    mst_sync            = 1'b0;
    mst_ack             = 1'b0;
    slv_wake            = 1'b0;

    case (c_state)
      IDLE     : if      (slv_sync & (local_sync | ~valid_level)) begin slv_wake = 1'b1; clear_ack_detector = 1'b1;                   end
                 else if (slv_sync & ~local_sync & valid_level)   begin                                              mst_sync = 1'b1; end
      SYNC     : if      (slv_ack)                                begin slv_wake = 1'b1; clear_sync_detector = 1'b1; mst_ack = 1'b1;  end
                 else                                             begin slv_wake = 1'b1;                                              end
      PROPAGATE: if      (mst_wake)                               begin slv_wake = 1'b1; clear_ack_detector = 1'b1;                   end
    endcase
  end
  
endmodule: fractal_sync
