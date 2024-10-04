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
 * Fractal synchronization transaction model
 */

import fractal_dv_pkg::*;

class sync_transaction;
  
  rand   int unsigned sync_level;
  rand   bit          transaction_error;
         int unsigned transaction_id;
  static int unsigned global_id = 0;

  function new();
  endfunction: new

  function automatic void set_uid();
    this.transaction_id = global_id++;
  endfunction: set_uid

  function automatic void update_error(bit error_bit);
    this.transaction_error |= error_bit;
  endfunction: update_error

  function automatic void scp(sync_transaction src);
    this.sync_level        = src.sync_level;
    this.transaction_error = src.transaction_error;
    this.transaction_id    = src.transaction_id;
  endfunction: scp

  function automatic void print();
    $display("-------------------------");
    $display("Fractal Sync transaction:");
    $display("TIME: %0t", $time);
    $display("ID: %0d (Global ID: %0d)", this.transaction_id, sync_transaction::global_id);
    $display("LEVEL: %0d", this.sync_level);
    $display("ERROR: %s", this.transaction_error == 1 ? "yes" : "no");
    $display("-------------------------\n");
  endfunction: print

endclass: sync_transaction
