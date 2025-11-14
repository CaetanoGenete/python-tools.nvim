FROM ubuntu:22.04

# Install dependencies
RUN apt update && apt install -y cmake lua5.1 luarocks git \
	&& wget https://github.com/neovim/neovim-releases/releases/download/v0.11.4/nvim-linux-x86_64.appimage \
	&& chmod +x ./nvim-linux-x86_64.appimage \
	&& ./nvim-linux-x86_64.appimage --appimage-extract \
	&& cp -r ./squashfs-root/usr/* /usr/ \
	&& wget -qO- https://astral.sh/uv/install.sh | sh \
	&& /root/.local/bin/uv tool install git+https://github.com/johnnymorganz/stylua \
	&& wget -qO- https://github.com/LuaLS/lua-language-server/releases/download/3.15.0/lua-language-server-3.15.0-linux-x64.tar.gz | tar -xvz --one-top-level=lua-ls \
	&& cp -r ./lua-ls/* /usr/

ENV PATH=${PATH}:/root/.local/bin/

WORKDIR /home/project/

RUN --mount=type=bind,source=./python-tools.nvim-0.2-0.rockspec,target=./python-tools.nvim-0.2-0.rockspec \
	--mount=type=bind,source=./.busted,target=./.busted \
	--mount=type=bind,source=./scripts/minimal_init.lua,target=./scripts/minimal_init.lua \
	luarocks install --deps-only ./python-tools.nvim-0.2-0.rockspec \
	&& luarocks test --prepare ./python-tools.nvim-0.2-0.rockspec

COPY . .

RUN make develop
