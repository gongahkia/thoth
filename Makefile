.PHONY: run smoke test check benchmark benchmark-scaled package clean

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
	$(LUAJIT) tests/replays.lua
	$(LUAJIT) tests/assets.lua
	$(LUAJIT) tests/registry.lua

benchmark:
	$(LUAJIT) benchmarks/mixed_factory.lua

benchmark-scaled:
	THOTH_BENCH_TICKS=900 THOTH_BENCH_BURNER_LINES=48 THOTH_BENCH_POWERED_LINES=16 $(LUAJIT) benchmarks/mixed_factory.lua

package: check
	mkdir -p dist
	rm -f $(PACKAGE)
	zip -9 -r $(PACKAGE) main.lua conf.lua src assets README.md docs "to do.md" -x "assets/previews/*" "assets/replays/*"
	zip -T $(PACKAGE)

clean:
	rm -rf dist
