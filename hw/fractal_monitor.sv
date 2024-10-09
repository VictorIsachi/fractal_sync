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
 * Fractal synchronization tree node monitor
 * Asynchronous valid low reset
 *
 * Parameters:
 *  PORT_WIDTH - LVL_WIDTH of master ports
 *
 * Interface signals:
 *  Ports to be monitored - usually master ports of the top node of the synchronization tree
 *  > error_o             - error detected
 *
 * WARRNING: Proper measures for error detection and handling must be implemented
 */

module fractal_monitor #(
  parameter int unsigned PORT_WIDTH = 0,
  localparam int unsigned N_PORTS   = 1
)(
  input  logic        clk_i,
  input  logic        rstn_i,
  fractal_if.slv_port ports  [N_PORTS],
  output logic        error_o[N_PORTS]
);
  
  typedef enum logic[1:0] {
    IDLE,
    SYNC,
    ACK
  } monitor_state_e;

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_port_monitor
    monitor_state_e c_state, n_state;

    always_ff @(posedge clk_i, negedge rstn_i) begin: state_register
      if (!rstn_i) c_state <= IDLE;
      else         c_state <= n_state;
    end

    always_comb begin: state_output_logic
      unique case (c_state)
        IDLE   : begin
          ports[i].wake              = 1'b0;
          ports[i].error             = 1'b0;
          if (ports[i].sync) n_state = SYNC;
          else               n_state = IDLE;
        end
        SYNC   : begin
          ports[i].wake              = 1'b1;
          ports[i].error             = 1'b1;
          n_state                    = ACK;
        end
        ACK    : begin
          ports[i].wake              = 1'b1;
          ports[i].error             = 1'b1;
          if (ports[i].ack) n_state  = IDLE;
          else              n_state  = ACK;
        end
        default: begin
          ports[i].wake              = 1'b0;
          ports[i].error             = 1'b0;
          n_state                    = IDLE;
        end
      endcase
    end

    assign error_o[i] = ports[i].error;
  end
  
endmodule: fractal_monitor
