.PHONY: test

supported-versions:=3.8 3.9 3.10 3.11 3.12 3.13

$(patsubst %, test-%, $(supported-versions)):
	uv sync -p $(subst test-,,$@) --project ./test/mock-repo/
	nvim --headless --noplugin -u scripts/minimal_init.lua -c "PlenaryBustedDirectory test { minimal_init = './scripts/minimal_init.lua' }"

test: $(patsubst %, test-%, $(supported-versions))

