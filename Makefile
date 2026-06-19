.PHONY: run smoke title-smoke settings-smoke estate-smoke combat-smoke curio-smoke camp-smoke render-smoke test check benchmark benchmark-smoke benchmark-scaled render-benchmark package-build package clean

LOVE ?= love
LUAJIT ?= luajit
PACKAGE := dist/thoth.love
PACKAGE_INPUTS := main.lua conf.lua src assets vendor/g3d/g3d vendor/g3d/LICENSE TODO.md docs

run:
	$(LOVE) .

smoke:
	$(LOVE) . --smoke

title-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --title-smoke | tee $$tmp; \
	else \
		$(LOVE) . --title-smoke | tee $$tmp; \
	fi; \
	grep -q "title-smoke-state=title" $$tmp; \
	grep -q "title-smoke-buttons=new,continue,settings,quit" $$tmp; \
	rm -f $$tmp

settings-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --settings-smoke | tee $$tmp; \
	else \
		$(LOVE) . --settings-smoke | tee $$tmp; \
	fi; \
	grep -q "settings-smoke-state=settings" $$tmp; \
	grep -q "settings-smoke-adjust=true" $$tmp; \
	grep -q "settings-smoke-bind=true" $$tmp; \
	grep -q "settings-smoke-toggle=true" $$tmp; \
	rm -f $$tmp

estate-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --estate-smoke | tee $$tmp; \
	else \
		$(LOVE) . --estate-smoke | tee $$tmp; \
	fi; \
	grep -q "estate-smoke-mode=estate" $$tmp; \
	grep -q "estate-smoke-buildings=4" $$tmp; \
	grep -q "estate-smoke-gear-actions=2" $$tmp; \
	grep -q "estate-smoke-trinket-actions=3" $$tmp; \
	grep -q "estate-smoke-trinket-tooltips=6" $$tmp; \
	grep -q "estate-smoke-roster=" $$tmp; \
	grep -q "estate-smoke-party-slots=4" $$tmp; \
	grep -q "estate-smoke-missions=" $$tmp; \
	rm -f $$tmp

combat-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --combat-smoke | tee $$tmp; \
	else \
		$(LOVE) . --combat-smoke | tee $$tmp; \
	fi; \
	grep -q "combat-smoke-mode=combat" $$tmp; \
	grep -q "combat-smoke-turns=6" $$tmp; \
	grep -q "combat-smoke-skills=3" $$tmp; \
	grep -q "combat-smoke-ally-targets=4" $$tmp; \
	grep -q "combat-smoke-enemy-targets=2" $$tmp; \
	rm -f $$tmp

curio-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --curio-smoke | tee $$tmp; \
	else \
		$(LOVE) . --curio-smoke | tee $$tmp; \
	fi; \
	grep -q "curio-smoke-modal=salt_font" $$tmp; \
	grep -q "curio-smoke-buttons=4" $$tmp; \
	grep -q "curio-smoke-enabled=4" $$tmp; \
	rm -f $$tmp

camp-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --camp-smoke | tee $$tmp; \
	else \
		$(LOVE) . --camp-smoke | tee $$tmp; \
	fi; \
	grep -q "camp-smoke-active=true" $$tmp; \
	grep -q "camp-smoke-skills=7" $$tmp; \
	grep -q "camp-smoke-heroes=4" $$tmp; \
	grep -q "camp-smoke-respite=" $$tmp; \
	rm -f $$tmp

render-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --smoke --render-smoke | tee $$tmp; \
	else \
		$(LOVE) . --smoke --render-smoke | tee $$tmp; \
	fi; \
	grep -q "render-smoke-renderer=render3d" $$tmp; \
	grep -q "render-smoke-mode=render3d" $$tmp; \
	grep -q "render-smoke-hud-torch=" $$tmp; \
	grep -q "render-smoke-hud-room=" $$tmp; \
	grep -q "render-smoke-hud-party=4" $$tmp; \
	rm -f $$tmp

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
	$(LUAJIT) benchmarks/rpg_expedition.lua

benchmark-smoke:
	THOTH_BENCH_TICKS=60 THOTH_BENCH_RUNS=4 $(LUAJIT) benchmarks/rpg_expedition.lua

benchmark-scaled:
	THOTH_BENCH_TICKS=900 THOTH_BENCH_RUNS=24 $(LUAJIT) benchmarks/rpg_expedition.lua

render-benchmark:
	@if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --render-benchmark; \
	else \
		$(LOVE) . --render-benchmark; \
	fi

package-build:
	mkdir -p dist
	rm -f $(PACKAGE)
	zip -9 -r $(PACKAGE) $(PACKAGE_INPUTS) -x "assets/previews/*" "assets/replays/*"
	zip -T $(PACKAGE)

package: check

clean:
	rm -rf dist
