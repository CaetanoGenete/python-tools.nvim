.PHONY: test clean

SUPPORTED-VERSIONS:=3.8 3.9 3.10 3.11 3.12 3.13
MINIMAL_INIT:=./scripts/minimal_init.lua

# Targets: test-{version}
$(patsubst %, test-%, $(SUPPORTED-VERSIONS)):
	uv sync -p $(subst test-,,$@) --project ./test/fixtures/mock-repo/
	nvim --headless --noplugin -u $(MINIMAL_INIT)  -c "PlenaryBustedDirectory test { minimal_init = '$(MINIMAL_INIT)' }"

test: $(patsubst %, test-%, $(SUPPORTED-VERSIONS))

RC_PATH:=.luarc-ci.json

type-check:
	nvim --headless --noplugin -u $(MINIMAL_INIT) -l ./scripts/gen-type-cheking-rcfile.lua > $(RC_PATH)
	lua-language-server --check=. --configpath=$(RC_PATH)

test-dev: test-3.12 | type-check
