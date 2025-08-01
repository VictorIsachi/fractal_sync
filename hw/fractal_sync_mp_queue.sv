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
 * Fractal synchronization multi-port FIFO queue register: synch. multi-port push; synch. single-port pop and ready
 * Asynchronous valid low reset
 *
 * Parameters:
 *  DEPTH     - Depth of the queue
 *  element_t - Element type to be stored in the queue
 *  N_PORTS   - Number of ports
 *  COMB_OUT  - Combinational output based on input (fall-through) FIFO
 *
 * Interface signals:
 *  > push_i           - Push elements into the FIFO
 *  > pop_i            - Pop element from the FIFO
 *  > element_i        - Elements to be pushed into the FIFO
 *  < ready_o          - Indicates that the register granted exclusive access
 *  < element_o        - Indicates element which has been granted exlusive access
 *  < overflow_error_o - Indicates FIFO overflow error
 */

module fractal_sync_mp_queue_reg
  import fractal_sync_pkg::*;
#(
  parameter int unsigned DEPTH     = 1,
  parameter type         element_t = logic,
  parameter int unsigned N_PORTS   = 2,
  parameter bit          COMB_OUT  = 1'b1
)(
  input  logic     clk_i,
  input  logic     rst_ni,

  input  logic     push_i[N_PORTS],
  input  logic     pop_i,
  input  element_t element_i[N_PORTS],
  output logic     ready_o,
  output element_t element_o,
  output logic     overflow_error_o
);

/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  typedef enum logic[1:0] {
    FREE,
    FREE_GRANT,
    LOCKED,
    LOCKED_GRANT
  } state_e;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic lock_req;
  logic en_push;

  logic push_fifo[N_PORTS];
  logic pop_fifo;
  logic empty_fifo;
  logic full_fifo;

  state_e c_state, n_state;

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  always_comb begin: lock_req_logic
    lock_req = 1'b0;
    for (int unsigned i = 0; i < N_PORTS; i++)
      lock_req |= push_i[i];
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_push
    assign push_fifo[i] = push_i[i] & en_push;
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**                   FIFO Beginning                  **/
/*******************************************************/

  fractal_sync_mp_fifo #(
    .FIFO_DEPTH ( DEPTH     ),
    .fifo_t     ( element_t ),
    .COMB_OUT   ( COMB_OUT  ),
    .N_PORTS    ( N_PORTS   )
  ) i_queue (
    .clk_i                          ,
    .rst_ni                         ,
    .push_i     ( push_fifo        ),
    .element_i  ( element_i        ),
    .pop_i      ( pop_fifo         ),
    .element_o  ( element_o        ),
    .empty_o    ( empty_fifo       ),
    .full_o     ( full_fifo        ),
    .overflow_o ( overflow_error_o ),
    .avail_o    (                  )
  );

/*******************************************************/
/**                      FIFO End                     **/
/*******************************************************/
/**               Control FSM Beginning               **/
/*******************************************************/

  always_ff @(posedge clk_i, negedge rst_ni) begin: state_register
    if (!rst_ni) c_state <= FREE;
    else         c_state <= n_state;
  end

  always_comb begin: state_and_output_logic
    n_state  = c_state;
    en_push  = 1'b0;
    pop_fifo = 1'b0;
    ready_o  = 1'b0;
    unique case (c_state)
      FREE: begin
        if (lock_req) begin
          n_state = FREE_GRANT;
          en_push = 1'b1;
        end
      end
      FREE_GRANT: begin
        ready_o = 1'b1;
        if (pop_i) begin
          n_state  = FREE;
          pop_fifo = 1'b1;
        end else begin
          n_state = LOCKED;
          en_push = lock_req;
        end
      end
      LOCKED: begin
        if (empty_fifo) begin
          n_state = FREE;
        end else begin
          en_push = lock_req;
          if (pop_i) begin
            n_state  = LOCKED_GRANT;
            pop_fifo = 1'b1;
          end
        end
      end  
      LOCKED_GRANT: begin
        ready_o = 1'b1;
        if (empty_fifo) begin
          n_state = FREE;
        end else begin
          en_push = lock_req;
          if (!pop_i) begin
            n_state = LOCKED;
          end else begin
            pop_fifo = 1'b1;
          end
        end
      end
    endcase
  end

/*******************************************************/
/**                  Control FSM End                  **/
/*******************************************************/

endmodule: fractal_sync_mp_queue_reg

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
 * Fractal synchronization multi-port FIFO queue: synch. multi-port lock/free and grant
 * Asynchronous valid low reset
 *
 * Parameters:
 *  N_REGS    - Number of registers in the register file
 *  REG_DEPTH - Queue depth of each register
 *  IDX_WIDTH - Width of the selected register; width must be large enough to be able to select all registers in the RF
 *  element_t - Queue element (aggregate) type
 *  COMB_OUT  - Combinational output based on input (fall-through) FIFO
 *  N_PORTS   - Number of ports
 *
 * Interface signals:
 *  > lock_i           - Request lock of the register at selected index
 *  > free_i           - Request free of the register at selected index
 *  > element_i        - Aggregate pattern of the lock/free request
 *  > idx_i            - Register index
 *  > idx_valid_i      - Indicates that the selected index is valid
 *  < grant_o          - Indicates that the register at selected index is granting exclusive access
 *  < element_o        - Indicates the aggregate pattern of the granted request
 *  < overflow_error_o - Indicates FIFO overflow error
 */

module fractal_sync_mp_queue
  import fractal_sync_pkg::*;
#(
  parameter int unsigned N_REGS    = 1,
  parameter int unsigned REG_DEPTH = 1,
  parameter int unsigned IDX_WIDTH = 1,
  parameter type         element_t = logic,
  parameter bit          COMB_OUT  = 1'b1,
  parameter int unsigned N_PORTS   = 2
)(
  input  logic                clk_i,
  input  logic                rst_ni,

  input  logic                lock_i[N_PORTS],
  input  logic                free_i[N_PORTS],
  input  element_t            element_i[N_PORTS],
  input  logic[IDX_WIDTH-1:0] idx_i[N_PORTS],
  input  logic                idx_valid_i[N_PORTS],
  output logic                grant_o[N_PORTS],
  output element_t            element_o[N_PORTS],
  output logic                overflow_error_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_MP_QUEUE: assert (2**IDX_WIDTH >= N_REGS) else $fatal("IDX_WIDTH must be able to index all N_REGS registers");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned REG_IDX_WIDTH = N_REGS > 1 ? $clog2(N_REGS) : 1;
  
/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[REG_IDX_WIDTH-1:0] reg_idx[N_PORTS];

  logic lock_queue[N_REGS][N_PORTS];
  logic free_queue[N_REGS];

  logic     grant_queue[N_REGS][N_PORTS];
  element_t granted_element[N_REGS];

  logic overflow_error[N_REGS][N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_reg_idx
    assign reg_idx[i] = idx_i[i][REG_IDX_WIDTH-1:0];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**             Multi-Port Queue Beginning            **/
/*******************************************************/
  
  for (genvar i = 0; i < N_REGS; i++) begin: gen_queue_reg
    fractal_sync_mp_queue_reg #(
      .DEPTH     ( REG_DEPTH ),
      .element_t ( element_t ),
      .N_PORTS   ( N_PORTS   ),
      .COMB_OUT  ( COMB_OUT  )
    ) i_fractal_sync_mp_queue_reg (
      .clk_i                                  ,
      .rst_ni                                 ,
      .push_i           ( lock_queue[i]      ),
      .pop_i            ( free_queue[i]      ),
      .element_i        ( element_i          ),
      .ready_o          ( grant_queue[i]     ),
      .element_o        ( granted_element[i] ),
      .overflow_error_o ( overflow_error[i]  )
    );
  end
  
  for (genvar i = 0; i < N_REGS; i++) begin: gen_lock_free
    always_comb begin
      lock_queue[i] = '{default: '0};
      free_queue[i] = 1'b0;
      for (int unsigned j = 0; j < N_PORTS; j++) begin
        lock_queue[i][j] = lock_i[j] && (reg_idx[j] == i) ? 1'b1 : 1'b0;
        free_queue[i]   |= free_i[j] && (reg_idx[j] == i) ? 1'b1 : 1'b0;
      end
    end
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_grant_element
    always_comb begin
      grant_o[i]   = 1'b0;
      element_o[i] = '0;
      for (int unsigned j = 0; j < N_REGS; j++) begin
        if (grant_queue[j][i] == 1'b1) begin
          grant_o[i]          = 1'b1;
          element_o[i]        = granted_element[j];
          overflow_error_o[i] = overflow_error[j][i];
          break;
        end
      end
    end
  end

/*******************************************************/
/**                Multi-Port Queue End               **/
/*******************************************************/

endmodule: fractal_sync_mp_queue