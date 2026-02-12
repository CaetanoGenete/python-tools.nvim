BUSTED_PROFILE?=default

# Python versions to test against
SUPPORTED-VERSIONS:=3.8 3.9 3.10 3.11 3.12 3.13

MINIMAL_INIT:=./scripts/minimal_init.lua
RC_PATH:=.luarc.json

BUILD_PATH:=./build
INSTALL_PATH:=./lib/

PARSER_VERSION=v0.25.0
PARSER_CLONE_PATH:=./.tree-sitter-python/
PARSER_BUILD_PATH:=./build-ts
PARSER_INSTALL_PATH:=$(PARSER_BUILD_PATH)/install

LLS_PLUGINS_DIR = ./.plugins/

### clib targets

$(BUILD_PATH):
	cmake -S . -B $@ -DCMAKE_BUILD_TYPE=release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DBUILD_REDIRECTLIB=ON

# Note: Make 'compile' PHONY to ensure compilation always happens, CMAKE and
# its generators already handle caching
.PHONY: compile
compile: $(BUILD_PATH)
	cmake --build $(BUILD_PATH) --config release
	cmake --install $(BUILD_PATH) --prefix $(INSTALL_PATH)

### ts parser targets

$(PARSER_CLONE_PATH):
	git clone --depth 1 --branch=$(PARSER_VERSION) https://github.com/tree-sitter/tree-sitter-python.git $@

$(PARSER_BUILD_PATH): $(PARSER_CLONE_PATH)
	cmake -S $(PARSER_CLONE_PATH) -B $@ -DCMAKE_BUILD_TYPE=release
	cmake --build $@ --config release
	cmake --install $@ --prefix $(PARSER_INSTALL_PATH)

.PHONY: compile-parser
compile-parser: $(PARSER_BUILD_PATH)

### Lint targets

$(LLS_PLUGINS_DIR)/busted:
	git clone --depth 1 https://github.com/LuaCATS/busted.git $@

$(LLS_PLUGINS_DIR)/luassert:
	git clone --depth 1 https://github.com/LuaCATS/luassert.git $@

.PHONY: lls-addons
lls-addons: $(LLS_PLUGINS_DIR)/busted $(LLS_PLUGINS_DIR)/luassert

$(RC_PATH): lls-addons
	nvim --headless --clean -l ./scripts/gen-type-cheking-rcfile.lua > $@

.PHONY: check-types
check-types: $(RC_PATH)
	lua-language-server --check=. --checklevel=Hint --configpath=$(RC_PATH)

.PHONY: check-formatting
check-formatting:
	stylua -c .

### Test targets

PYENV_TARGETS:=$(patsubst %, pyenv-%, $(SUPPORTED-VERSIONS))

.PHONY: $(PYENV_TARGETS)
$(PYENV_TARGETS):
	uv sync -p $(subst pyenv-,,$@) --project ./test/fixtures/mock-repo/

TEST_TARGETS:=$(patsubst %, test-%, $(SUPPORTED-VERSIONS))

.PHONY: $(TEST_TARGETS)
$(TEST_TARGETS): test-%: pyenv-% compile $(PARSER_BUILD_PATH)
	busted --run=$(BUSTED_PROFILE)

.PHONY: test-all
test-all: $(TEST_TARGETS)

### Dev targets

.PHONY: develop
develop: $(RC_PATH) pyenv-3.12 compile compile-parser

.PHONY: test-dev
test-dev: develop check-types check-formatting test-3.12

.PHONY: dev-container
dev-container:
	docker build -t pytools .
	docker run -it pytools
