/*
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Base test
class riscv_instr_base_test extends uvm_test;

  riscv_instr_gen_config  cfg;
  string                  test_opts;
  string                  asm_file_name = "riscv_asm_test";
  riscv_asm_program_gen   asm_gen;
  string                  instr_seq;

  `uvm_component_utils(riscv_instr_base_test)

  function new(string name="", uvm_component parent=null);
    super.new(name, parent);
    void'($value$plusargs("asm_file_name=%0s", asm_file_name));
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = riscv_instr_gen_config::type_id::create("cfg");
    uvm_config_db#(riscv_instr_gen_config)::set(null, "*", "instr_cfg", cfg);
    if(cfg.asm_test_suffix != "")
      asm_file_name = {asm_file_name, ".", cfg.asm_test_suffix};
    // Override the default riscv instruction sequence
    if($value$plusargs("instr_seq=%0s", instr_seq)) begin
      uvm_coreservice_t coreservice = uvm_coreservice_t::get();
      uvm_factory factory = coreservice.get_factory();
      factory.set_type_override_by_name("riscv_instr_sequence", instr_seq);
    end
  endfunction

  function void report_phase(uvm_phase phase);
    uvm_report_server rs;
    int error_count;

    rs = uvm_report_server::get_server();

    error_count = rs.get_severity_count(UVM_WARNING) +
                  rs.get_severity_count(UVM_ERROR) +
                  rs.get_severity_count(UVM_FATAL);

    if (error_count == 0) begin
      `uvm_info("", "TEST PASSED", UVM_NONE);
    end else begin
      `uvm_info("", "TEST FAILED", UVM_NONE);
    end
    super.report_phase(phase);
  endfunction

  function void get_directed_instr_stream_opts();
    string instr_name;
    int ratio;
    string cmd_opts_prefix;
    int i = 0;
    while(1) begin
      cmd_opts_prefix = $sformatf("directed_instr_%0d", i);
      if($value$plusargs({cmd_opts_prefix, "=%0s"}, instr_name) &&
         $value$plusargs({cmd_opts_prefix, "_ratio=%0d"}, ratio)) begin
        asm_gen.add_directed_instr_stream(instr_name, ratio);
      end else begin
        break;
      end
      `uvm_info(`gfn, $sformatf("Got directed instr[%0d] %0s, ratio = %0d/1000",
                                 i, instr_name, ratio), UVM_LOW)
      i++;
    end

  endfunction

  virtual function void apply_directed_instr();
  endfunction

  task run_phase(uvm_phase phase);
    int fd;
    for(int i = 0; i < cfg.num_of_tests; i++) begin
      string test_name;
      cfg = riscv_instr_gen_config::type_id::create("cfg");
      randomize_cfg();
      asm_gen = riscv_asm_program_gen::type_id::create("asm_gen");
      get_directed_instr_stream_opts();
      asm_gen.cfg = cfg;
      test_name = $sformatf("%0s.%0d.S", asm_file_name, i);
      apply_directed_instr();
      `uvm_info(`gfn, "All directed instruction is applied", UVM_LOW)
      asm_gen.gen_program();
      asm_gen.gen_test_file(test_name);
    end
  endtask

  virtual function void randomize_cfg();
    `DV_CHECK_RANDOMIZE_FATAL(cfg);
    `uvm_info(`gfn, $sformatf("riscv_instr_gen_config is randomized:\n%0s",
                    cfg.sprint()), UVM_LOW)
  endfunction

endclass
