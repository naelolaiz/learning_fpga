# Tiny RV32I assembler — Python tool, no HDL flow.
#
# This project deliberately does NOT pull in the shared HDL build
# rules: the auto-discovery step in .github/workflows/ci.yml greps
# Makefiles for the shared-rules include (the very string this
# comment must therefore avoid) and would otherwise feed this
# directory into the matrix as if it were an HDL design.
#
# The CI integration for this assembler is indirect — the committed
# programs/*.hex files are the source of truth that the upcoming
# CPU testbenches load into IMEM. Running `make test` re-assembles
# each .S program and asserts the output matches the committed .hex,
# so any change to the assembler that would silently shift the
# programs is caught here.

PROJECT_NAME := rv32_asm

PROGRAMS := $(wildcard programs/*.S)
BUILD    := build

PYTHON   ?= python3

.PHONY: help test golden clean

help:
	@echo "Project: $(PROJECT_NAME)"
	@echo "Targets:"
	@echo "  test    run the assembler unittests + re-assemble each program"
	@echo "          and diff against its committed .hex (default)"
	@echo "  golden  regenerate the committed programs/*.hex files from the"
	@echo "          current rv32_asm.py — review the diff before committing"
	@echo "  clean   remove build/"

# Default target = run the unittest suite. The suite covers both
# per-instruction encoding (hand-encoded vectors) and the
# golden-file equivalence for every program in programs/.
test:
	$(PYTHON) -m unittest discover -v -s test

# Regenerate the golden .hex files from the current rv32_asm.py.
# Use this when you've intentionally changed the assembler and want
# the .hex files to track. Inspect the resulting diff before
# committing.
golden:
	@for s in $(PROGRAMS); do \
	  out=$${s%.S}.hex ; \
	  echo "$$s -> $$out" ; \
	  $(PYTHON) rv32_asm.py "$$s" -o "$$out" ; \
	done

clean:
	@rm -rf $(BUILD)
