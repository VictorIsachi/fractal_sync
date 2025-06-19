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
  rand   bit[31:0]    sync_aggregate;
  rand   int unsigned sync_barrier_id; 

         int unsigned transaction_id;
  static int unsigned global_id = 0;
         time         transaction_time;

  constraint aggregate_range { 2**(sync_level-1) > sync_aggregate; }

  function new();
  endfunction: new

  function automatic void set_uid();
    this.transaction_id = global_id++;
  endfunction: set_uid

  function automatic void scp(sync_transaction src);
    this.sync_level      = src.sync_level;
    this.sync_aggregate  = src.sync_aggregate;
    this.sync_barrier_id = src.sync_barrier_id;
    this.transaction_id  = src.transaction_id;
  endfunction: scp

  function automatic void set(int unsigned lvl, bit[31:0] aggr, int unsigned id);
    this.sync_level      = lvl;
    this.sync_aggregate  = aggr;
    this.sync_barrier_id = id;
  endfunction: set

  function automatic void print();
    $display("-------------------------");
    $display("FractalSync transaction:");
    $display("TIME: %0t (Transaction time %0t)", $time, transaction_time);
    $display("ID: %0d (Global ID: %0d)", this.transaction_id, sync_transaction::global_id);
    $display("LEVEL: %0d", this.sync_level);
    $display("AGGREGATE: 0b%0b", this.sync_aggregate);
    $display("AGGR. Field: 0b%0b", 1'b1 << this.sync_level-1 | this.sync_aggregate);
    $display("ID Field: %0d", this.sync_barrier_id);
    $display("-------------------------");
  endfunction: print

endclass: sync_transaction
