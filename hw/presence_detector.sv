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
 * Barrier - flag detector module, detects if all participants have raised thier flag
 * Asynchronous valid low reset
 *
 * Parameters:
 *  PARTICIPANTS - Number of signals that must be asserted
 *  COMB         - Indicates whether the output is combinationally/sequentially defined with respect to the input
 *                 1: combinational - output is asserted as soon as all partecipants are seen
 *                 0: sequential - output is asserted at the rising clock edge of the cycle all partecipants are seen
 *
 * Interface signals:
 *  > present_i     - Participant indicates that it is present, once this signal is asserted for one clock cycle
 *                    the participant can de-assert it in the next clock cycle, without waiting for the other participants
 *  < all_present_o - Indicates that all participants are present, is asserted for one clock cycle
 */

module presence_detector#(
  parameter int unsigned PARTICIPANTS = 0,
  parameter bit          COMB         = 0
)(
  input  logic                   clk_i,
  input  logic                   rstn_i,
  input  logic                   clear_i,
  input  logic[PARTICIPANTS-1:0] present_i,
  output logic                   all_present_o
);

  logic[PARTICIPANTS-1:0] participant_present_d, participant_present_q;

  assign participant_present_d = participant_present_q | present_i;

  always_ff @(posedge clk_i, negedge rstn_i) begin: participant_tracker
    if (!rstn_i)   participant_present_q <= '0;
    else begin
      if (clear_i) participant_present_q <= '0;
      else         participant_present_q <= participant_present_d;
    end
  end

  generate
    if (COMB) begin: gen_comb_pd
      assign all_present_o = &present_i ? &present_i : &participant_present_d;
    end else begin: gen_seq_pd
      assign all_present_o = &participant_present_q;
    end
  endgenerate

endmodule: presence_detector
