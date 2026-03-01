BUSTED_PROFILE?=default

MINIMAL_INIT:=scripts/minimal_init.lua
RC_PATH:=.luarc.json

BUILD_PATH:=build
INSTALL_PATH:=lib

PARSER_VERSION=v0.25.0
PARSER_CLONE_PATH:=.tree-sitter-python
PARSER_BUILD_PATH:=build-ts
PARSER_INSTALL_PATH:=$(PARSER_BUILD_PATH)/install

LLS_PLUGINS_DIR:=.plugins/

MOCK_REPO_DIR:=test/fixtures/mock-repo/

ifeq ($(OS),Windows_NT)
	RMDIR:=rmdir /s /q
	RM:=del /f /q
else
	RMDIR:=rm -rf
	RM:=rm -f
endif

### clib targets

$(BUILD_PATH):
	cmake -S . -B $@ -DCMAKE_BUILD_TYPE=release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DBUILD_REDIRECTLIB=ON

.PHONY: compile
compile: $(BUILD_PATH)
	cmake --build $(BUILD_PATH) --config release
	cmake --install $(BUILD_PATH) --prefix $(INSTALL_PATH)

### ts parser targets

$(PARSER_CLONE_PATH):
	git clone --depth 1 --branch=$(PARSER_VERSION) https://github.com/tree-sitter/tree-sitter-python.git $@

$(PARSER_BUILD_PATH): $(PARSER_CLONE_PATH)
	cmake -S $(PARSER_CLONE_PATH) -B $@ -DCMAKE_BUILD_TYPE=release
	cmake --build $(PARSER_BUILD_PATH) --config release
	cmake --install $(PARSER_BUILD_PATH) --prefix $(PARSER_INSTALL_PATH)

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

.PHONY: test-all
test-all: compile $(PARSER_BUILD_PATH)
	tox run-parallel

### Dev targets

.PHONY: develop
develop: $(RC_PATH) compile $(PARSER_BUILD_PATH)

.PHONY: format
format:
	stylua .

.PHONY: test-dev
test-dev: develop check-types check-formatting
	tox -e 3.12

.PHONY: dev-container
dev-container:
	docker build -t pytools .
	docker run --rm -it pytools

### clean

clean:
	-$(RMDIR) $(BUILD_PATH)
	-$(RMDIR) $(PARSER_BUILD_PATH)
	-$(RMDIR) $(INSTALL_PATH)
	-$(RMDIR) .tox
	-$(RM) $(RC_PATH)
