PYTHON_VERSION ?= 3.12
UV_PROJECT_ENVIRONMENT ?= ./test/fixtures/mock-repo/.venv

MINIMAL_INIT:=./scripts/minimal_init.lua
RC_PATH:=.luarc-ci.json

${UV_PROJECT_ENVIRONMENT}:
	uv sync -p ${PYTHON_VERSION} --project ./test/fixtures/mock-repo/

.PHONY: test
test: ${UV_PROJECT_ENVIRONMENT}
	nvim --headless --noplugin -u $(MINIMAL_INIT)  -c "PlenaryBustedDirectory test { minimal_init = '$(MINIMAL_INIT)' }"

.PHONY: type-check
type-check:
	nvim --headless --noplugin -u $(MINIMAL_INIT) -l ./scripts/gen-type-cheking-rcfile.lua > $(RC_PATH)
	lua-language-server --check=. --configpath=$(RC_PATH)

.PHONY: check-formatting
check-formatting:
	stylua -c .

.PHONY: test-dev
test-dev: type-check check-formatting test

