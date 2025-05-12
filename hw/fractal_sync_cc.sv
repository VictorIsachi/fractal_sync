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
 * Fractal synchronization core control
 * Asynchronous valid low reset
 *
 * Parameters:
 *  NODE_TYPE       - Node type of control core (horizontal, vertical, 2D, root)
 *  RF_TYPE         - Remote RF type (Directly Mapped or CAM)
 *  N_LOCAL_REGS    - Number of register in teh local RF
 *  N_REMOTE_LINES  - Number of CAM lines in a CAM-based remote RF
 *  AGGREGATE_WIDTH - Width of the aggr field
 *  ID_WIDTH        - Width of the id field
 *  fsync_req_in_t  - Input synchronization request type (RX -> CC)
 *  fsync_rsp_in_t  - Input synchronization response type (CC -> TX arb.)
 *  fsync_req_out_t - Output synchronization request type (CC -> RX arb.)
 *  N_RX_PORTS      - Number of input (RX) ports
 *  N_TX_PORTS      - Number of output (TX) ports
 *  FIFO_DEPTH      - Maximum number of elements that can be present in a FIFO
 *
 * Interface signals:
 *  > req_i               - Synchronization request (input)
 *  > local_i             - Indicates that synch. req. should be managed by current node (root or aggregate)
 *  > root_i              - Indicates that synch. req. has reached the root of the synchronization tree
 *  > error_overflow_rx_i - Indicates RX FIFO overflow
 *  > error_overflow_tx_i - Indicates TX FIFO overflow
 *  > local_empty_o       - Indicates that local FIFO (associated with local RF) is empty
 *  > local_rsp_o         - Local synchronization response (input) FIFO
 *  > local_pop_i         - Pop synch. rsp.
 *  > remote_empty_o      - Indicates that remote FIFO (associated with remote RF) is empty
 *  > remote_req_o        - Remote synch. req. (output) FIFO
 *  > remote_pop_i        - Pop synch. req.
 *  > detected_error_o    - Detected error associated with RX/TX transaction
 */

module fractal_sync_cc 
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::node_e      NODE_TYPE       = fractal_sync_pkg::HV_NODE,
  localparam fractal_sync_pkg::rf_dim_e   RF_DIM          = (NODE_TYPE == fractal_sync_pkg::HV_NODE) ||
                                                            (NODE_TYPE == fractal_sync_pkg::RT_NODE) ? 
                                                            fractal_sync_pkg::RF2D : fractal_sync_pkg::RF1D,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE         = fractal_sync_pkg::CAM_RF,
  parameter int unsigned                  N_LOCAL_REGS    = 0,
  parameter int unsigned                  N_REMOTE_LINES  = 0,
  parameter int unsigned                  AGGREGATE_WIDTH = 1,
  parameter int unsigned                  ID_WIDTH        = 1,
  parameter type                          fsync_req_in_t  = logic,
  parameter type                          fsync_rsp_in_t  = logic,
  parameter type                          fsync_req_out_t = logic,
  // 2D CC: even indexed ports -> horizontal channel; odd indexed ports -> vertical channel
  parameter int unsigned                  N_RX_PORTS      = (RF_DIM == fractal_sync_pkg::RF2D) ? 4 : 
                                                            (RF_DIM == fractal_sync_pkg::RF1D) ? 2 :
                                                            0,
  // 2D CC: even indexed ports -> horizontal channel; odd indexed ports -> vertical channel
  parameter int unsigned                  N_TX_PORTS      = (RF_DIM == fractal_sync_pkg::RF2D) ? 2 : 
                                                            (RF_DIM == fractal_sync_pkg::RF1D) ? 1 :
                                                            0,
  // Total number of ports: lower indexes represent RX ports; higher indexes represent TX ports
  localparam int unsigned                 N_PORTS         = N_RX_PORTS + N_TX_PORTS,
  // 2D CC: even indexed FIFOs -> horizontal channel; odd indexed FIFOs -> vertical channel
  localparam int unsigned                 N_FIFOS         = N_RX_PORTS, 
  parameter int unsigned                  FIFO_DEPTH      = 1
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_req_in_t  req_i[N_RX_PORTS],
  input  logic           local_i[N_RX_PORTS],
  input  logic           root_i[N_RX_PORTS],
  input  logic           error_overflow_rx_i[N_RX_PORTS],
  input  logic           error_overflow_tx_i[N_TX_PORTS],

  output logic           local_empty_o[N_FIFOS],
  output fsync_rsp_in_t  local_rsp_o[N_FIFOS],
  input  logic           local_pop_i[N_FIFOS],

  output logic           remote_empty_o[N_FIFOS],
  output fsync_req_out_t remote_req_o[N_FIFOS],
  input  logic           remote_pop_i[N_FIFOS],

  output logic           detected_error_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_CC_LOCAL_REGS: assert (N_LOCAL_REGS > 0) else $fatal("N_LOCAL_REGS must be > 0");
  initial FRACTAL_SYNC_CC_REMOTE_LINES: assert (RF_TYPE == fractal_sync_pkg::CAM_RF -> N_REMOTE_LINES > 0) else $fatal("N_REMOTE_LINES must be > 0 for CAM Remote Register File");
  initial FRACTAL_SYNC_CC_AGGR_W: assert (AGGREGATE_WIDTH > 0) else $fatal("AGGREGATE_WIDTH must be > 0");
  initial FRACTAL_SYNC_CC_ID_W: assert (ID_WIDTH > 0) else $fatal("ID_WIDTH must be > 0");
  initial FRACTAL_SYNC_CC_DST: assert ($bits(req_i[0].src) == $bits(remote_req_o[0].src)-2) else $fatal("Output sources width must be 2 bits more than input destination");
  initial FRACTAL_SYNC_CC_SRC: assert ($bits(req_i[0].src) == $bits(local_rsp_o[0].dst)) else $fatal("Output destination width must be equal to input sources");
  initial FRACTAL_SYNC_CC_RX_PORTS: assert (N_RX_PORTS > 0) else $fatal("N_RX_PORTS must be > 0");
  initial FRACTAL_SYNC_CC_TX_PORTS: assert (N_TX_PORTS > 0) else $fatal("N_TX_PORTS must be > 0");
  initial FRACTAL_SYNC_CC_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam fractal_sync_pkg::en_remote_rf_e EN_REMOTE_RF  = (NODE_TYPE == fractal_sync_pkg::RT_NODE) ? fractal_sync_pkg::ENN_REMOTE_RF : fractal_sync_pkg::EN_REMOTE_RF;
  localparam int unsigned                     LEVEL_WIDTH   = $clog2(AGGREGATE_WIDTH);
  localparam fractal_sync_pkg::sd_e           SD_MASK       = fractal_sync_pkg::SD_BOTH;
  localparam int unsigned                     N_1D_RX_PORTS = N_RX_PORTS/2;

  typedef enum logic {
    IDLE,
    CHECK
  } state_e;

  localparam int unsigned SD_WIDTH = fractal_sync_pkg::SD_WIDTH;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[LEVEL_WIDTH-1:0] level[N_RX_PORTS];
  logic[LEVEL_WIDTH-1:0] h_level[N_1D_RX_PORTS];
  logic[LEVEL_WIDTH-1:0] v_level[N_1D_RX_PORTS];
  logic[ID_WIDTH-1:0]    id[N_RX_PORTS];
  logic[ID_WIDTH-1:0]    h_id[N_1D_RX_PORTS];
  logic[ID_WIDTH-1:0]    v_id[N_1D_RX_PORTS];

  logic[SD_WIDTH-1:0] src[N_RX_PORTS];
  logic[SD_WIDTH-1:0] h_src[N_1D_RX_PORTS];
  logic[SD_WIDTH-1:0] v_src[N_1D_RX_PORTS];
  logic[SD_WIDTH-1:0] dst[N_RX_PORTS];
  logic[SD_WIDTH-1:0] h_dst[N_1D_RX_PORTS];
  logic[SD_WIDTH-1:0] v_dst[N_1D_RX_PORTS];

  fsync_rsp_in_t  local_rsp[N_RX_PORTS];
  fsync_req_out_t remote_req[N_RX_PORTS];
  
  logic id_error[N_RX_PORTS];
  logic h_id_error[N_1D_RX_PORTS];
  logic v_id_error[N_1D_RX_PORTS];
  logic sig_error[N_RX_PORTS];
  logic h_sig_error[N_1D_RX_PORTS];
  logic v_sig_error[N_1D_RX_PORTS];
  logic rf_error[N_RX_PORTS];

  logic empty_local_fifo_err[N_FIFOS];
  logic full_local_fifo_err[N_FIFOS];
  logic empty_remote_fifo_err[N_FIFOS];
  logic full_remote_fifo_err[N_FIFOS];
  logic fifo_error[N_FIFOS];

  logic check_local[N_RX_PORTS];
  logic h_check_local[N_1D_RX_PORTS];
  logic v_check_local[N_1D_RX_PORTS];
  logic check_remote[N_RX_PORTS];
  logic h_check_remote[N_1D_RX_PORTS];
  logic v_check_remote[N_1D_RX_PORTS];
  logic bypass_local[N_RX_PORTS];
  logic h_bypass_local[N_1D_RX_PORTS];
  logic v_bypass_local[N_1D_RX_PORTS];
  logic bypass_remote[N_RX_PORTS];
  logic h_bypass_remote[N_1D_RX_PORTS];
  logic v_bypass_remote[N_1D_RX_PORTS];
  logic present_local[N_RX_PORTS];
  logic h_present_local[N_1D_RX_PORTS];
  logic v_present_local[N_1D_RX_PORTS];
  logic present_remote[N_RX_PORTS];
  logic h_present_remote[N_1D_RX_PORTS];
  logic v_present_remote[N_1D_RX_PORTS];
  
  logic push_local[N_FIFOS];
  logic full_local[N_FIFOS];
  logic push_remote[N_FIFOS];
  logic full_remote[N_FIFOS];

  state_e c_state[N_RX_PORTS];
  state_e n_state[N_RX_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_map
    for (genvar i = 0; i < N_1D_RX_PORTS; i++) begin
      assign id_error[2*i]   = h_id_error[i];
      assign id_error[2*i+1] = v_id_error[i];

      assign sig_error[2*i]   = h_sig_error[i];
      assign sig_error[2*i+1] = v_sig_error[i];

      assign h_level[i] = level[2*i];
      assign v_level[i] = level[2*i+1];

      assign h_id[i] = id[2*i];
      assign v_id[i] = id[2*i+1];

      assign h_src[i] = src[2*i];
      assign v_src[i] = src[2*i+1];

      assign dst[2*i]   = h_dst[i];
      assign dst[2*i+1] = v_dst[i];

      assign h_check_local[i] = check_local[2*i];
      assign v_check_local[i] = check_local[2*i+1];

      assign h_check_remote[i] = check_remote[2*i];
      assign v_check_remote[i] = check_remote[2*i+1];

      assign bypass_local[2*i]   = h_bypass_local[i];
      assign bypass_local[2*i+1] = v_bypass_local[i];

      assign bypass_remote[2*i]   = h_bypass_remote[i];
      assign bypass_remote[2*i+1] = v_bypass_remote[i];

      assign present_local[2*i]   = h_present_local[i];
      assign present_local[2*i+1] = v_present_local[i];

      assign present_remote[2*i]   = h_present_remote[i];
      assign present_remote[2*i+1] = v_present_remote[i];
    end
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_id_src
    assign id[i]  = req_i[i].sig.id;
    assign src[i] = req_i[i].src;
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_rf_error
    assign rf_error[i] = id_error[i] | sig_error[i];
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_req
    assign remote_req[i].sync     = req_i[i].sync;
    assign remote_req[i].sig.aggr = req_i[i].sig.aggr >> 1;
    assign remote_req[i].sig.id   = req_i[i].sig.id;
    assign remote_req[i].src      = {req_i[i].src, SD_MASK};
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_rsp
    assign local_rsp[i].wake  = 1'b1;
    assign local_rsp[i].dst   = dst[i];
    assign local_rsp[i].error = rf_error[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**              Level Encoder Beginning              **/
/*******************************************************/

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_lvl_enc
    always_comb begin: enc_logic
      level[i] = '0;
      for (int j = AGGREGATE_WIDTH-1; j >= 0; j--) begin
        if (req_i[i].sig.aggr[j] == 1'b1) begin
          level[i] = j;
          break;
        end
      end
    end
  end

/*******************************************************/
/**                 Level Encoder End                 **/
/*******************************************************/
/**               Control FSMs Beginning              **/
/*******************************************************/

  if (RF_DIM == fractal_sync_pkg::RF1D) begin: gen_1d_fsm
    for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_fsm

      always_ff @(posedge clk_i, negedge rst_ni) begin: state_register
        if (!rst_ni) c_state[i] <= IDLE;
        else         c_state[i] <= n_state[i];
      end

      always_comb begin: state_and_output_logic
        n_state[i] = c_state[i];

        check_local[i]  = 1'b0;
        check_remote[i] = 1'b0;
        push_local[i]   = 1'b0;
        push_remote[i]  = 1'b0;
        unique case (c_state[i])
          IDLE: begin
            if (local_i[i]) begin
              n_state[i] = CHECK;
              if (!root_i[i]) begin
                check_remote[i] = 1'b1;
                if (!rf_error[i]) push_remote[i] = bypass_remote[i] | present_remote[i];
                else              push_local[i]  = 1'b1;
              end else begin
                check_local[i] = 1'b1;
                push_local[i]  = bypass_local[i] | present_local[i] | rf_error[i];
              end
            end
          end
          CHECK: n_state[i] = IDLE;
        endcase
      end

    end
  end else if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_fsm
    for (genvar i = 0; i < N_1D_RX_PORTS; i++) begin: gen_h_fsm

      always_ff @(posedge clk_i, negedge rst_ni) begin: state_register
        if (!rst_ni) c_state[2*i] <= IDLE;
        else         c_state[2*i] <= n_state[2*i];
      end

      always_comb begin: state_and_output_logic
        n_state[2*i] = c_state[2*i];

        check_local[2*i]  = 1'b0;
        check_remote[2*i] = 1'b0;
        push_local[2*i]   = 1'b0;
        push_remote[2*i]  = 1'b0;
        unique case (c_state[2*i])
          IDLE: begin
            if (local_i[2*i]) begin
              n_state[2*i] = CHECK;
              if (!root_i[2*i]) begin
                check_remote[2*i] = 1'b1;
                if (!rf_error[2*i]) push_remote[2*i] = bypass_remote[2*i] | present_remote[2*i];
                else                push_local[2*i]  = 1'b1;
              end else begin
                check_local[2*i] = 1'b1;
                push_local[2*i]  = bypass_local[2*i] | present_local[2*i] | rf_error[2*i];
              end
            end
          end
          CHECK: n_state[2*i] = IDLE;
        endcase
      end

    end
    for (genvar i = 0; i < N_1D_RX_PORTS; i++) begin: gen_v_fsm

      always_ff @(posedge clk_i, negedge rst_ni) begin: state_register
        if (!rst_ni) c_state[2*i+1] <= IDLE;
        else         c_state[2*i+1] <= n_state[2*i+1];
      end

      always_comb begin: state_and_output_logic
        n_state[2*i+1] = c_state[2*i+1];

        check_local[2*i+1]  = 1'b0;
        check_remote[2*i+1] = 1'b0;
        push_local[2*i+1]   = 1'b0;
        push_remote[2*i+1]  = 1'b0;
        unique case (c_state[2*i+1])
          IDLE: begin
            if (local_i[2*i+1]) begin
              n_state[2*i+1] = CHECK;
              if (!root_i[2*i+1]) begin
                check_remote[2*i+1] = 1'b1;
                if (!rf_error[2*i+1]) push_remote[2*i+1] = bypass_remote[2*i+1] | present_remote[2*i+1];
                else                  push_local[2*i+1]  = 1'b1;
              end else begin
                check_local[2*i+1] = 1'b1;
                push_local[2*i+1]  = bypass_local[2*i+1] | present_local[2*i+1] | rf_error[2*i+1];
              end
            end
          end
          CHECK: n_state[2*i+1] = IDLE;
        endcase
      end

    end
  end else $fatal("Unsupported Register File Dimension");

/*******************************************************/
/**                  Control FSMs End                 **/
/*******************************************************/
/**              Register File Beginning              **/
/*******************************************************/

  if (RF_DIM == fractal_sync_pkg::RF1D) begin: gen_1d_rf
    fractal_sync_1d_rf #(
      .REMOTE_RF_TYPE ( RF_TYPE        ),
      .EN_REMOTE_RF   ( EN_REMOTE_RF   ),
      .N_LOCAL_REGS   ( N_LOCAL_REGS   ),
      .LEVEL_WIDTH    ( LEVEL_WIDTH    ),
      .ID_WIDTH       ( ID_WIDTH       ),
      .N_REMOTE_LINES ( N_REMOTE_LINES ),
      .N_PORTS        ( N_RX_PORTS     )
    ) i_rf (
      .clk_i                              ,
      .rst_ni                             ,
      .level_i          ( level          ),
      .id_i             ( id             ),
      .check_local_i    ( check_local    ),
      .check_remote_i   ( check_remote   ),
      .sd_local_i       ( src            ),
      .present_local_o  ( present_local  ),
      .present_remote_o ( present_remote ),
      .sd_local_o       ( dst            ),
      .id_err_o         ( id_error       ),
      .sig_err_o        ( sig_error      ),
      .bypass_local_o   ( bypass_local   ),
      .bypass_remote_o  ( bypass_remote  ),
      .ignore_local_o   (                ),
      .ignore_remote_o  (                )
    );
  end else if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_rf
    fractal_sync_2d_rf #(
      .REMOTE_RF_TYPE ( RF_TYPE        ),
      .EN_REMOTE_RF   ( EN_REMOTE_RF   ),
      .N_LOCAL_REGS   ( N_LOCAL_REGS   ),
      .LEVEL_WIDTH    ( LEVEL_WIDTH    ),
      .ID_WIDTH       ( ID_WIDTH       ),
      .N_REMOTE_LINES ( N_REMOTE_LINES ),
      .N_H_PORTS      ( N_1D_RX_PORTS  ),
      .N_V_PORTS      ( N_1D_RX_PORTS  )
    ) i_rf (
      .clk_i                                  ,
      .rst_ni                                 ,
      .level_h_i          ( h_level          ),
      .id_h_i             ( h_id             ),
      .check_h_local_i    ( h_check_local    ),
      .check_h_remote_i   ( h_check_remote   ),
      .sd_h_local_i       ( h_src            ),
      .h_present_local_o  ( h_present_local  ),
      .h_present_remote_o ( h_present_remote ),
      .h_sd_local_o       ( h_dst            ),
      .h_id_err_o         ( h_id_error       ),
      .h_sig_err_o        ( h_sig_error      ),
      .h_bypass_local_o   ( h_bypass_local   ),
      .h_bypass_remote_o  ( h_bypass_remote  ),
      .h_ignore_local_o   (                  ),
      .h_ignore_remote_o  (                  ),
      .level_v_i          ( v_level          ),
      .id_v_i             ( v_id             ),
      .check_v_local_i    ( v_check_local    ),
      .check_v_remote_i   ( v_check_remote   ),
      .sd_v_local_i       ( v_src            ),
      .v_present_local_o  ( v_present_local  ),
      .v_present_remote_o ( v_present_remote ),
      .v_sd_local_o       ( v_dst            )
      .v_id_err_o         ( v_id_error       ),
      .v_sig_err_o        ( v_sig_error      ),
      .v_bypass_local_o   ( v_bypass_local   ),
      .v_bypass_remote_o  ( v_bypass_remote  ),
      .v_ignore_local_o   (                  ),
      .v_ignore_remote_o  (                  )
    );
  end else $fatal("Unsupported Register File Dimension");

/*******************************************************/
/**                 Register File End                 **/
/*******************************************************/
/**              Error Handler Beginning              **/
/*******************************************************/

  for (genvar i = 0; i < N_FIFOS; i++) begin: gen_fifo_error
    assign empty_local_fifo_err[i]  = local_empty_o[i] & local_pop_i[i];
    assign full_local_fifo_err[i]   = full_local[i] & push_local[i];
    assign empty_remote_fifo_err[i] = remote_empty_o[i] & remote_pop_i[i];
    assign full_remote_fifo_err[i]  = full_remote[i] & push_remote[i];
    assign fifo_error[i]            = empty_local_fifo_err[i] | full_local_fifo_err[i] | empty_remote_fifo_err[i] | full_remote_fifo_err[i];
  end
  
  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_error_rx
    assign detected_error_o[i] = error_overflow_rx_i[i] | fifo_error[i];
  end
  for (genvar i = 0; i < N_TX_PORTS; i++) begin: gen_error_tx
    assign detected_error_o[i+N_RX_PORTS] = error_overflow_tx_i[i];
  end

/*******************************************************/
/**                 Error Handler End                 **/
/*******************************************************/
/**                  FIFOs Beginning                  **/
/*******************************************************/

  for (genvar i = 0; i < N_FIFOS; i++) begin: gen_local_fifos
    fractal_sync_fifo #(
      .FIFO_DEPTH ( FIFO_DEPTH     ),
      .fifo_t     ( fsync_rsp_in_t )
    ) i_local_fifo (
      .clk_i                         ,
      .rst_ni                        ,
      .push_i    ( push_local[i]    ),
      .element_i ( local_rsp[i]     ),
      .pop_i     ( local_pop_i[i]   ),
      .element_o ( local_rsp_o[i]   ),
      .empty_o   ( local_empty_o[i] ),
      .full_o    ( full_local[i]    )
    );
  end

  for (genvar i = 0; i < N_FIFOS; i++) begin: gen_remote_fifos
    fractal_sync_fifo #(
      .FIFO_DEPTH ( FIFO_DEPTH      ),
      .fifo_t     ( fsync_req_out_t )
    ) i_remote_fifo (
      .clk_i                          ,
      .rst_ni                         ,
      .push_i    ( push_remote[i]    ),
      .element_i ( remote_req[i]     ),
      .pop_i     ( remote_pop_i[i]   ),
      .element_o ( remote_req_o[i]   ),
      .empty_o   ( remote_empty_o[i] ),
      .full_o    ( full_remote[i]    )
    );
  end

/*******************************************************/
/**                     FIFOs End                     **/
/*******************************************************/

endmodule: fractal_sync_cc