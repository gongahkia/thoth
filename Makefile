.PHONY: run smoke test check package clean

LOVE ?= love
LUAJIT ?= luajit
PACKAGE := dist/thoth.love

run:
	$(LOVE) .

smoke:
	$(LOVE) . --smoke

test:
	$(LUAJIT) tests/run.lua

check: test
	$(LUAJIT) tests/assets.lua
	$(LUAJIT) tests/registry.lua

package: check
	mkdir -p dist
	rm -f $(PACKAGE)
	zip -9 -r $(PACKAGE) main.lua conf.lua src assets README.md docs "to do.md" -x "assets/previews/*" "assets/replays/*"
	zip -T $(PACKAGE)

clean:
	rm -rf dist
