SUPPORTED-VERSIONS:=3.8 3.9 3.10 3.11 3.12 3.13
TEST-ENVS:=$(patsubst %, test-%, $(SUPPORTED-VERSIONS))

MINIMAL_INIT:=./scripts/minimal_init.lua
RC_PATH:=.luarc-ci.json

# Targets: test-{version}
.PHONY: $(TEST-ENVS)
$(TEST-ENVS):
	uv sync -p $(subst test-,,$@) --project ./test/fixtures/mock-repo/
	nvim --headless --noplugin -u $(MINIMAL_INIT)  -c "PlenaryBustedDirectory test { minimal_init = '$(MINIMAL_INIT)' }"

.PHONY: test
test: $(TEST-ENVS)

.PHONY: type-check
type-check:
	nvim --headless --noplugin -u $(MINIMAL_INIT) -l ./scripts/gen-type-cheking-rcfile.lua > $(RC_PATH)
	lua-language-server --check=. --configpath=$(RC_PATH)

.PHONY: check-formatting
check-formatting:
	stylua -c .

.PHONY: test-dev
test-dev: type-check check-formatting test-3.12

