BUSTED_PROFILE?=default

# Python versions to test against
SUPPORTED-VERSIONS:=3.8 3.9 3.10 3.11 3.12 3.13

MINIMAL_INIT:=./scripts/minimal_init.lua
RC_PATH:=.luarc.json

BUILD_PATH:=./build
INSTALL_PATH:=./lib/

PARSER_BUILD_PATH:=./build-ts
PARSER_INSTALL_PATH:=$(PARSER_BUILD_PATH)/install

### Cmake targets

$(BUILD_PATH):
	cmake -S . -B $(BUILD_PATH) -DCMAKE_BUILD_TYPE=release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DBUILD_REDIRECTLIB=ON

# Note: Make 'compile' PHONY to ensure compilation always happens, CMAKE and
# its generators already handle caching
.PHONY: compile
compile: $(BUILD_PATH)
	cmake --build $(BUILD_PATH) --config release
	cmake --install $(BUILD_PATH) --prefix $(INSTALL_PATH)

$(PARSER_BUILD_PATH):
	cmake -S ./tree-sitter-python/ -B $(PARSER_BUILD_PATH) -DCMAKE_BUILD_TYPE=release

# Note: Make 'compile' PHONY to ensure compilation always happens, CMAKE and
# its generators already handle caching
.PHONY: compile-parser
compile-parser: $(PARSER_BUILD_PATH)
	cmake --build $(PARSER_BUILD_PATH) --config release
	cmake --install $(PARSER_BUILD_PATH) --prefix $(PARSER_INSTALL_PATH)

### Lint targets

$(RC_PATH):
	nvim --headless --clean -l ./scripts/gen-type-cheking-rcfile.lua > $(RC_PATH)

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
$(TEST_TARGETS): test-%: pyenv-% compile compile-parser
	busted --run=$(BUSTED_PROFILE)

.PHONY: test
test: test-3.12

.PHONY: test-all
test-all: $(TEST_TARGETS)

### Dev targets

.PHONY: develop
develop: $(RC_PATH) pyenv-3.8 compile compile-parser

.PHONY: test-dev
test-dev: check-types check-formatting test

.PHONY: dev-container
dev-container:
	docker build -t pytools .
	docker run -it pytools
