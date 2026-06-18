.PHONY: run smoke test check benchmark benchmark-smoke benchmark-scaled package-build package clean

LOVE ?= love
LUAJIT ?= luajit
PACKAGE := dist/thoth.love
PACKAGE_INPUTS := main.lua conf.lua src assets TODO.md docs

run:
	$(LOVE) .

smoke:
	$(LOVE) . --smoke

test:
	$(LUAJIT) tests/run.lua

check: test
	$(LUAJIT) tests/replays.lua
	$(LUAJIT) tests/assets.lua
	$(LUAJIT) tests/registry.lua
	$(MAKE) package-build
	$(LUAJIT) tests/package.lua $(PACKAGE)
	$(MAKE) benchmark-smoke

benchmark:
	$(LUAJIT) benchmarks/mixed_factory.lua

benchmark-smoke:
	THOTH_BENCH_TICKS=60 THOTH_BENCH_BURNER_LINES=2 THOTH_BENCH_POWERED_LINES=1 $(LUAJIT) benchmarks/mixed_factory.lua

benchmark-scaled:
	THOTH_BENCH_TICKS=900 THOTH_BENCH_BURNER_LINES=48 THOTH_BENCH_POWERED_LINES=16 $(LUAJIT) benchmarks/mixed_factory.lua

package-build:
	mkdir -p dist
	rm -f $(PACKAGE)
	zip -9 -r $(PACKAGE) $(PACKAGE_INPUTS) -x "assets/previews/*" "assets/replays/*"
	zip -T $(PACKAGE)

package: check

clean:
	rm -rf dist
