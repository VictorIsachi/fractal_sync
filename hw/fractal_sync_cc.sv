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
  parameter fractal_sync_pkg::sd_e        SD_MASK         = fractal_sync_pkg::SD_BOTH,
  localparam int unsigned                 N_PORTS         = (RF_DIM == fractal_sync_pkg::RF2D) ? 4 : 
                                                            (RF_DIM == fractal_sync_pkg::RF1D) ? 2 :
                                                            0,
  parameter int unsigned                  FIFO_DEPTH_L    = 1,
  parameter int unsigned                  FIFO_DEPTH_R    = 1
)(
  input  logic           clk_i,
  input  logic           rst_ni,

  input  fsync_req_in_t  req_i[N_PORTS],
  input  logic           local_i[N_PORTS],
  input  logic           root_i[N_PORTS],
  input  logic           error_overflow_rx_i[N_PORTS],
  input  logic           error_overflow_tx_i[N_PORTS],

  output logic           local_empty_o[N_PORTS],
  output fsync_rsp_in_t  local_rsp_o[N_PORTS],
  input  logic           local_pop_i[N_PORTS],

  output logic           remote_empty_o[N_PORTS],
  output fsync_req_out_t remote_req_o[N_PORTS],
  input  logic           remote_pop_i[N_PORTS],

  output logic           detected_error_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_CC_LOCAL_REGS: assert (N_LOCAL_REGS > 0) else $fatal("N_LOCAL_REGS must be > 0");
  initial FRACTAL_SYNC_CC_REMOTE_LINES: assert (RF_TYPE == fractal_sync_pkg::CAM_RF -> N_REMOTE_LINES > 0) else $fatal("N_REMOTE_LINES must be > 0 for CAM Remote Register File");
  initial FRACTAL_SYNC_CC_AGGR_W: assert (AGGREGATE_WIDTH > 0) else $fatal("AGGREGATE_WIDTH must be > 0");
  initial FRACTAL_SYNC_CC_ID_W: assert (ID_WIDTH > 0) else $fatal("ID_WIDTH must be > 0");
  initial FRACTAL_SYNC_CC_FIFO_D_L: assert (FIFO_DEPTH_L > 0) else $fatal("FIFO_DEPTH_L must be > 0");
  initial FRACTAL_SYNC_CC_FIFO_D_R: assert (FIFO_DEPTH_R > 0) else $fatal("FIFO_DEPTH_R must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam int unsigned LEVEL_WIDTH = $clog2(AGGREGATE_WIDTH);
  localparam int unsigned N_FIFOS     = N_PORTS;

  typedef enum logic[1:0] {
    IDLE,
    ROOT,
    AGGR
  } state_e;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  logic[LEVEL_WIDTH-1:0] level[N_PORTS];
  logic[LEVEL_WIDTH-1:0] h_level[N_PORTS/2];
  logic[LEVEL_WIDTH-1:0] v_level[N_PORTS/2];
  logic[ID_WIDTH-1:0]    id[N_PORTS];
  logic[ID_WIDTH-1:0]    h_id[N_PORTS/2];
  logic[ID_WIDTH-1:0]    v_id[N_PORTS/2];

  fsync_rsp_in_t  local_rsp[N_PORTS];
  fsync_req_out_t remote_req[N_PORTS];
  
  logic id_error[N_PORTS];
  logic h_id_error[N_PORTS/2];
  logic v_id_error[N_PORTS/2];
  logic sig_error[N_PORTS];
  logic h_sig_error[N_PORTS/2];
  logic v_sig_error[N_PORTS/2];
  logic rf_error[N_PORTS];

  logic empty_local_fifo_err[N_FIFOS];
  logic full_local_fifo_err[N_FIFOS];
  logic empty_remote_fifo_err[N_FIFOS];
  logic full_remote_fifo_err[N_FIFOS];
  logic fifo_error[N_FIFOS];

  logic check_local[N_PORTS];
  logic h_check_local[N_PORTS/2];
  logic v_check_local[N_PORTS/2];
  logic check_remote[N_PORTS];
  logic h_check_remote[N_PORTS/2];
  logic v_check_remote[N_PORTS/2];
  logic bypass_local[N_PORTS];
  logic h_bypass_local[N_PORTS/2];
  logic v_bypass_local[N_PORTS/2];
  logic bypass_remote[N_PORTS];
  logic h_bypass_remote[N_PORTS/2];
  logic v_bypass_remote[N_PORTS/2];
  logic present_local[N_PORTS];
  logic h_present_local[N_PORTS/2];
  logic v_present_local[N_PORTS/2];
  logic present_remote[N_PORTS];
  logic h_present_remote[N_PORTS/2];
  logic v_present_remote[N_PORTS/2];
  
  logic push_local[N_FIFOS];
  logic full_local[N_FIFOS];
  logic push_remote[N_FIFOS];
  logic full_remote[N_FIFOS];

  state_e c_state[N_PORTS];
  state_e n_state[N_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_map
    assign id_error[H01_IDX] = h_id_error[0];
    assign id_error[H02_IDX] = h_id_error[1];
    assign id_error[V01_IDX] = v_id_error[0];
    assign id_error[V02_IDX] = v_id_error[1];

    assign sig_error[H01_IDX] = h_sig_error[0];
    assign sig_error[H02_IDX] = h_sig_error[1];
    assign sig_error[V01_IDX] = v_sig_error[0];
    assign sig_error[V02_IDX] = v_sig_error[1];

    assign h_level[0] = level[H01_IDX];
    assign h_level[1] = level[H02_IDX];
    assign v_level[0] = level[V01_IDX];
    assign v_level[1] = level[V02_IDX];
    
    assign h_id[0] = id[H01_IDX];
    assign h_id[1] = id[H02_IDX];
    assign v_id[0] = id[V01_IDX];
    assign v_id[1] = id[V02_IDX];

    assign h_check_local[0] = check_local[H01_IDX];
    assign h_check_local[1] = check_local[H02_IDX];
    assign v_check_local[0] = check_local[V01_IDX];
    assign v_check_local[1] = check_local[V02_IDX];

    assign h_check_remote[0] = check_remote[H01_IDX];
    assign h_check_remote[1] = check_remote[H02_IDX];
    assign v_check_remote[0] = check_remote[V01_IDX];
    assign v_check_remote[1] = check_remote[V02_IDX];

    assign bypass_local[H01_IDX] = h_bypass_local[0];
    assign bypass_local[H02_IDX] = h_bypass_local[1];
    assign bypass_local[V01_IDX] = v_bypass_local[0];
    assign bypass_local[V02_IDX] = v_bypass_local[1];

    assign bypass_remote[H01_IDX] = h_bypass_remote[0];
    assign bypass_remote[H02_IDX] = h_bypass_remote[1];
    assign bypass_remote[V01_IDX] = v_bypass_remote[0];
    assign bypass_remote[V02_IDX] = v_bypass_remote[1];

    assign present_local[H01_IDX] = h_present_local[0];
    assign present_local[H02_IDX] = h_present_local[1];
    assign present_local[V01_IDX] = v_present_local[0];
    assign present_local[V02_IDX] = v_present_local[1];

    assign present_remote[H01_IDX] = h_present_remote[0];
    assign present_remote[H02_IDX] = h_present_remote[1];
    assign present_remote[V01_IDX] = v_present_remote[0];
    assign present_remote[V02_IDX] = v_present_remote[1];
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_id
    assign id[i] = req_i[i].sig.id;
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_rf_error
    assign rf_error[i] = id_error[i] | sig_error[i];
  end

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_req
    assign remote_req[i].sync     = req_i[i].sync;
    assign remote_req[i].sig.aggr = req_i[i].sig.aggr >> 1;
    assign remote_req[i].sig.id   = req_i[i].sig.id;
    assign remote_req[i].src      = {req_i[i].src, SD_MASK};
  end

  for (genvar i = 0; i < N_PORTS: i++) begin: gen_rsp
    assign local_rsp[i].wake  = 1'b1;
    assign local_rsp[i].dst   = req_i[i].src;
    assign local_rsp[i].error = rf_error[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**              Level Encoder Beginning              **/
/*******************************************************/

  for (genvar i = 0; i < N_PORTS; i++) begin: gen_lvl_enc
    always_comb begin: enc_logic
      level = '0;
      for (int unsigned j = AGGREGATE_WIDTH-1; j >= 0; j++) begin
        if (req_i[i].sig.aggr[j] == 1'b1) begin
          level = j;
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
    for (genvar i = 0; i < N_PORTS; i++) begin: gen_fsm

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
            if (req_i[i].sync & root_i[i]) begin 
              n_state[i] = ROOT; 
              check_local[i] = 1'b1;
            end else if (req_i[i].sync & ~root_i[i] & local_i[i]) begin
              n_state[i] = AGGR;
              check_remote[i] = 1'b1;
            end
          end
          ROOT: begin
            n_state[i] = IDLE;
            push_local[i] = ((i == 0) & bypass_local[i]) | present_local[i] | rf_error[i];
          end
          AGGR: begin
            n_state[i] = IDLE;
            if (rf_error[i])
              push_local[i] = 1'b1;
            else
              push_remote[i] = ((i == 0) & bypass_remote[i]) | present_remote[i];
          end
        endcase
      end

    end
  end else if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_fsm
    for (genvar i = 0; i < N_PORTS/2; i++) begin: gen_h_fsm

      always_ff @(posedge clk_i, negedge rst_ni) begin: state_register
        if (!rst_ni) c_state[2*i] <= IDLE;
        else         c_state[2*i] <= n_state[2*i];
      end

      always_comb begin: state_and_output_logic
        n_state[2*i] = c_state[2*i];

        h_check_local[i]  = 1'b0;
        h_check_remote[i] = 1'b0;
        push_local[2*i]   = 1'b0;
        push_remote[2*i]  = 1'b0;
        unique case (c_state[2*i])
          IDLE: begin
            if (req_i[2*i].sync & root_i[2*i]) begin 
              n_state[2*i] = ROOT; 
              h_check_local[i] = 1'b1;
            end else if (req_i[2*i].sync & ~root_i[2*i] & local_i[2*i]) begin
              n_state[2*i] = AGGR;
              h_check_remote[i] = 1'b1;
            end
          end
          ROOT: begin
            n_state[2*i] = IDLE;
            push_local[2*i] = ((i == 0) & h_bypass_local[i]) | h_present_local[i] | rf_error[2*i];
          end
          AGGR: begin
            n_state[2*i] = IDLE;
            if (rf_error[2*i])
              push_local[2*i] = 1'b1;
            else
              push_remote[2*i] = ((i == 0) & h_bypass_remote[i]) | h_present_remote[i];
          end
        endcase
      end

    end
    for (genvar i = 0; i < N_PORTS/2; i++) begin: gen_v_fsm

      always_ff @(posedge clk_i, negedge rst_ni) begin: state_register
        if (!rst_ni) c_state[2*i+1] <= IDLE;
        else         c_state[2*i+1] <= n_state[2*i+1];
      end

      always_comb begin: state_and_output_logic
        n_state[2*i+1] = c_state[2*i+1];

        v_check_local[i]   = 1'b0;
        v_check_remote[i]  = 1'b0;
        push_local[2*i+1]  = 1'b0;
        push_remote[2*i+1] = 1'b0;
        unique case (c_state[2*i+1])
          IDLE: begin
            if (req_i[2*i+1].sync & root_i[2*i+1]) begin 
              n_state[2*i+1] = ROOT; 
              v_check_local[i] = 1'b1;
            end else if (req_i[2*i+1].sync & ~root_i[2*i+1] & local_i[2*i+1]) begin
              n_state[2*i+1] = AGGR;
              v_check_remote[i] = 1'b1;
            end
          end
          ROOT: begin
            n_state[2*i+1] = IDLE;
            push_local[2*i+1] = ((i == 0) & v_bypass_local[i]) | v_present_local[i] | rf_error[2*i+1];
          end
          AGGR: begin
            n_state[2*i+1] = IDLE;
            if (rf_error[2*i+1])
              push_local[2*i+1] = 1'b1;
            else
              push_remote[2*i+1] = ((i == 0) & v_bypass_remote[i]) | v_present_remote[i];
          end
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
      .N_LOCAL_REGS   ( N_LOCAL_REGS   ),
      .LEVEL_WIDTH    ( LEVEL_WIDTH    ),
      .ID_WIDTH       ( ID_WIDTH       ),
      .N_REMOTE_LINES ( N_REMOTE_LINES )
    ) i_rf (
      .clk_i                              ,
      .rst_ni                             ,
      .level_i          ( level          ),
      .id_i             ( id             ),
      .check_local_i    ( check_local    ),
      .check_remote_i   ( check_remote   ),
      .present_local_o  ( present_local  ),
      .present_remote_o ( present_remote ),
      .id_err_o         ( id_error       ),
      .sig_err_o        ( sig_error      ),
      .bypass_local_o   ( bypass_local   ),
      .bypass_remote_o  ( bypass_remote  )
    );
  end else if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_rf
    fractal_sync_2d_rf #(
      .REMOTE_RF_TYPE ( RF_TYPE        ),
      .N_LOCAL_REGS   ( N_LOCAL_REGS   ),
      .LEVEL_WIDTH    ( LEVEL_WIDTH    ),
      .ID_WIDTH       ( ID_WIDTH       ),
      .N_REMOTE_LINES ( N_REMOTE_LINES )
    ) i_rf (
      .clk_i                                  ,
      .rst_ni                                 ,
      .level_h_i          ( h_level          ),
      .id_h_i             ( h_id             ),
      .check_h_local_i    ( h_check_local    ),
      .check_h_remote_i   ( h_check_remote   ),
      .h_present_local_o  ( h_present_local  ),
      .h_present_remote_o ( h_present_remote ),
      .h_id_err_o         ( h_id_error       ),
      .h_sig_err_o        ( h_sig_error      ),
      .h_bypass_local_o   ( h_bypass_local   ),
      .h_bypass_remote_o  ( h_bypass_remote  ),
      .level_v_i          ( v_level          ),
      .id_v_i             ( v_id             ),
      .check_v_local_i    ( v_check_local    ),
      .check_v_remote_i   ( v_check_remote   ),
      .v_present_local_o  ( v_present_local  ),
      .v_present_remote_o ( v_present_remote ),
      .v_id_err_o         ( v_id_error       ),
      .v_sig_err_o        ( v_sig_error      ),
      .v_bypass_local_o   ( v_bypass_local   ),
      .v_bypass_remote_o  ( v_bypass_remote  )
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
  
  for (genvar i = 0; i < N_PORTS; i++) begin: gen_error
    assign detected_error_o[i] = error_overflow_rx_i[i] | error_overflow_tx_i[i] | fifo_error[i];
  end

/*******************************************************/
/**                 Error Handler End                 **/
/*******************************************************/
/**               Local FIFOs Beginning               **/
/*******************************************************/

  for (genvar i = 0; i < N_FIFOS; i++) begin: gen_local_fifos
    fractal_sync_fifo #(
      .FIFO_DEPTH ( FIFO_DEPTH_L   ),
      .fifo_t     ( fsync_rsp_in_t )
    ) i_local_fifo (
      .clk_i                         ,
      .rst_ni                        ,
      .push_i    ( push_local[i]    ),
      .element_i ( local_rsp[i]     ),
      .pop_i     ( local_pop_i[i]   ),
      .element_o ( local_req_o[i]   ),
      .empty_o   ( local_empty_o[i] ),
      .full_o    ( full_local[i]    )
    );
  end

/*******************************************************/
/**                  Local FIFOs End                  **/
/*******************************************************/
/**               Remote FIFOs Beginning              **/
/*******************************************************/

  for (genvar i = 0; i < N_FIFOS; i++) begin: gen_remote_fifos
    fractal_sync_fifo #(
      .FIFO_DEPTH ( FIFO_DEPTH_R    ),
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
/**                  Remote FIFOs End                 **/
/*******************************************************/

endmodule: fractal_sync_cc