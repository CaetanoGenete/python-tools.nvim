BUSTED_PROFILE?=default

SUPPORTED-VERSIONS:=3.8 3.9 3.10 3.11 3.12 3.13
TEST-ENVS:=$(patsubst %, test-%, $(SUPPORTED-VERSIONS))

MINIMAL_INIT:=./scripts/minimal_init.lua
RC_PATH:=.luarc.json

BUILD_PATH:=./build
INSTALL_PATH:=$(BUILD_PATH)/install

PARSER_BUILD_PATH:=./build-ts
PARSER_INSTALL_PATH:=$(PARSER_BUILD_PATH)/install

$(RC_PATH):
	nvim --headless --clean -l ./scripts/gen-type-cheking-rcfile.lua > $(RC_PATH)

$(BUILD_PATH):
	cmake -S . -B $(BUILD_PATH) -DCMAKE_BUILD_TYPE=release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

.PHONY: compile
compile: $(BUILD_PATH)
	cmake --build $(BUILD_PATH) --config release
	cmake --install $(BUILD_PATH) --prefix $(INSTALL_PATH)

$(PARSER_BUILD_PATH):
	cmake -S ./tree-sitter-python/ -B $(PARSER_BUILD_PATH) -DCMAKE_BUILD_TYPE=release

.PHONY: compile-parser
compile-parser: $(PARSER_BUILD_PATH)
	cmake --build $(PARSER_BUILD_PATH) --config release
	cmake --install $(PARSER_BUILD_PATH) --prefix $(PARSER_INSTALL_PATH)

.PHONY: develop
develop: $(RC_PATH) compile compile-parser

.PHONY: type-check
type-check: $(RC_PATH)
	lua-language-server --check=. --checklevel=Hint --configpath=$(RC_PATH)

.PHONY: check-formatting
check-formatting:
	stylua -c .

.PHONY: $(TEST-ENVS)
$(TEST-ENVS):
	uv sync -p $(subst test-,,$@) --project ./test/fixtures/mock-repo/
	busted --run=$(BUSTED_PROFILE)

.PHONY: test
test: $(TEST-ENVS)

.PHONY: test-dev
test-dev: type-check check-formatting test-3.12
