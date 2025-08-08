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
 *  NODE_TYPE            - Node type of control core (horizontal, vertical, 2D, root)
 *  RF_TYPE              - Remote RF type (Directly Mapped or CAM)
 *  N_QUEUE_REGS         - Number of registers in the queue RF
 *  QUEUE_DEPTH          - Queue RF register depth (FIFO depth)
 *  N_LOCAL_REGS         - Number of registers in the local RF
 *  N_REMOTE_LINES       - Number of CAM lines in a CAM-based remote RF
 *  AGGREGATE_WIDTH      - Width of the aggr field
 *  ID_WIDTH             - Width of the id field
 *  LVL_OFFSET           - Level offset from first node of the syncrhonization tree: 0 for nodes at level 1, 1 for nodes at level 2, ...
 *  fsync_req_t          - Input synchronization request type (RX -> CC; CC -> RX arb.)
 *  fsync_rsp_t          - Input synchronization response type (TX -> CC; CC -> TX arb.)
 *  N_RX_PORTS           - Number of input (RX) ports
 *  N_TX_PORTS           - Number of output (TX) ports
 *  FIFO_DEPTH           - Maximum number of elements that can be present in a FIFO
 *  QUEUE_FIFO_COMB_OUT  - 1: Queue RF register and output FIFOs with fall-through; 0: sequential register and output FIFOs
 *  LOCAL_FIFO_COMB_OUT  - 1: Output local FIFO with fall-through; 0: sequential local FIFO
 *  REMOTE_FIFO_COMB_OUT - 1: Output remote FIFO with fall-through; 0: sequential remote FIFO
 *
 * Interface signals:
 *  > req_i               - Synchronization request (input)
 *  > check_rf_i          - Indicates the presence of a synch. req.
 *  > local_i             - Indicates that synch. req. should be managed by current node (root or aggregate)
 *  > root_i              - Indicates that synch. req. has reached the root of the synchronization tree
 *  > lock_i              - Indicates that synch. req. is of type lock
 *  > free_i              - Indicates that synch. req. is of type free
 *  < propagate_lock_o    - Indicates that synch. req. of type lock/free should be propagated to the next level of the tree
 *  > error_overflow_rx_i - Indicates RX FIFO overflow
 *  > rsp_i               - Synchronization response (output)
 *  > check_br_i          - Indicates that synch. rsp. should be checked in remote RF to determine back-routing information
 *  > check_aggr_i        - Indicates that synch. rsp. should be checked by aggregation pattern to determine back-routing information
 *  < en_br_o             - Indicates that synch. rsp. should be routed via the east-north channel
 *  < ws_br_o             - Indicates taht synch. rsp. should be routed via the west-south channel
 *  > error_overflow_tx_i - Indicates TX FIFO overflow
 *  > local_empty_o       - Indicates that local FIFO (associated with local RF) is empty
 *  > local_rsp_o         - Local synchronization response (input) FIFO
 *  > local_pop_i         - Pop synch. rsp.
 *  > remote_empty_o      - Indicates that remote FIFO (associated with remote RF) is empty
 *  > remote_req_o        - Remote synch. req. (output) FIFO
 *  > remote_pop_i        - Pop synch. req.
 *  > queue_empty_o       - Indicates that en/ws queue FIFO (associated with queue RF) is empty
 *  > queue_req_o         - Queue synch. rsp. (input) FIFO
 *  > queue_pop_i         - Pop synch. rsp.
 *  > detected_error_o    - Detected error associated with RX/TX transaction
 */

module fractal_sync_cc 
  import fractal_sync_pkg::*; 
#(
  parameter fractal_sync_pkg::node_e      NODE_TYPE            = fractal_sync_pkg::HV_NODE,
  localparam fractal_sync_pkg::rf_dim_e   RF_DIM               = (NODE_TYPE == fractal_sync_pkg::HV_NODE) ||
                                                                 (NODE_TYPE == fractal_sync_pkg::RT_NODE) ? 
                                                                 fractal_sync_pkg::RF2D : fractal_sync_pkg::RF1D,
  parameter fractal_sync_pkg::remote_rf_e RF_TYPE              = fractal_sync_pkg::CAM_RF,
  parameter int unsigned                  N_QUEUE_REGS         = 0,
  parameter int unsigned                  QUEUE_DEPTH          = 0,
  parameter int unsigned                  N_LOCAL_REGS         = 0,
  parameter int unsigned                  N_REMOTE_LINES       = 0,
  parameter int unsigned                  AGGREGATE_WIDTH      = 1,
  parameter int unsigned                  ID_WIDTH             = 1,
  parameter int unsigned                  LVL_OFFSET           = 0,
  parameter type                          fsync_req_t          = logic,
  parameter type                          fsync_rsp_t          = logic,
  // 2D CC: even indexed ports -> horizontal channel; odd indexed ports -> vertical channel
  parameter int unsigned                  N_RX_PORTS           = (RF_DIM == fractal_sync_pkg::RF2D) ? 4 : 
                                                                 (RF_DIM == fractal_sync_pkg::RF1D) ? 2 :
                                                                 0,
  // 2D CC: even indexed ports -> horizontal channel; odd indexed ports -> vertical channel
  parameter int unsigned                  N_TX_PORTS           = (RF_DIM == fractal_sync_pkg::RF2D) ? 2 : 
                                                                 (RF_DIM == fractal_sync_pkg::RF1D) ? 1 :
                                                                 0,
  // Total number of ports: lower indexes represent RX ports; higher indexes represent TX ports
  localparam int unsigned                 N_PORTS              = N_RX_PORTS + N_TX_PORTS,
  // 2D CC: even indexed FIFOs -> horizontal channel; odd indexed FIFOs -> vertical channel
  localparam int unsigned                 N_FIFOS              = N_RX_PORTS, 
  parameter int unsigned                  FIFO_DEPTH           = 1,
  parameter bit                           QUEUE_FIFO_COMB_OUT  = 1'b1,
  parameter bit                           LOCAL_FIFO_COMB_OUT  = 1'b1,
  parameter bit                           REMOTE_FIFO_COMB_OUT = 1'b1
)(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  fsync_req_t req_i[N_RX_PORTS],
  input  logic       check_rf_i[N_RX_PORTS],
  input  logic       local_i[N_RX_PORTS],
  input  logic       root_i[N_RX_PORTS],
  input  logic       lock_i[N_RX_PORTS],
  input  logic       free_i[N_RX_PORTS],
  output logic       propagate_lock_o[N_RX_PORTS],
  input  logic       error_overflow_rx_i[N_RX_PORTS],

  input  fsync_rsp_t rsp_i[N_TX_PORTS],
  input  logic       check_br_i[N_TX_PORTS],
  input  logic       check_aggr_i[N_TX_PORTS],
  output logic       en_br_o[N_TX_PORTS],
  output logic       ws_br_o[N_TX_PORTS],
  input  logic       error_overflow_tx_i[N_TX_PORTS],

  output logic       local_empty_o[N_FIFOS],
  output fsync_rsp_t local_rsp_o[N_FIFOS],
  input  logic       local_pop_i[N_FIFOS],

  output logic       remote_empty_o[N_FIFOS],
  output fsync_req_t remote_req_o[N_FIFOS],
  input  logic       remote_pop_i[N_FIFOS],

  output logic       en_queue_empty_o[N_FIFOS],
  output fsync_rsp_t en_queue_rsp_o[N_FIFOS],
  input  logic       en_queue_pop_i[N_FIFOS],

  output logic       ws_queue_empty_o[N_FIFOS],
  output fsync_rsp_t ws_queue_rsp_o[N_FIFOS],
  input  logic       ws_queue_pop_i[N_FIFOS],

  output logic       detected_error_o[N_PORTS]
);

/*******************************************************/
/**                Assertions Beginning               **/
/*******************************************************/

  initial FRACTAL_SYNC_CC_QUEUE_REGS: assert (N_QUEUE_REGS > 0) else $fatal("N_QUEUE_REGS must be > 0");
  initial FRACTAL_SYNC_CC_QUEUE_DEPTH: assert (QUEUE_DEPTH > 0) else $fatal("QUEUE_DEPTH must be > 0");
  initial FRACTAL_SYNC_CC_LOCAL_REGS: assert (N_LOCAL_REGS > 0) else $fatal("N_LOCAL_REGS must be > 0");
  initial FRACTAL_SYNC_CC_REMOTE_LINES: assert (RF_TYPE == fractal_sync_pkg::CAM_RF -> N_REMOTE_LINES > 0) else $fatal("N_REMOTE_LINES must be > 0 for CAM Remote Register File");
  initial FRACTAL_SYNC_CC_AGGR_W: assert (AGGREGATE_WIDTH > 0) else $fatal("AGGREGATE_WIDTH must be > 0");
  initial FRACTAL_SYNC_CC_ID_W: assert (ID_WIDTH > 0) else $fatal("ID_WIDTH must be > 0");
  initial FRACTAL_SYNC_CC_AGGR: assert ($bits(req_i[0].sig.aggr) == $bits(rsp_i[0].sig.aggr)) else $fatal("Req. aggregate with must be equal to rsp. aggregate width ");
  initial FRACTAL_SYNC_CC_ID: assert ($bits(req_i[0].sig.id) == $bits(rsp_i[0].sig.id)) else $fatal("Req. id with must be equal to rsp. id width ");
  initial FRACTAL_SYNC_CC_RX_PORTS: assert (N_RX_PORTS > 0) else $fatal("N_RX_PORTS must be > 0");
  initial FRACTAL_SYNC_CC_TX_PORTS: assert (N_TX_PORTS > 0) else $fatal("N_TX_PORTS must be > 0");
  initial FRACTAL_SYNC_CC_FIFO_DEPTH: assert (FIFO_DEPTH > 0) else $fatal("FIFO_DEPTH must be > 0");

/*******************************************************/
/**                   Assertions End                  **/
/*******************************************************/
/**        Parameters and Definitions Beginning       **/
/*******************************************************/

  localparam fractal_sync_pkg::en_remote_rf_e EN_REMOTE_RF  = (NODE_TYPE == fractal_sync_pkg::RT_NODE) ? fractal_sync_pkg::ENN_REMOTE_RF : fractal_sync_pkg::EN_REMOTE_RF;
  localparam int unsigned                     LEVEL_WIDTH   = $clog2(ID_WIDTH+1);
  localparam int unsigned                     N_1D_RX_PORTS = N_RX_PORTS/2;
  localparam int unsigned                     N_1D_TX_PORTS = N_TX_PORTS/2;
  localparam int unsigned                     N_1D_PORTS    = N_PORTS/2;
  localparam int unsigned                     SD_WIDTH      = fractal_sync_pkg::SD_WIDTH;

  typedef logic[LEVEL_WIDTH-1:0]     level_t;
  typedef logic[ID_WIDTH-1:0]        id_t;
  typedef logic[SD_WIDTH-1:0]        sd_t;
  typedef logic[AGGREGATE_WIDTH-1:0] aggr_t;

/*******************************************************/
/**           Parameters and Definitions End          **/
/*******************************************************/
/**             Internal Signals Beginning            **/
/*******************************************************/

  level_t level[N_PORTS];
  level_t h_level[N_1D_PORTS];
  level_t v_level[N_1D_PORTS];
  id_t    id[N_PORTS];
  id_t    h_id[N_1D_PORTS];
  id_t    v_id[N_1D_PORTS];
  sd_t    sd_in[N_PORTS];
  sd_t    h_sd_in[N_1D_PORTS];
  sd_t    v_sd_in[N_1D_PORTS];
  sd_t    sd_out[N_PORTS];
  sd_t    h_sd_out[N_1D_PORTS];
  sd_t    v_sd_out[N_1D_PORTS];
  aggr_t  br_in[N_RX_PORTS];
  aggr_t  h_br_in[N_1D_RX_PORTS];
  aggr_t  v_br_in[N_1D_RX_PORTS];
  aggr_t  br_out[N_RX_PORTS];
  aggr_t  h_br_out[N_1D_RX_PORTS];
  aggr_t  v_br_out[N_1D_RX_PORTS];

  fsync_rsp_t local_barrier_rsp[N_RX_PORTS];
  fsync_rsp_t local_lock_rsp[N_RX_PORTS];
  logic       local_rsp_type[N_RX_PORTS];
  fsync_rsp_t local_rsp[N_RX_PORTS];
  fsync_req_t remote_req[N_RX_PORTS];
  fsync_rsp_t queue_rsp[N_RX_PORTS];

  logic lock_req[N_RX_PORTS];
  logic local_queue[N_RX_PORTS];
  
  logic queue_error[N_RX_PORTS];
  logic h_queue_error[N_1D_RX_PORTS];
  logic v_queue_error[N_1D_RX_PORTS];
  logic id_error[N_RX_PORTS];
  logic h_id_error[N_1D_RX_PORTS];
  logic v_id_error[N_1D_RX_PORTS];
  logic sig_error[N_PORTS];
  logic h_sig_error[N_1D_PORTS];
  logic v_sig_error[N_1D_PORTS];
  logic barrier_rf_error[N_PORTS];

  logic empty_local_fifo_err[N_FIFOS];
  logic full_local_fifo_err[N_FIFOS];
  logic empty_remote_fifo_err[N_FIFOS];
  logic full_remote_fifo_err[N_FIFOS];
  logic empty_en_queue_fifo_err[N_FIFOS];
  logic full_en_queue_fifo_err[N_FIFOS];
  logic empty_ws_queue_fifo_err[N_FIFOS];
  logic full_ws_queue_fifo_err[N_FIFOS];
  logic fifo_error[N_FIFOS];

  logic lock_queue[N_RX_PORTS];
  logic h_lock_queue[N_1D_RX_PORTS];
  logic v_lock_queue[N_1D_RX_PORTS];
  logic free_queue[N_RX_PORTS];
  logic h_free_queue[N_1D_RX_PORTS];
  logic v_free_queue[N_1D_RX_PORTS];
  logic check_local[N_RX_PORTS];
  logic h_check_local[N_1D_RX_PORTS];
  logic v_check_local[N_1D_RX_PORTS];
  logic check_remote[N_PORTS];
  logic h_check_remote[N_1D_PORTS];
  logic v_check_remote[N_1D_PORTS];
  logic set_remote[N_PORTS];
  logic h_set_remote[N_1D_PORTS];
  logic v_set_remote[N_1D_PORTS];
  logic bypass_local[N_RX_PORTS];
  logic h_bypass_local[N_1D_RX_PORTS];
  logic v_bypass_local[N_1D_RX_PORTS];
  logic bypass_remote[N_PORTS];
  logic h_bypass_remote[N_1D_PORTS];
  logic v_bypass_remote[N_1D_PORTS];
  logic grant_queue[N_RX_PORTS];
  logic h_grant_queue[N_RX_PORTS];
  logic v_grant_queue[N_RX_PORTS];
  logic present_local[N_RX_PORTS];
  logic h_present_local[N_1D_RX_PORTS];
  logic v_present_local[N_1D_RX_PORTS];
  logic present_remote[N_PORTS];
  logic h_present_remote[N_1D_PORTS];
  logic v_present_remote[N_1D_PORTS];
  
  logic push_local[N_FIFOS];
  logic full_local[N_FIFOS];
  logic push_remote[N_FIFOS];
  logic full_remote[N_FIFOS];
  logic push_en_queue[N_FIFOS];
  logic full_en_queuel[N_FIFOS];
  logic push_ws_queue[N_FIFOS];
  logic full_ws_queuel[N_FIFOS];

  id_t  sampled_queue_id[N_RX_PORTS];
  logic sampled_queue_error[N_RX_PORTS];

/*******************************************************/
/**                Internal Signals End               **/
/*******************************************************/
/**            Hardwired Signals Beginning            **/
/*******************************************************/

  if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_map
    for (genvar i = 0; i < N_1D_PORTS; i++) begin
      assign sig_error[2*i]   = h_sig_error[i];
      assign sig_error[2*i+1] = v_sig_error[i];

      assign h_level[i] = level[2*i];
      assign v_level[i] = level[2*i+1];

      assign h_id[i] = id[2*i];
      assign v_id[i] = id[2*i+1];

      assign h_check_remote[i] = check_remote[2*i];
      assign v_check_remote[i] = check_remote[2*i+1];

      assign h_set_remote[i] = set_remote[2*i];
      assign v_set_remote[i] = set_remote[2*i+1];

      assign bypass_remote[2*i]   = h_bypass_remote[i];
      assign bypass_remote[2*i+1] = v_bypass_remote[i];

      assign present_remote[2*i]   = h_present_remote[i];
      assign present_remote[2*i+1] = v_present_remote[i];

      assign sd_out[2*i]   = h_sd_out[i];
      assign sd_out[2*i+1] = v_sd_out[i];

      assign h_sd_in[i] = sd_in[2*i];
      assign v_sd_in[i] = sd_in[2*i+1];
    end
    for (genvar i = 0; i < N_1D_RX_PORTS; i++) begin
      assign h_br_in[i] = br_in[2*i];
      assign v_br_in[i] = br_in[2*i+1];

      assign br_out[2*i]   = h_br_out[i];
      assign br_out[2*i+1] = v_br_out[i];
      
      assign queue_error[2*i]   = h_queue_error[i];
      assign queue_error[2*i+1] = v_queue_error[i];
      
      assign id_error[2*i]   = h_id_error[i];
      assign id_error[2*i+1] = v_id_error[i];
      
      assign h_lock_queue[i] = lock_queue[2*i];
      assign v_lock_queue[i] = lock_queue[2*i+1];

      assign h_free_queue[i] = free_queue[2*i];
      assign v_free_queue[i] = free_queue[2*i+1];
      
      assign h_check_local[i] = check_local[2*i];
      assign v_check_local[i] = check_local[2*i+1];

      assign bypass_local[2*i]   = h_bypass_local[i];
      assign bypass_local[2*i+1] = v_bypass_local[i];

      assign grant_queue[2*i]   = h_grant_queue[i];
      assign grant_queue[2*i+1] = v_grant_queue[i];

      assign present_local[2*i]   = h_present_local[i];
      assign present_local[2*i+1] = v_present_local[i];
    end
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_lock_req_local_queue
    assign lock_req[i]    = lock_i[i] | free_i[i];
    assign local_queue[i] = (level[i] == LVL_OFFSET) ? 1'b1 : 1'b0;
  end
  
  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_rx_id
    assign id[i] = req_i[i].sig.id;
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) sampled_queue_id[i] <= '0;
      else         sampled_queue_id[i] <= req_i[i].sig.id;
    end
  end
  for (genvar i = 0; i < N_TX_PORTS; i++) begin: gen_tx_id
    assign id[i+N_RX_PORTS] = rsp_i[i].sig.id;
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_rx_rf_error
    assign barrier_rf_error[i] = id_error[i] | sig_error[i];
    always_ff @(posedge clk_i, negedge rst_ni) begin
      if (!rst_ni) sampled_queue_error[i] <= 1'b0;
      else         sampled_queue_error[i] <= queue_error[i];
    end
  end
  for (genvar i = 0; i < N_TX_PORTS; i++) begin: gen_tx_rf_error
    assign barrier_rf_error[i+N_RX_PORTS] = sig_error[i];
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_remote_req
    assign remote_req[i].sync     = req_i[i].sync;
    assign remote_req[i].lock     = req_i[i].lock;
    assign remote_req[i].free     = req_i[i].free;
    assign remote_req[i].sig.aggr = req_i[i].sig.aggr >> 1;
    assign remote_req[i].sig.id   = req_i[i].sig.id;
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_local_barrier_rsp
    assign local_barrier_rsp[i].wake     = 1'b1;
    assign local_barrier_rsp[i].grant    = 1'b0;
    assign local_barrier_rsp[i].sig.aggr = level[i];
    assign local_barrier_rsp[i].sig.id   = req_i[i].sig.id;
    assign local_barrier_rsp[i].error    = barrier_rf_error[i];
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_local_lock_rsp
    assign local_lock_rsp[i].wake     = 1'b0;
    assign local_lock_rsp[i].grant    = 1'b1;
    assign local_lock_rsp[i].sig.aggr = req_i[i].sig.aggr;
    assign local_lock_rsp[i].sig.id   = req_i[i].sig.id;
    assign local_lock_rsp[i].error    = queue_error[i];
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_local_rsp
    assign local_rsp_type[i] = req_i[i].sync ? 1'b1 : 1'b0;
    assign local_rsp[i]      = local_rsp_type[i] ? local_barrier_rsp[i] : local_lock_rsp[i];
  end

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_queue_rsp
    assign queue_rsp[i].wake     = 1'b0;
    assign queue_rsp[i].grant    = 1'b1;
    assign queue_rsp[i].sig.aggr = br_out[i];
    assign queue_rsp[i].sig.id   = sampled_queue_id[i];
    assign queue_rsp[i].error    = sampled_queue_error[i];
  end

/*******************************************************/
/**               Hardwired Signals End               **/
/*******************************************************/
/**              Level Encoder Beginning              **/
/*******************************************************/

  for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_rx_lvl_enc
    always_comb begin: enc_logic
      level[i] = '0;
      for (int j = AGGREGATE_WIDTH-1; j >= 0; j--) begin
        if (req_i[i].sig.aggr[j] == 1'b1) begin
          level[i] = lock_req[i] ? j : j+LVL_OFFSET;
          break;
        end
      end
    end
  end
  for (genvar i = 0; i < N_TX_PORTS; i++) begin: gen_tx_lvl_enc
    assign level[i+N_RX_PORTS] = rsp_i[i].sig.aggr;
  end

/*******************************************************/
/**                 Level Encoder End                 **/
/*******************************************************/
/**              Control Logic Beginning              **/
/*******************************************************/

  if (RF_DIM == fractal_sync_pkg::RF1D) begin: gen_1d_logic
    for (genvar i = 0; i < N_RX_PORTS; i++) begin: gen_rx_logic
      always_comb begin
        lock_queue[i]       = 1'b0;
        free_queue[i]       = 1'b0;
        check_local[i]      = 1'b0;
        check_remote[i]     = 1'b0;
        set_remote[i]       = 1'b0;
        sd_in[i]            = i%2 ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EAST_NORTH;
        br_in[i]            = '0;
        push_local[i]       = 1'b0;
        push_remote[i]      = 1'b0;
        push_en_queue[i]    = 1'b0;
        push_ws_queue[i]    = 1'b0;
        propagate_lock_o[i] = 1'b0;

        if (lock_req[i]) begin
          if (!local_queue[i]) begin
            propagate_lock_o[i] = 1'b1;
          end else begin
            br_in[i]      = req_i[i].sig.aggr;
            lock_queue[i] = lock_i[i];
            free_queue[i] = free_i[i];
            push_local[i] = queue_error[i];
          end
        end else if (check_rf_i[i]) begin
          if (local_i[i]) begin
            if (!root_i[i]) begin
              set_remote[i]  = 1'b1;
              push_remote[i] = (bypass_remote[i] | present_remote[i]) & ~barrier_rf_error[i];
              push_local[i]  = barrier_rf_error[i];
            end else begin
              check_local[i] = 1'b1;
              push_local[i]  = bypass_local[i] | present_local[i] | barrier_rf_error[i];
            end
          end else begin
            set_remote[i] = 1'b1;
          end
        end
        if (grant_queue[i]) begin
          if (br_out[i][0]) push_ws_queue[i] = 1'b1;
          else              push_en_queue[i] = 1'b1;      
        end
      end
    end
    for (genvar i = 0; i < N_TX_PORTS; i++) begin: gen_tx_logic
      always_comb begin
        check_remote[i+N_RX_PORTS] = 1'b0;
        set_remote[i+N_RX_PORTS]   = 1'b0;
        sd_in[i+N_RX_PORTS]        = '0;
        en_br_o[i]                 = 1'b0;
        ws_br_o[i]                 = 1'b0;

        if (check_aggr_i[i]) begin
          {ws_br_o[i], en_br_o[i]} = rsp_i[i].sig.aggr[LVL_OFFSET] ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EAST_NORTH;
        end else if (check_br_i[i]) begin
          check_remote[i+N_RX_PORTS] = 1'b1;
          {ws_br_o[i], en_br_o[i]}   = barrier_rf_error[i+N_RX_PORTS] ? '0 : sd_out[i+N_RX_PORTS];
        end
      end
    end
  end else if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_logic
    for (genvar i = 0; i < N_1D_RX_PORTS; i++) begin: gen_h_rx_logic
      always_comb begin
        lock_queue[2*i]       = 1'b0
        free_queue[2*i]       = 1'b0
        check_local[2*i]      = 1'b0;
        check_remote[2*i]     = 1'b0;
        set_remote[2*i]       = 1'b0;
        sd_in[2*i]            = i%2 ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EAST_NORTH;
        br_in[2*i]            = '0;
        push_local[2*i]       = 1'b0;
        push_remote[2*i]      = 1'b0;
        push_en_queue[2*i]    = 1'b0;
        push_ws_queue[2*i]    = 1'b0;
        propagate_lock_o[2*i] = 1'b0;

        if (lock_req[2*i]) begin
          if (!local_queue[2*i]) begin
            propagate_lock_o[2*i] = 1'b1;
          end else begin
            br_in[2*i]      = req_i[2*i].sig.aggr;
            lock_queue[2*i] = lock_i[2*i];
            free_queue[2*i] = free_i[2*i];
            push_local[2*i] = queue_error[2*i];
          end
        end else if (check_rf_i[2*i]) begin
          if (local_i[2*i]) begin
            if (!root_i[2*i]) begin
              set_remote[2*i]  = 1'b1;
              push_remote[2*i] = (bypass_remote[2*i] | present_remote[2*i]) & ~barrier_rf_error[2*i];
              push_local[2*i]  = barrier_rf_error[2*i];
            end else begin
              check_local[2*i] = 1'b1;
              push_local[2*i]  = bypass_local[2*i] | present_local[2*i] | barrier_rf_error[2*i];
            end
          end else begin
            set_remote[2*i] = 1'b1;
          end
        end
        if (grant_queue[2*i]) begin
          if (br_out[2*i][0]) push_ws_queue[2*i] = 1'b1;
          else                push_en_queue[2*i] = 1'b1;      
        end
      end
    end
    for (genvar i = 0; i < N_1D_TX_PORTS; i++) begin: gen_h_tx_logic
      always_comb begin
        check_remote[2*i+N_RX_PORTS] = 1'b0;
        set_remote[2*i+N_RX_PORTS]   = 1'b0;
        sd_in[2*i+N_RX_PORTS]        = '0;
        en_br_o[2*i]                 = 1'b0;
        ws_br_o[2*i]                 = 1'b0;

        if (check_aggr_i[2*i]) begin
          {ws_br_o[2*i], en_br_o[2*i]} = rsp_i[2*i].sig.aggr[LVL_OFFSET] ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EAST_NORTH;
        end else if (check_br_i[2*i]) begin
          check_remote[2*i+N_RX_PORTS] = 1'b1;
          {ws_br_o[2*i], en_br_o[2*i]} = barrier_rf_error[2*i+N_RX_PORTS] ? '0 : sd_out[2*i+N_RX_PORTS];
        end
      end
    end
    for (genvar i = 0; i < N_1D_RX_PORTS; i++) begin: gen_v_rx_logic
      always_comb begin
        lock_queue[2*i+1]       = 1'b0;
        free_queue[2*i+1]       = 1'b0;
        check_local[2*i+1]      = 1'b0;
        check_remote[2*i+1]     = 1'b0;
        set_remote[2*i+1]       = 1'b0;
        sd_in[2*i+1]            = i%2 ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EAST_NORTH;
        br_in[2*i+1]            = '0;
        push_local[2*i+1]       = 1'b0;
        push_remote[2*i+1]      = 1'b0;
        push_en_queue[2*i+1]    = 1'b0;
        push_ws_queue[2*i+1]    = 1'b0;
        propagate_lock_o[2*i+1] = 1'b0;

        if (lock_req[2*i+1]) begin
          if (!local_queue[2*i+1]) begin
            propagate_lock_o[2*i+1] = 1'b1;
          end else begin
            br_in[2*i+1]      = req_i[2*i+1].sig.aggr;
            lock_queue[2*i+1] = lock_i[2*i+1];
            free_queue[2*i+1] = free_i[2*i+1];
            push_local[2*i+1] = queue_error[2*i+1];
          end
        end else if (check_rf_i[2*i+1]) begin
          if (local_i[2*i+1]) begin
            if (!root_i[2*i+1]) begin
              set_remote[2*i+1]  = 1'b1;
              push_remote[2*i+1] = (bypass_remote[2*i+1] | present_remote[2*i+1]) & ~barrier_rf_error[2*i+1];
              push_local[2*i+1]  = barrier_rf_error[2*i+1];
            end else begin
              check_local[2*i+1] = 1'b1;
              push_local[2*i+1]  = bypass_local[2*i+1] | present_local[2*i+1] | barrier_rf_error[2*i+1];
            end
          end else begin
            set_remote[2*i+1] = 1'b1;
          end
        end
        if (grant_queue[2*i+1]) begin
          if (br_out[2*i+1][0]) push_ws_queue[2*i+1] = 1'b1;
          else                  push_en_queue[2*i+1] = 1'b1;      
        end
      end
    end
    for (genvar i = 0; i < N_1D_TX_PORTS; i++) begin: gen_v_tx_logic
      always_comb begin
        check_remote[2*i+1+N_RX_PORTS] = 1'b0;
        set_remote[2*i+1+N_RX_PORTS]   = 1'b0;
        sd_in[2*i+1+N_RX_PORTS]        = '0;
        en_br_o[2*i+1]                 = 1'b0;
        ws_br_o[2*i+1]                 = 1'b0;

        if (check_aggr_i[2*i+1]) begin
          {ws_br_o[2*i+1], en_br_o[2*i+1]} = rsp_i[2*i+1].sig.aggr[LVL_OFFSET] ? fractal_sync_pkg::SD_WEST_SOUTH : fractal_sync_pkg::SD_EAST_NORTH;
        end else if (check_br_i[2*i+1]) begin
          check_remote[2*i+1+N_RX_PORTS]   = 1'b1;
          {ws_br_o[2*i+1], en_br_o[2*i+1]} = barrier_rf_error[2*i+1+N_RX_PORTS] ? '0 : sd_out[2*i+1+N_RX_PORTS];
        end
      end  
    end
  end else $fatal("Unsupported Register File Dimension");

/*******************************************************/
/**                 Control Logic End                 **/
/*******************************************************/
/**              Register File Beginning              **/
/*******************************************************/

  if (RF_DIM == fractal_sync_pkg::RF1D) begin: gen_1d_rf
    fractal_sync_1d_rf #(
      .REMOTE_RF_TYPE  ( RF_TYPE             ),
      .EN_REMOTE_RF    ( EN_REMOTE_RF        ),
      .N_QUEUE_REGS    ( N_QUEUE_REGS        ),
      .QUEUE_DEPTH     ( QUEUE_DEPTH         ),
      .N_LOCAL_REGS    ( N_LOCAL_REGS        ),
      .LEVEL_WIDTH     ( LEVEL_WIDTH         ),
      .ID_WIDTH        ( ID_WIDTH            ),
      .N_REMOTE_LINES  ( N_REMOTE_LINES      ),
      .br_pattern_t    ( aggr_t              ),
      .QUEUE_COMB_FIFO ( QUEUE_FIFO_COMB_OUT ),
      .N_LOCAL_PORTS   ( N_RX_PORTS          ),
      .N_REMOTE_PORTS  ( N_PORTS             )
    ) i_rf (
      .clk_i                              ,
      .rst_ni                             ,
      .level_i          ( level          ),
      .id_i             ( id             ),
      .sd_remote_i      ( sd_in          ),
      .br_queue_i       ( br_in          ),
      .lock_queue_i     ( lock_queue     ),
      .free_queue_i     ( free_queue     ),
      .check_local_i    ( check_local    ),
      .check_remote_i   ( check_remote   ),
      .set_remote_i     ( set_remote     ),
      .grant_queue_o    ( grant_queue    ),
      .present_local_o  ( present_local  ),
      .present_remote_o ( present_remote ),
      .sd_remote_o      ( sd_out         ),
      .br_queue_o       ( br_out         ),
      .id_err_o         ( id_error       ),
      .sig_err_o        ( sig_error      ),
      .queue_err_o      ( queue_error    ),
      .bypass_local_o   ( bypass_local   ),
      .bypass_remote_o  ( bypass_remote  ),
      .ignore_local_o   (                ),
      .ignore_remote_o  (                )
    );
  end else if (RF_DIM == fractal_sync_pkg::RF2D) begin: gen_2d_rf
    fractal_sync_2d_rf #(
      .REMOTE_RF_TYPE   ( RF_TYPE             ),
      .EN_REMOTE_RF     ( EN_REMOTE_RF        ),
      .N_QUEUE_REGS     ( N_QUEUE_REGS        ),
      .QUEUE_DEPTH      ( QUEUE_DEPTH         ),
      .N_LOCAL_REGS     ( N_LOCAL_REGS        ),
      .LEVEL_WIDTH      ( LEVEL_WIDTH         ),
      .ID_WIDTH         ( ID_WIDTH            ),
      .N_REMOTE_LINES   ( N_REMOTE_LINES      ),
      .br_pattern_t     ( aggr_t              ),
      .QUEUE_COMB_FIFO  ( QUEUE_FIFO_COMB_OUT ),
      .N_LOCAL_H_PORTS  ( N_1D_RX_PORTS       ),
      .N_LOCAL_V_PORTS  ( N_1D_RX_PORTS       ),
      .N_REMOTE_H_PORTS ( N_1D_PORTS          ),
      .N_REMOTE_V_PORTS ( N_1D_PORTS          )
    ) i_rf (
      .clk_i                                  ,
      .rst_ni                                 ,
      .level_h_i          ( h_level          ),
      .id_h_i             ( h_id             ),
      .sd_h_remote_i      ( h_sd_in          ),
      .br_h_queue_i       ( h_br_in          ),
      .lock_h_queue_i     ( h_lock_queue     ),
      .free_h_queue_i     ( h_free_queue     ),
      .check_h_local_i    ( h_check_local    ),
      .check_h_remote_i   ( h_check_remote   ),
      .set_h_remote_i     ( h_set_remote     ),
      .h_grant_queue_o    ( h_grant_queue    ),
      .h_present_local_o  ( h_present_local  ),
      .h_present_remote_o ( h_present_remote ),
      .h_sd_remote_o      ( h_sd_out         ),
      .h_br_queue_o       ( h_br_out         ),
      .h_id_err_o         ( h_id_error       ),
      .h_sig_err_o        ( h_sig_error      ),
      .h_queue_err_o      ( h_queue_error    ),
      .h_bypass_local_o   ( h_bypass_local   ),
      .h_bypass_remote_o  ( h_bypass_remote  ),
      .h_ignore_local_o   (                  ),
      .h_ignore_remote_o  (                  ),
      .level_v_i          ( v_level          ),
      .id_v_i             ( v_id             ),
      .sd_v_remote_i      ( v_sd_in          ),
      .br_v_queue_i       ( v_br_in          ),
      .lock_v_queue_i     ( v_lock_queue     ),
      .free_v_queue_i     ( v_free_queue     ),
      .check_v_local_i    ( v_check_local    ),
      .check_v_remote_i   ( v_check_remote   ),
      .set_v_remote_i     ( v_set_remote     ),
      .v_grant_queue_o    ( v_grant_queue    ),
      .v_present_local_o  ( v_present_local  ),
      .v_present_remote_o ( v_present_remote ),
      .v_sd_remote_o      ( v_sd_out         ),
      .v_br_queue_o       ( v_br_out         ),
      .v_id_err_o         ( v_id_error       ),
      .v_sig_err_o        ( v_sig_error      ),
      .v_queue_err_o      ( v_queue_error    ),
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
    assign empty_local_fifo_err[i]    = local_empty_o[i] & local_pop_i[i];
    assign full_local_fifo_err[i]     = full_local[i] & push_local[i];
    assign empty_remote_fifo_err[i]   = remote_empty_o[i] & remote_pop_i[i];
    assign full_remote_fifo_err[i]    = full_remote[i] & push_remote[i];
    assign empty_en_queue_fifo_err[i] = en_queue_empty_o[i] & en_queue_pop_i[i];
    assign full_en_queue_fifo_err[i]  = full_en_queue[i] & push_en_queue[i];
    assign empty_ws_queue_fifo_err[i] = ws_queue_empty_o[i] & ws_queue_pop_i[i];
    assign full_ws_queue_fifo_err[i]  = full_ws_queue[i] & push_ws_queue[i];
    assign fifo_error[i]              = empty_local_fifo_err[i]    | full_local_fifo_err[i]    | 
                                        empty_remote_fifo_err[i]   | full_remote_fifo_err[i]   |
                                        empty_en_queue_fifo_err[i] | full_en_queue_fifo_err[i] |
                                        empty_ws_queue_fifo_err[i] | full_ws_queue_fifo_err[i];
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
      .FIFO_DEPTH ( FIFO_DEPTH          ),
      .fifo_t     ( fsync_rsp_t         ),
      .COMB_OUT   ( LOCAL_FIFO_COMB_OUT )
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
      .FIFO_DEPTH ( FIFO_DEPTH           ),
      .fifo_t     ( fsync_req_t          ),
      .COMB_OUT   ( REMOTE_FIFO_COMB_OUT )
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

  for (genvar i = 0; i < N_FIFOS; i++) begin: gen_en_queue_fifos
    fractal_sync_fifo #(
      .FIFO_DEPTH ( FIFO_DEPTH          ),
      .fifo_t     ( fsync_rsp_t         ),
      .COMB_OUT   ( QUEUE_FIFO_COMB_OUT )
    ) i_en_queue_fifo (
      .clk_i                            ,
      .rst_ni                           ,
      .push_i    ( push_en_queue[i]    ),
      .element_i ( queue_rsp[i]        ),
      .pop_i     ( en_queue_pop_i[i]   ),
      .element_o ( en_queue_rsp_o[i]   ),
      .empty_o   ( en_queue_empty_o[i] ),
      .full_o    ( full_en_queue[i]    )
    );
  end

  for (genvar i = 0; i < N_FIFOS; i++) begin: gen_ws_queue_fifos
    fractal_sync_fifo #(
      .FIFO_DEPTH ( FIFO_DEPTH          ),
      .fifo_t     ( fsync_rsp_t         ),
      .COMB_OUT   ( QUEUE_FIFO_COMB_OUT )
    ) i_ws_queue_fifo (
      .clk_i                            ,
      .rst_ni                           ,
      .push_i    ( push_ws_queue[i]    ),
      .element_i ( queue_rsp[i]        ),
      .pop_i     ( ws_queue_pop_i[i]   ),
      .element_o ( ws_queue_rsp_o[i]   ),
      .empty_o   ( ws_queue_empty_o[i] ),
      .full_o    ( full_ws_queue[i]    )
    );
  end

/*******************************************************/
/**                     FIFOs End                     **/
/*******************************************************/

endmodule: fractal_sync_cc