BENDER_DIR ?= .
BENDER     ?= ./bender
QUESTA     ?= questa-2023.4

compile_script ?= compile_fsync.tcl

bender_targs += -t dv

tb_top ?= tb_bfm

.PHONY: bender compile_script start_sim

bender:
	curl --proto '=https'                                                        \
	--tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh -s -- 0.28.1 \
	$(BENDER) update

compile_script:
	$(BENDER) script vsim $(bender_targs) > ${compile_script}

start_sim:
	$(QUESTA) vsim -do "source ${compile_script}" -do "vsim work.$(tb_top) -voptargs=+acc"

clear:
	rm -fr ${compile_script} \
	rm -fr work/
