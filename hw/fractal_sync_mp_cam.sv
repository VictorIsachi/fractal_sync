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
 * Fractal synchronization multi-port CAM line: synch. single-port write; asynch. multi-port present
 * Asynchronous valid low reset
 *
 * Parameters:
 *  SIG_WIDTH - Width of signature to be stored in CAM line
 *  N_PORTS   - Number of ports
 *
 * Interface signals:
 *  > we_i      - Write (synchronous) enable
 *  > free_i    - Free line (synchronous): write has precedence over free
 *  > idx_i     - Index of the port whose signature will be written
 *  > sig_i     - Signature
 *  < full_o    - Indicates that line is full
 *  < present_o - Indicates which ports have the signature present in the CAM line (asynchronous)
 */

module fractal_sync_mp_cam_line
  import fractal_sync_pkg::*;
#(
  parameter int unsigned  SIG_WIDTH   = 1,
  parameter int unsigned  N_PORTS     = 2,
  localparam int unsigned W_IDX_WIDTH = $clog2(N_PORTS)
)(
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  logic                  we_i,
  input  logic                  free_i,
  input  logic[W_IDX_WIDTH-1:0] idx_i,
  input  logic[SIG_WIDTH-1:0]   sig_i[N_PORTS],
  output logic                  full_o,
  output logic                  present_o[N_PORTS]
);

/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[SIG_WIDTH-1:0] sig;
  logic[SIG_WIDTH-1:0] sig_bit_eql[N_PORTS];
  logic                sig_eql[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                 CAM Line Beginning                **/
/*******************************************************/

  always_ff @(posedge clk_i, negedge rst_ni) begin: full_reg
    if (!rst_ni)       full_o <= 1'b0;
    else begin
      if      (we_i)   full_o <= 1'b1;
      else if (free_i) full_o <= 1'b0;
    end
  end
 
  always_ff @(posedge clk_i, negedge rst_ni) begin: sig_regs
    if      (!rst_ni) sig <= '0;
    else if (we_i)    sig <= sig_i[idx_i];
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_present_logic
    assign sig_bit_eql[i] = sig ~^ sig_i[i];
    assign sig_eql[i]     = &sig_bit_eql[i];
    assign present_o[i]   = sig_eql[i] & full_o;
  end

/*******************************************************/
/**                    CAM Line End                   **/
/*******************************************************/

endmodule: fractal_sync_mp_cam_line

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
 * Fractal synchronization multi-port CAM: synch. check; asynch. present
 * Asynchronous valid low reset
 *
 * Parameters:
 *  N_LINES   - Number of CAM lines in the register file
 *  SIG_WIDTH - Width of the signature
 *  N_PORTS   - Number of ports
 *
 * Interface signals:
 *  > check_i     - Check (synchronous) the signature (function of level and barrier id) and update CAM accordingly (present AND valid => clear; NOT(present) AND valid => set)
 *  > set_i       - Set (synchronous) the signature (valid => set); set_i has lower priority than check_i
 *  > sig_i       - Signature
 *  > sig_valid_i - Indicates that the signature is valid
 *  < present_o   - Indicates whether signature is present (asynchronous)
 */

module fractal_sync_mp_cam
  import fractal_sync_pkg::*;
#(
  parameter int unsigned N_LINES   = 1,
  parameter int unsigned SIG_WIDTH = 1,
  parameter int unsigned N_PORTS   = 2
)(
  input  logic                clk_i,
  input  logic                rst_ni,

  input  logic                check_i[N_PORTS],
  input  logic                set_i[N_PORTS],
  input  logic[SIG_WIDTH-1:0] sig_i[N_PORTS],
  input  logic                sig_valid_i[N_PORTS],
  output logic                present_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_MP_CAM: assert (N_LINES >= N_PORTS/2) else $fatal("N_LINES must be >= N_PORTS/2");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned W_IDX_WIDTH = $clog2(N_PORTS);
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic                  write_line[N_LINES];
  logic                  free_line[N_LINES];
  logic[W_IDX_WIDTH-1:0] line_idx[N_LINES];

  logic line_full[N_LINES];
  logic line_present[N_LINES][N_PORTS];

  logic store[N_PORTS];
  logic store_masked[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                   CAM Beginning                   **/
/*******************************************************/
  
  for (genvar i = 0; i < N_LINES; i++) begin: gen_cam_line
    fractal_sync_mp_cam_line #(
      .SIG_WIDTH ( SIG_WIDTH ),
      .N_PORTS   ( N_PORTS   )
    ) i_fractal_sync_mp_cam_line (
      .clk_i                        ,
      .rst_ni                       ,
      .we_i      ( write_line[i]   ),
      .free_i    ( free_line[i]    ),
      .idx_i     ( line_idx[i]     ),
      .sig_i                        ,
      .full_o    ( line_full[i]    ),
      .present_o ( line_present[i] )
    );
  end

  always_comb begin: present_free_store_logic
    present_o = '{default: 1'b0};
    free_line = '{default: 1'b0};
    for (int unsigned i = 0; i < N_PORTS; i++) begin
      store[i] = check_i[i] | set_i[i];
      for (int unsigned j = 0; j < N_LINES; j++) begin
        if (line_present[j][i] & sig_valid_i[i]) begin
          present_o[i] = 1'b1;
          if      (check_i[i]) begin free_line[j] = 1'b1; store[i] = 1'b0; end
          else if (set_i[i])   begin                      store[i] = 1'b0; end
        end
      end
    end
  end

  always_comb begin: write_line_logic
    write_line   = '{default: 1'b0};
    line_idx     = '{default: '0};
    store_masked = store;
    for (int unsigned i = 0; i < N_LINES; i++) begin
      for (int unsigned j = 0; j < N_PORTS; j++) begin
        if (store_masked[j] & sig_valid_i[j] & (~line_full[i] | free_line[i])) begin
          write_line[i]   = 1'b1;
          line_idx[i]     = j;
          store_masked[j] = 1'b0;
          break;
        end
      end
    end
  end

/*******************************************************/
/**                      CAM End                      **/
/*******************************************************/

endmodule: fractal_sync_mp_cam

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
 * Fractal synchronization multi-port CAM with back-routing registers: synch. check; asynch. present
 * Asynchronous valid low reset
 *
 * Parameters:
 *  N_LINES   - Number of CAM lines in the register file
 *  SIG_WIDTH - Width of the signature
 *  N_PORTS   - Number of ports
 *
 * Interface signals:
 *  > check_i     - Check (synchronous) the signature (function of level and barrier id) and update CAM accordingly (present AND valid => clear; NOT(present) AND valid => set)
 *  > set_i       - Set (synchronous) the signature (valid => set); set_i has lower priority than check_i
 *  > sd_i        - Source/destination ports of the synchronization transaction to be stored for back-routing
 *  > sig_i       - Signature
 *  > sig_valid_i - Indicates that the signature is valid
 *  < present_o   - Indicates whether signature is present (asynchronous)
 *  < sd_o        - Source/destination ports of the synchronization transaction stored: sticky, will remember all ports
 */

module fractal_sync_mp_cam_br
  import fractal_sync_pkg::*;
#(
  parameter int unsigned  N_LINES   = 1,
  parameter int unsigned  SIG_WIDTH = 1,
  localparam int unsigned SD_WIDTH  = fractal_sync_pkg::SD_WIDTH,
  parameter int unsigned  N_PORTS   = 2
)(
  input  logic                clk_i,
  input  logic                rst_ni,

  input  logic                check_i[N_PORTS],
  input  logic                set_i[N_PORTS],
  input  logic[SD_WIDTH-1:0]  sd_i[N_PORTS],
  input  logic[SIG_WIDTH-1:0] sig_i[N_PORTS],
  input  logic                sig_valid_i[N_PORTS],
  output logic                present_o[N_PORTS],
  output logic[SD_WIDTH-1:0]  sd_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_MP_CAM: assert (N_LINES >= N_PORTS/2) else $fatal("N_LINES must be >= N_PORTS/2");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned W_IDX_WIDTH = $clog2(N_PORTS);
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/
  
  logic                  write_line[N_LINES];
  logic                  free_line[N_LINES];
  logic[W_IDX_WIDTH-1:0] line_idx[N_LINES];

  logic line_full[N_LINES];
  logic line_present[N_LINES][N_PORTS];

  logic store[N_PORTS];
  logic store_masked[N_PORTS];

  logic update_line[N_LINES];

  logic[SD_WIDTH-1:0] sd_reg_d[N_LINES];
  logic[SD_WIDTH-1:0] sd_reg_q[N_LINES];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**                   CAM Beginning                   **/
/*******************************************************/
  
  for (genvar i = 0; i < N_LINES; i++) begin: gen_cam_line
    fractal_sync_mp_cam_line #(
      .SIG_WIDTH ( SIG_WIDTH ),
      .N_PORTS   ( N_PORTS   )
    ) i_fractal_sync_mp_cam_line (
      .clk_i                        ,
      .rst_ni                       ,
      .we_i      ( write_line[i]   ),
      .free_i    ( free_line[i]    ),
      .idx_i     ( line_idx[i]     ),
      .sig_i                        ,
      .full_o    ( line_full[i]    ),
      .present_o ( line_present[i] )
    );
  end

  always_comb begin: present_sd_free_update_store_logic
    present_o   = '{default: 1'b0};
    sd_o        = '{default: '0};
    free_line   = '{default: 1'b0};
    update_line = '{default: 1'b0};
    for (int unsigned i = 0; i < N_PORTS; i++) begin
      store[i] = check_i[i] | set_i[i];
      for (int unsigned j = 0; j < N_LINES; j++) begin
        if (line_present[j][i] & sig_valid_i[i]) begin
          present_o[i] = 1'b1;
          sd_o[i]      = sd_reg_q[j];
          if      (check_i[i]) begin free_line[j] = 1'b1; store[i] = 1'b0;                        end
          else if (set_i[i])   begin                      store[i] = 1'b0; update_line[j] = 1'b1; end
        end
      end
    end
  end

  always_comb begin: write_line_sd_logic
    write_line   = '{default: 1'b0};
    line_idx     = '{default: '0};
    sd_reg_d     = sd_reg_q;
    store_masked = store;
    for (int unsigned i = 0; i < N_LINES; i++) begin
      for (int unsigned j = 0; j < N_PORTS; j++) begin
        if (sig_valid_i[j]) begin
          if (store_masked[j] & (~line_full[i] | free_line[i])) begin
            write_line[i]   = 1'b1;
            line_idx[i]     = j;
            store_masked[j] = 1'b0;
            sd_reg_d[i]     = sd_i[j];
            break;
          end else if (update_line[i] & line_present[i][j] & set_i[j]) begin
            sd_reg_d[i]     = sd_reg_q[i] | sd_i[j];
            break;
          end
        end
      end
    end
  end

  for (genvar i = 0; i < N_LINES; i++) begin: gen_sd_regs
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni)        sd_reg_q[i] <= '0;         
      else
        if (free_line[i]) sd_reg_q[i] <= '0;
        else              sd_reg_q[i] <= sd_reg_d[i];
    end
  end

/*******************************************************/
/**                      CAM End                      **/
/*******************************************************/

endmodule: fractal_sync_mp_cam_br