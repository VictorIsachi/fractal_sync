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
 * Fractal synchronization fully-associative arbiter
 * Asynchronous valid low reset
 *
 * Parameters:
 *  IN_PORTS  - Number of input ports
 *  OUT_PORTS - Number of output ports
 *  arbiter_t - Arbiter element type
 *
 * Interface signals:
 *  < pop_o     - Pop input element
 *  > empty_i   - Indicates empty input FIFO
 *  > element_i - Input element
 *  < element_o - Output element
 */

module fractal_sync_arbiter_fa
  import fractal_sync_pkg::*;
#(
  parameter int unsigned IN_PORTS  = 1,
  parameter int unsigned OUT_PORTS = 1,
  parameter type         arbiter_t = logic
)(
  input  logic     clk_i,
  input  logic     rst_ni,

  output logic     pop_o[IN_PORTS],
  input  logic     empty_i[IN_PORTS],
  input  arbiter_t element_i[IN_PORTS],

  output arbiter_t element_o[OUT_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

`ifndef SYNTHESIS
  initial FRACTAL_SYNC_ARBITER_IN_PORTS: assert (IN_PORTS > 0) else $fatal("IN_PORTS must be > 0");
  initial FRACTAL_SYNC_ARBITER_OUT_PORTS: assert (OUT_PORTS > 0) else $fatal("OUT_PORTS must be > 0");
`endif /* SYNTHESIS */

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
      if (out_en[i]) continue;
      else begin
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
  end

  always_comb begin: next_mask_logic
    for (int unsigned i = 0; i < IN_PORTS; i++)
      n_mask[i] = (c_mask[i] & clear_mask & gnt_arb[i]) | (~gnt_arb[i] & (c_mask[i] | clear_mask));
  end
  
  always_ff @(posedge clk_i, negedge rst_ni) begin: current_mask_logic
    if (!rst_ni) c_mask <= '{default: 1'b1};
    else         c_mask <= n_mask;
  end
  
  for (genvar i = 0; i < OUT_PORTS; i++) begin: gen_out_el
    assign element_o[i] = out_en[i] ? element_i[sel_idx[i]] : '{default: '0};
  end

/*******************************************************/
/**                    Arbiter End                    **/
/*******************************************************/

endmodule: fractal_sync_arbiter_fa

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
 * Fractal synchronization arbiter
 * Asynchronous valid low reset
 *
 * Parameters:
 *  IN_PORTS     - Number of input ports
 *  OUT_PORTS    - Number of output ports
 *  arbiter_t    - Arbiter element type
 *  ARBITER_TYPE - Arbiter type (Fully Associative or Directly Mapped wrap-around/alternating order)
 *
 * Interface signals:
 *  < pop_o     - Pop input element
 *  > empty_i   - Indicates empty input FIFO
 *  > element_i - Input element
 *  < element_o - Output element
 */

module fractal_sync_arbiter
  import fractal_sync_pkg::*;
#(
  parameter int unsigned            IN_PORTS     = 1,
  parameter int unsigned            OUT_PORTS    = 1,
  parameter type                    arbiter_t    = logic,
  parameter fractal_sync_pkg::arb_e ARBITER_TYPE = fractal_sync_pkg::FA_ARB
)(
  input  logic     clk_i,
  input  logic     rst_ni,

  output logic     pop_o[IN_PORTS],
  input  logic     empty_i[IN_PORTS],
  input  arbiter_t element_i[IN_PORTS],

  output arbiter_t element_o[OUT_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

`ifndef SYNTHESIS
  initial FRACTAL_SYNC_ARBITER_IN_PORTS: assert (IN_PORTS > 0) else $fatal("IN_PORTS must be > 0");
  initial FRACTAL_SYNC_ARBITER_OUT_PORTS: assert (OUT_PORTS > 0) else $fatal("OUT_PORTS must be > 0");
`endif /* SYNTHESIS */

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned ODD_MAPPING       = OUT_PORTS%IN_PORTS ? (OUT_PORTS/IN_PORTS)%2 : 0;
  localparam int unsigned N_LEFTOVER_ARB    = IN_PORTS%OUT_PORTS;
  localparam int unsigned N_LEFTOVER_PORTS  = IN_PORTS/OUT_PORTS+1;
  localparam int unsigned N_LEFTOVERN_PORTS = IN_PORTS/OUT_PORTS;

  localparam int unsigned OUTPUT_PORTS = 1;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**                 Arbiter Beginning                 **/
/*******************************************************/

  if (ARBITER_TYPE == fractal_sync_pkg::FA_ARB) begin: gen_fa_arbiter
    fractal_sync_arbiter_fa #(
      .IN_PORTS  ( IN_PORTS  ),
      .OUT_PORTS ( OUT_PORTS ),
      .arbiter_t ( arbiter_t )
    ) i_fractal_sync_arbiter (.*);
  end else if (ARBITER_TYPE == fractal_sync_pkg::DM_WA_ARB) begin: gen_dm_wa_arbiter
    for (genvar i = 0; i < OUT_PORTS; i++) begin: gen_port_arbiters
      localparam int unsigned INPUT_PORTS  = (i <  N_LEFTOVER_ARB) ? N_LEFTOVER_PORTS : N_LEFTOVERN_PORTS;
      
      logic     pop_out[INPUT_PORTS];
      logic     empty_in[INPUT_PORTS];
      arbiter_t element_in[INPUT_PORTS];
      arbiter_t element_out[OUTPUT_PORTS];

      assign element_o[i] = element_out[0]; // Single output port

      fractal_sync_arbiter_fa #(
        .IN_PORTS  ( INPUT_PORTS  ),
        .OUT_PORTS ( OUTPUT_PORTS ),
        .arbiter_t ( arbiter_t    )
      ) i_fractal_sync_port_arbiter (
        .clk_i                    ,
        .rst_ni                   ,
        .pop_o     ( pop_out     ),
        .empty_i   ( empty_in    ),
        .element_i ( element_in  ),
        .element_o ( element_out )
      );
    end

    for (genvar i = 0; i < IN_PORTS; i++) begin: gen_port_mapping
      localparam int unsigned PORT_IDX = i/OUT_PORTS;
      assign pop_o[i]                                            = gen_port_arbiters[i%OUT_PORTS].pop_out[PORT_IDX];
      assign gen_port_arbiters[i%OUT_PORTS].empty_in[PORT_IDX]   = empty_i[i];
      assign gen_port_arbiters[i%OUT_PORTS].element_in[PORT_IDX] = element_i[i];
    end
  end else if (ARBITER_TYPE == fractal_sync_pkg::DM_ALT_ARB) begin: gen_dm_alt_arbiter
    for (genvar i = 0; i < OUT_PORTS; i++) begin: gen_port_arbiters
      localparam int unsigned INPUT_PORTS  = ODD_MAPPING ? 
                                             (i >= N_LEFTOVER_ARB ? N_LEFTOVER_PORTS : N_LEFTOVERN_PORTS) :
                                             (i <  N_LEFTOVER_ARB ? N_LEFTOVER_PORTS : N_LEFTOVERN_PORTS);
      
      logic     pop_out[INPUT_PORTS];
      logic     empty_in[INPUT_PORTS];
      arbiter_t element_in[INPUT_PORTS];
      arbiter_t element_out[OUTPUT_PORTS];

      assign element_o[i] = element_out[0]; // Single output port

      fractal_sync_arbiter_fa #(
        .IN_PORTS  ( INPUT_PORTS  ),
        .OUT_PORTS ( OUTPUT_PORTS ),
        .arbiter_t ( arbiter_t    )
      ) i_fractal_sync_port_arbiter (
        .clk_i                    ,
        .rst_ni                   ,
        .pop_o     ( pop_out     ),
        .empty_i   ( empty_in    ),
        .element_i ( element_in  ),
        .element_o ( element_out )
      );
    end

    for (genvar i = 0; i < IN_PORTS; i++) begin: gen_port_mapping
      localparam int unsigned PORT_IDX    = i/OUT_PORTS;
      localparam int unsigned MAPPING_DIR = PORT_IDX%2;
      if (MAPPING_DIR == 0) begin
        assign pop_o[i]                                            = gen_port_arbiters[i%OUT_PORTS].pop_out[PORT_IDX];
        assign gen_port_arbiters[i%OUT_PORTS].empty_in[PORT_IDX]   = empty_i[i];
        assign gen_port_arbiters[i%OUT_PORTS].element_in[PORT_IDX] = element_i[i];
      end else begin
        assign pop_o[i]                                                            = gen_port_arbiters[OUT_PORTS-1 - (i%OUT_PORTS)].pop_out[PORT_IDX];
        assign gen_port_arbiters[OUT_PORTS-1 - (i%OUT_PORTS)].empty_in[PORT_IDX]   = empty_i[i];
        assign gen_port_arbiters[OUT_PORTS-1 - (i%OUT_PORTS)].element_in[PORT_IDX] = element_i[i];
      end
    end
  end
`ifndef SYNTHESIS
  else $fatal("Unsupported Arbiter Type");
`endif /* SYNTHESIS */

/*******************************************************/
/**                    Arbiter End                    **/
/*******************************************************/

endmodule: fractal_sync_arbiter