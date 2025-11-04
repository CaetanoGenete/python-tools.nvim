SUPPORTED-VERSIONS:=3.8 3.9 3.10 3.11 3.12 3.13
TEST-ENVS:=$(patsubst %, test-%, $(SUPPORTED-VERSIONS))

MINIMAL_INIT:=./scripts/minimal_init.lua
RC_PATH:=.luarc.json

# Targets: test-{version}
.PHONY: $(TEST-ENVS)
$(TEST-ENVS):
	uv sync -p $(subst test-,,$@) --project ./test/fixtures/mock-repo/
	busted

.PHONY: test
test: $(TEST-ENVS)

$(RC_PATH):
	nvim --headless --clean -l ./scripts/gen-type-cheking-rcfile.lua > $(RC_PATH)

.PHONY: type-check
type-check: $(RC_PATH)
	lua-language-server --check=. --checklevel=Hint --configpath=$(RC_PATH)

.PHONY: check-formatting
check-formatting:
	stylua -c .

.PHONY: test-dev
test-dev: type-check check-formatting test-3.12

