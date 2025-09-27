SUPPORTED-VERSIONS:=3.8 3.9 3.10 3.11 3.12 3.13

MINIMAL_INIT:=./scripts/minimal_init.lua
RC_PATH:=.luarc-ci.json

# Targets: test-{version}
.PHONY: $(patsubst %, test-%, $(SUPPORTED-VERSIONS))
$(patsubst %, test-%, $(SUPPORTED-VERSIONS)):
	uv sync -p $(subst test-,,$@) --project ./test/fixtures/mock-repo/
	nvim --headless --noplugin -u $(MINIMAL_INIT)  -c "PlenaryBustedDirectory test { minimal_init = '$(MINIMAL_INIT)' }"

.PHONY: test
test: $(patsubst %, test-%, $(SUPPORTED-VERSIONS))

.PHONY: type-check
type-check:
	nvim --headless --noplugin -u $(MINIMAL_INIT) -l ./scripts/gen-type-cheking-rcfile.lua > $(RC_PATH)
	lua-language-server --check=. --configpath=$(RC_PATH)

.PHONY: test-dev
test-dev: test-3.12 type-check
