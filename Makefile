# ---------------------------------------------------------------------------
# Top-level Makefile.
#
# Auto-discovers every subdirectory (at any depth) that contains a
# Makefile including mk/common.mk, and forwards the standard targets to
# each of them. Running `make` at the repo root therefore exercises every
# project the same way CI does.
#
# A project is anywhere `make -C <dir>` would work. To register a new one,
# drop a Makefile that `include`s ../(../..)?/mk/common.mk — that's it.
# ---------------------------------------------------------------------------

# Find every Makefile under the tree that uses our shared rules. Marker:
# a literal `mk/common.mk` include. grep -l prints filenames only.
PROJECT_MAKEFILES := $(shell grep -rl --include=Makefile 'mk/common\.mk' . 2>/dev/null | \
                            grep -v '^\./Makefile$$' | sort)
PROJECTS := $(patsubst %/Makefile,%,$(PROJECT_MAKEFILES))

# Targets we forward to each project. Keep in sync with mk/common.mk.
FORWARDED_TARGETS := all analyze elaborate simulate diagram waveform clean

.PHONY: help list $(FORWARDED_TARGETS)

help:
	@echo "learning_fpga - top-level orchestration"
	@echo ""
	@echo "Discovered projects:"
	@for p in $(PROJECTS); do echo "  - $$p"; done
	@echo ""
	@echo "Targets (run against every project):"
	@echo "  all         simulate + diagram + waveform"
	@echo "  analyze     ghdl -a"
	@echo "  elaborate   ghdl -e"
	@echo "  simulate    ghdl -r (emits an FST)"
	@echo "  diagram     yosys + netlistsvg (emits an SVG)"
	@echo "  waveform    waveview render (emits an SVG + PNG)"
	@echo "  clean       remove every build/ directory"
	@echo ""
	@echo "Targeting a single project: make -C <project-dir> [target]"

list:
	@for p in $(PROJECTS); do echo $$p; done

$(FORWARDED_TARGETS):
	@set -e; for dir in $(PROJECTS); do \
	    echo "==> $$dir: make $@"; \
	    $(MAKE) -C $$dir $@; \
	done
