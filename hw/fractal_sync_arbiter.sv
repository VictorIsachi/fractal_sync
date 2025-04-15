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
 * Fractal synchronization 1D arbiter
 * Asynchronous valid low reset
 */

module fractal_sync_1d_arbiter
  import fractal_sync_pkg::*;
#(
  parameter int unsigned IN_PORTS  = 1,
  parameter int unsigned OUT_PORTS = 1,
  parameter type         arbiter_t = logic
)(
  input  logic     clk_i,
  input  logic     rst_ni,

  output logic     pop_o[IN_PORTS],
  input  logic     empty_i[IN_PORTS]
  input  arbiter_t element_i[IN_PORTS],

  output arbiter_t element_o[OUT_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_1D_ARBITER_IN_PORTS: assert (IN_PORTS > 0) else $fatal("IN_PORTS must be > 0");
  initial FRACTAL_SYNC_1D_ARBITER_OUT_PORTS: assert (OUT_PORTS > 0) else $fatal("OUT_PORTS must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned SEL_IDX_W = $clog2(IN_PORTS);

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic                req_arb[IN_PORTS];
  logic                gnt_arb[IN_PORTS];
  logic                pending_req[IN_PORTS];

  logic                c_mask[IN_PORTS];
  logic                n_mask[IN_PORTS];
  logic                clear_mask;

  logic                out_en[OUT_PORTS];
  logic[SEL_IDX_W-1:0] sel_idx[OUT_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < IN_PORTS; i++) begin: gen_req_pop
    assign req_arb[i] = ~empty_i[i];
    assign pop_o[i]   = gnt_arb[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                 Arbiter Beginning                 **/
/*******************************************************/

  always_comb begin: sel_logic
    pending_req = req_arb;
    gnt_arb     = '{default: 1'b0};
    out_en      = '{default: 1'b0};
    sel_idx     = '{default: '0};
    clear_mask  = 1'b0;
    for (int unsigned i = 0; i < OUT_PORTS; i++) begin
      for (int unsigned j = 0; j < IN_PORTS; j++) begin
        if (pending_req[j] & c_mask[j]) begin
          pending_req[j] = 1'b0;
          gnt_arb[j]     = 1'b1;
          out_en[i]      = 1'b1;
          sel_idx[i]     = j;
          break;
        end
      end
      clear_mask = 1'b1;
      for (int unsigned j = 0; j < IN_PORTS; j++) begin
        if (pending_req[j]) begin
          pending_req[j] = 1'b0;
          gnt_arb[j]     = 1'b1;
          out_en[i]      = 1'b1;
          sel_idx[i]     = j;
          break;
        end
      end
    end
  end

  always_comb begin: next_mask_logic
    for (int unsigned i = 0; i < IN_PORTS; i++) begin
      n_mask[i] = (c_mask[i] & clear_mask & gnt_arb[i]) | (~gnt_arb[i] & (c_mask[i] ^ clear_mask));
    end
  end
  
  always_ff @(posedge clk_i, negedge rst_ni) begin: current_mask_logic
    if (!rst_ni) c_mask <= '1;
    else         c_mask <= n_mask;
  end
  
  for (genvar i = 0; i < OUT_PORTS; i++) begin: gen_out_el
    assign element_o[i] = out_en[i] ? element_i[sel_idx[i]] : '{default: '0};
  end

/*******************************************************/
/**                    Arbiter End                    **/
/*******************************************************/

endmodule: fractal_sync_1d_arbiter

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
 * Fractal synchronization 2D arbiter
 * Asynchronous valid low reset
 */

module fractal_sync_2d_arbiter
  import fractal_sync_pkg::*;
#(
  parameter int unsigned IN_1D_PORTS = 1,
  parameter int unsigned IN_2D_PORTS = 1,
  parameter int unsigned OUT_PORTS   = 1,
  parameter type         arbiter_t   = logic
)(
  input  logic     clk_i,
  input  logic     rst_ni,

  output logic     h_pop_o[IN_1D_PORTS],
  input  logic     h_empty_i[IN_1D_PORTS],
  input  arbiter_t h_element_i[IN_1D_PORTS],

  output logic     v_pop_o[IN_1D_PORTS],
  input  logic     v_empty_i[IN_1D_PORTS],
  input  arbiter_t v_element_i[IN_1D_PORTS],

  output logic     pop_o[IN_2D_PORTS],
  input  logic     empty_i[IN_2D_PORTS],
  input  arbiter_t element_i[IN_2D_PORTS],

  output arbiter_t h_element_o[OUT_PORTS],
  output arbiter_t v_element_o[OUT_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_2D_ARBITER_IN_1D_PORTS: assert (IN_1D_PORTS > 0) else $fatal("IN_1D_PORTS must be > 0");
  initial FRACTAL_SYNC_2D_ARBITER_IN_2D_PORTS: assert (IN_2D_PORTS > 0) else $fatal("IN_2D_PORTS must be > 0");
  initial FRACTAL_SYNC_2D_ARBITER_IN_OUT_PORTS: assert (OUT_PORTS > 0) else $fatal("OUT_PORTS must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned IN_PORTS  = IN_2D_PORTS + IN_1D_PORTS;
  localparam int unsigned SEL_IDX_W = $clog2(IN_PORTS);

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  arbiter_t            h_element[IN_PORTS];
  arbiter_t            v_element[IN_PORTS];
  logic                h_req_arb[IN_PORTS];
  logic                v_req_arb[IN_PORTS];
  logic                h_gnt_arb[IN_PORTS];
  logic                v_gnt_arb[IN_PORTS];
  logic                h_pending_req[IN_PORTS];
  logic                v_pending_req[IN_PORTS];

  logic                h_c_mask[IN_PORTS];
  logic                v_c_mask[IN_PORTS];
  logic                h_n_mask[IN_PORTS];
  logic                v_n_mask[IN_PORTS];
  logic                h_clear_mask;
  logic                v_clear_mask;

  logic                h_out_en[OUT_PORTS];
  logic                v_out_en[OUT_PORTS];
  logic[SEL_IDX_W-1:0] h_sel_idx[OUT_PORTS];
  logic[SEL_IDX_W-1:0] v_sel_idx[OUT_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < IN_2D_PORTS; i++) begin: gen_2d_el_req_pop
    assign h_element[i] = element_i[i];
    assign v_element[i] = element_i[i];
    assign h_req_arb[i] = ~empty_i[i];
    assign v_req_arb[i] = ~empty_i[i];
    assign pop_o[i]     = h_gnt_arb[i] & v_gnt_arb[i];
  end

  for (genvar i = 0; i < IN_1D_PORTS; i++) begin: gen_1d_el_req_pop
    assign h_element[IN_2D_PORTS+i] = h_element_i[i];
    assign v_element[IN_2D_PORTS+i] = v_element_i[i];
    assign h_req_arb[IN_2D_PORTS+i] = ~h_empty_i[i];
    assign v_req_arb[IN_2D_PORTS+i] = ~v_empty_i[i];
    assign h_pop_o[i]               = h_gnt_arb[IN_2D_PORTS+i];
    assign v_pop_o[i]               = v_gnt_arb[IN_2D_PORTS+i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                 Arbiter Beginning                 **/
/*******************************************************/

  always_comb begin: sel_logic
    h_pending_req = h_req_arb;
    v_pending_req = v_req_arb;
    h_gnt_arb     = '{default: 1'b0};
    v_gnt_arb     = '{default: 1'b0};
    h_out_en      = '{default: 1'b0};
    v_out_en      = '{default: 1'b0};
    h_sel_idx     = '{default: '0};
    v_sel_idx     = '{default: '0};
    h_clear_mask  = 1'b0;
    v_clear_mask  = 1'b0;
    for (int unsigned i = 0; i < OUT_PORTS; i++) begin
      for (int unsigned j = 0; j < IN_PORTS; j++) begin
        if (h_pending_req[j] & h_c_mask[j]) begin
          h_pending_req[j] = 1'b0;
          h_gnt_arb[j]     = 1'b1;
          h_out_en[i]      = 1'b1;
          h_sel_idx[i]     = j;
          break;
        end
      end
      h_clear_mask = 1'b1;
      for (int unsigned j = 0; j < IN_PORTS; j++) begin
        if (h_pending_req[j]) begin
          h_pending_req[j] = 1'b0;
          h_gnt_arb[j]     = 1'b1;
          h_out_en[i]      = 1'b1;
          h_sel_idx[i]     = j;
          break;
        end
      end
    end
    for (int unsigned i = 0; i < OUT_PORTS; i++) begin
      for (int unsigned j = 0; j < IN_PORTS; j++) begin
        if (v_pending_req[j] & v_c_mask[j]) begin
          v_pending_req[j] = 1'b0;
          v_gnt_arb[j]     = 1'b1;
          v_out_en[i]      = 1'b1;
          v_sel_idx[i]     = j;
          break;
        end
      end
      v_clear_mask = 1'b1;
      for (int unsigned j = 0; j < IN_PORTS; j++) begin
        if (v_pending_req[j]) begin
          v_pending_req[j] = 1'b0;
          v_gnt_arb[j]     = 1'b1;
          v_out_en[i]      = 1'b1;
          v_sel_idx[i]     = j;
          break;
        end
      end
    end
  end

  always_comb begin: next_mask_logic
    for (int unsigned i = 0; i < IN_PORTS; i++) begin
      h_n_mask[i] = (h_c_mask[i] & h_clear_mask & h_gnt_arb[i]) | (~h_gnt_arb[i] & (h_c_mask[i] ^ h_clear_mask));
      v_n_mask[i] = (v_c_mask[i] & v_clear_mask & v_gnt_arb[i]) | (~v_gnt_arb[i] & (v_c_mask[i] ^ v_clear_mask));
    end
  end
  
  always_ff @(posedge clk_i, negedge rst_ni) begin: current_mask_logic
    if (!rst_ni) begin 
      h_c_mask <= '1;
      v_c_mask <= '1;
    end else begin 
      h_c_mask <= h_n_mask;
      v_c_mask <= v_n_mask;
    end
  end
  
  for (genvar i = 0; i < OUT_PORTS; i++) begin: gen_out_el
    assign h_element_o[i] = h_out_en[i] ? h_element[h_sel_idx[i]] : '{default: '0};
    assign v_element_o[i] = v_out_en[i] ? v_element[v_sel_idx[i]] : '{default: '0};
  end

/*******************************************************/
/**                    Arbiter End                    **/
/*******************************************************/

endmodule: fractal_sync_2d_arbiter