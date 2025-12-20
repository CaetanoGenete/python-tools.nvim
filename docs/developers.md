# Developers

## Dev dependencies

- [cmake](https://cmake.org/)
- [luarocks](https://luarocks.org/)
- [stylua](https://github.com/JohnnyMorganz/StyLua)
- [uv](https://astral.sh/uv/)
- [lua-language-server](https://luals.github.io/)
- [busted](https://lunarmodules.github.io/busted/)
- [tree-sitter-cli](https://tree-sitter.github.io/tree-sitter/) (If on windows)

To get started, simply run `make develop` and the environment should be setup
accordingly.

## Dockerfile

There is a simple dockerfile defined at the root of this project that creates an
image with all necessary dependencies. You may use it as a dev-container, or
otherwise as a test environmet by simply running:

```bash
make dev-container
```

Or:

```bash
docker build -t pytools .
docker run -it pytools
```

To ensure everything is ok, it's a good idea to try running the tests when first
building the image. The [next section](#executing-tests) covers this.

## Executing tests

You may execute tests using the busted provided script:

```bash
busted
```

Using luarocks (Which calls busted for you):

```bash
luarocks test
```

Or through make (Which also calls busted for you, but handles other
dependencies):

```bash
make test # Or make test-all
```
