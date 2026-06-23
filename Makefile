.PHONY: run smoke title-smoke settings-smoke estate-smoke legacy-combat-smoke curio-smoke camp-smoke pause-smoke confirm-smoke gameover-smoke credits-smoke journal-smoke tutorial-smoke toast-smoke polish-smoke keyboard-smoke controller-smoke render-smoke tactical-smoke storefront-previews sprite-import-smoke model-import-smoke validate test check merchant-balance-pass benchmark benchmark-smoke benchmark-scaled render-benchmark package-build package-title-smoke package clean

LOVE ?= love
LUAJIT ?= luajit
PACKAGE := dist/thoth.love
PACKAGE_INPUTS := main.lua conf.lua src assets vendor/g3d/g3d vendor/g3d/LICENSE TODO.md docs
VALIDATOR_REJECT_BUDGET ?= 0

run:
	$(LOVE) .

smoke:
	$(MAKE) tactical-smoke

title-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --title-smoke | tee $$tmp; \
	else \
		$(LOVE) . --title-smoke | tee $$tmp; \
	fi; \
	grep -q "title-smoke-state=title" $$tmp; \
	grep -q "title-smoke-buttons=new,continue,replay,settings,credits,quit" $$tmp; \
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
	grep -q "settings-smoke-tactical-accessibility=true" $$tmp; \
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

legacy-combat-smoke:
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

pause-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --pause-smoke | tee $$tmp; \
	else \
		$(LOVE) . --pause-smoke | tee $$tmp; \
	fi; \
	grep -q "pause-smoke-paused=true" $$tmp; \
	grep -q "pause-smoke-buttons=4" $$tmp; \
	rm -f $$tmp

confirm-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --confirm-smoke | tee $$tmp; \
	else \
		$(LOVE) . --confirm-smoke | tee $$tmp; \
	fi; \
	grep -q "confirm-smoke-open=true" $$tmp; \
	grep -q "confirm-smoke-paused=true" $$tmp; \
	grep -q "confirm-smoke-buttons=cancel,confirm" $$tmp; \
	rm -f $$tmp

gameover-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --gameover-smoke | tee $$tmp; \
	else \
		$(LOVE) . --gameover-smoke | tee $$tmp; \
	fi; \
	grep -q "gameover-smoke-state=gameover" $$tmp; \
	grep -q "gameover-smoke-reason=dread" $$tmp; \
	grep -q "gameover-smoke-route=extraction_collapse" $$tmp; \
	grep -q "gameover-smoke-dread-tier=4" $$tmp; \
	grep -q "gameover-smoke-factions=5" $$tmp; \
	grep -q "gameover-smoke-buttons=restart,title,credits" $$tmp; \
	rm -f $$tmp

credits-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --credits-smoke | tee $$tmp; \
	else \
		$(LOVE) . --credits-smoke | tee $$tmp; \
	fi; \
	grep -q "credits-smoke-state=credits" $$tmp; \
	grep -q "credits-smoke-assets=3" $$tmp; \
	grep -q "credits-smoke-libraries=2" $$tmp; \
	grep -q "credits-smoke-back=1" $$tmp; \
	rm -f $$tmp

journal-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --journal-smoke | tee $$tmp; \
	else \
		$(LOVE) . --journal-smoke | tee $$tmp; \
	fi; \
	grep -q "journal-smoke-state=journal" $$tmp; \
	grep -q "journal-smoke-documents=1" $$tmp; \
	grep -q "journal-smoke-epitaphs=1" $$tmp; \
	grep -q "journal-smoke-buttons=" $$tmp; \
	rm -f $$tmp

tutorial-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --tutorial-smoke | tee $$tmp; \
	else \
		$(LOVE) . --tutorial-smoke | tee $$tmp; \
	fi; \
	grep -q "tutorial-smoke-mode=tactical" $$tmp; \
	grep -q "tutorial-smoke-active=true" $$tmp; \
	grep -q "tutorial-smoke-steps=7" $$tmp; \
	grep -q "tutorial-smoke-first=tactical_onboarding" $$tmp; \
	grep -q "tutorial-smoke-board=tactical_onboarding" $$tmp; \
	grep -q "tutorial-smoke-board-size=6x6" $$tmp; \
	grep -q "tutorial-smoke-script=6" $$tmp; \
	grep -q "tutorial-smoke-buttons=3" $$tmp; \
	rm -f $$tmp

toast-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --toast-smoke | tee $$tmp; \
	else \
		$(LOVE) . --toast-smoke | tee $$tmp; \
	fi; \
	grep -q "toast-smoke-unlocked=true" $$tmp; \
	grep -q "toast-smoke-count=2" $$tmp; \
	rm -f $$tmp

polish-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --polish-smoke | tee $$tmp; \
	else \
		$(LOVE) . --polish-smoke | tee $$tmp; \
	fi; \
	grep -q "polish-smoke-hitbox=true" $$tmp; \
	grep -q "polish-smoke-pulse=true" $$tmp; \
	grep -q "polish-smoke-draw=true" $$tmp; \
	rm -f $$tmp

keyboard-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --keyboard-smoke | tee $$tmp; \
	else \
		$(LOVE) . --keyboard-smoke | tee $$tmp; \
	fi; \
	grep -q "keyboard-smoke-focusables=true" $$tmp; \
	grep -q "keyboard-smoke-tab=true" $$tmp; \
	grep -q "keyboard-smoke-back=true" $$tmp; \
	rm -f $$tmp

controller-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --controller-smoke | tee $$tmp; \
	else \
		$(LOVE) . --controller-smoke | tee $$tmp; \
	fi; \
	grep -q "controller-smoke-a=return" $$tmp; \
	grep -q "controller-smoke-b=escape" $$tmp; \
	grep -q "controller-smoke-axis=right" $$tmp; \
	grep -q "controller-smoke-tactical-cursor=2,3" $$tmp; \
	grep -q "controller-smoke-tactical-activate=2,3" $$tmp; \
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
	grep -q "render-smoke-overlay-total=7" $$tmp; \
	grep -q "render-smoke-overlay-movement=2" $$tmp; \
	grep -q "render-smoke-overlay-los=1" $$tmp; \
	grep -q "render-smoke-overlay-cover=1" $$tmp; \
	grep -q "render-smoke-overlay-flank=1" $$tmp; \
	grep -q "render-smoke-overlay-intent=1" $$tmp; \
	grep -q "render-smoke-overlay-hazard=1" $$tmp; \
	rm -f $$tmp

tactical-smoke:
	@set -e; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		SDL_AUDIODRIVER=dummy xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --tactical-smoke | tee $$tmp; \
	else \
		SDL_AUDIODRIVER=dummy $(LOVE) . --tactical-smoke | tee $$tmp; \
	fi; \
	grep -q "tactical-smoke-mode=tactical" $$tmp; \
	grep -q "tactical-smoke-route=buried_archive_vertical_slice" $$tmp; \
	grep -q "tactical-smoke-variant=archive_entry_audit" $$tmp; \
	grep -q "tactical-smoke-route-step=1/6" $$tmp; \
	grep -q "tactical-smoke-legacy-expedition=false" $$tmp; \
	grep -q "tactical-smoke-phase=player" $$tmp; \
	grep -q "tactical-smoke-player-units=6" $$tmp; \
	grep -q "tactical-smoke-enemy-units=2" $$tmp; \
	grep -q "tactical-smoke-board-size=32x24" $$tmp; \
	grep -q "tactical-smoke-height-tiles=[1-9]" $$tmp; \
	grep -q "tactical-smoke-destructibles=[1-9]" $$tmp; \
	grep -q "tactical-smoke-vertical-routes=[1-9]" $$tmp; \
	grep -q "tactical-smoke-descents=[1-9]" $$tmp; \
	grep -q "tactical-smoke-sightlines=[1-9]" $$tmp; \
	grep -q "tactical-smoke-high-cover=[1-9]" $$tmp; \
	grep -q "tactical-smoke-enemy-cards=[1-9]" $$tmp; \
	grep -q "tactical-smoke-intent-badges=[1-9]" $$tmp; \
	grep -q "tactical-smoke-intents=2" $$tmp; \
	grep -q "tactical-smoke-forecast=[1-9]" $$tmp; \
	grep -q "tactical-smoke-zoom=1.75" $$tmp; \
	grep -q "tactical-smoke-objective=3/3" $$tmp; \
	grep -q "tactical-smoke-hud-layout=true" $$tmp; \
	grep -q "tactical-smoke-hud-portraits=6" $$tmp; \
	grep -q "tactical-smoke-hud-ap-pools=6" $$tmp; \
	grep -q "tactical-smoke-hud-overlaps=0" $$tmp; \
	grep -q "tactical-smoke-inspector=true" $$tmp; \
	grep -q "tactical-smoke-inspector-lines=[1-9]" $$tmp; \
	grep -q "tactical-smoke-intent-legend=2" $$tmp; \
	grep -q "tactical-smoke-intent-targets=[1-9]" $$tmp; \
	grep -q "tactical-smoke-compass=0" $$tmp; \
	grep -q "tactical-smoke-ghost-arrows=0" $$tmp; \
	rm -f $$tmp

storefront-previews:
	@set -e; \
	mkdir -p assets/previews; \
	for spec in fog:itch-tactical-fog.png overwatch:itch-tactical-overwatch.png intent:itch-tactical-intent-legend.png; do \
		state=$${spec%%:*}; \
		path=assets/previews/$${spec#*:}; \
		tmp=$$(mktemp); \
		if command -v xvfb-run >/dev/null 2>&1; then \
			SDL_AUDIODRIVER=dummy xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --tactical-smoke --tactical-preview-state $$state --preview-capture $$path | tee $$tmp; \
		else \
			SDL_AUDIODRIVER=dummy $(LOVE) . --tactical-smoke --tactical-preview-state $$state --preview-capture $$path | tee $$tmp; \
		fi; \
		grep -q "tactical-smoke-preview-state=$$state" $$tmp; \
		grep -q "preview-capture=$$path" $$tmp; \
		test -s $$path; \
		rm -f $$tmp; \
	done

sprite-import-smoke:
	@set -e; \
	rm -rf dist/sprite-import-smoke; \
	mkdir -p dist/sprite-import-smoke; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		SDL_AUDIODRIVER=dummy xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --sprite-import --sprite-source assets/sprites/oga_700_sprites.png --sprite-atlas dist/sprite-import-smoke/oga_700_sprites.png --sprite-manifest dist/sprite-import-smoke/oga_700_sprites.lua --sprite-frame 32x32 | tee $$tmp; \
	else \
		SDL_AUDIODRIVER=dummy $(LOVE) . --sprite-import --sprite-source assets/sprites/oga_700_sprites.png --sprite-atlas dist/sprite-import-smoke/oga_700_sprites.png --sprite-manifest dist/sprite-import-smoke/oga_700_sprites.lua --sprite-frame 32x32 | tee $$tmp; \
	fi; \
	grep -q "sprite-import-frames=304" $$tmp; \
	grep -q "sprite-import-atlas=dist/sprite-import-smoke/oga_700_sprites.png" $$tmp; \
	grep -q "sprite-import-manifest=dist/sprite-import-smoke/oga_700_sprites.lua" $$tmp; \
	test -s dist/sprite-import-smoke/oga_700_sprites.png; \
	test -s dist/sprite-import-smoke/oga_700_sprites.lua; \
	rm -f $$tmp

model-import-smoke:
	@set -e; \
	rm -rf dist/model-import-smoke; \
	mkdir -p dist/model-import-smoke; \
	tmp=$$(mktemp); \
	if command -v xvfb-run >/dev/null 2>&1; then \
		SDL_AUDIODRIVER=dummy xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --model-import --model-source vendor/g3d/assets/cube.obj --model-out dist/model-import-smoke/cube.obj --model-manifest dist/model-import-smoke/models.lua --model-id smoke_cube | tee $$tmp; \
	else \
		SDL_AUDIODRIVER=dummy $(LOVE) . --model-import --model-source vendor/g3d/assets/cube.obj --model-out dist/model-import-smoke/cube.obj --model-manifest dist/model-import-smoke/models.lua --model-id smoke_cube | tee $$tmp; \
	fi; \
	grep -q "model-import-format=obj" $$tmp; \
	grep -q "model-import-vertices=36" $$tmp; \
	grep -q "model-import-g3d=true" $$tmp; \
	test -s dist/model-import-smoke/cube.obj; \
	test -s dist/model-import-smoke/models.lua; \
	rm -f $$tmp

test:
	$(LUAJIT) tests/run.lua

validate:
	@set -e; \
	tmp=$$(mktemp); \
	$(LUAJIT) tools/validator.lua --out dist/validator-report.json --reject-budget $(VALIDATOR_REJECT_BUDGET) | tee $$tmp; \
	grep -q "validator=procgen_validator_v1" $$tmp; \
	grep -q "validator-seeds=25" $$tmp; \
	grep -q "validator-budget=$(VALIDATOR_REJECT_BUDGET)" $$tmp; \
	grep -q "validator-rejects=" $$tmp; \
	test -s dist/validator-report.json; \
	rm -f $$tmp

check: test
	$(LUAJIT) tests/replays.lua
	$(LUAJIT) tests/assets.lua
	$(LUAJIT) tests/registry.lua
	$(MAKE) merchant-balance-pass
	$(MAKE) sprite-import-smoke
	$(MAKE) model-import-smoke
	$(MAKE) package-build
	$(LUAJIT) tests/package.lua $(PACKAGE)
	$(MAKE) benchmark-smoke
	$(MAKE) tactical-smoke

merchant-balance-pass:
	$(LUAJIT) tools/merchant_balance_pass.lua

benchmark:
	$(LUAJIT) benchmarks/tactical_route.lua

benchmark-smoke:
	THOTH_BENCH_TICKS=60 THOTH_BENCH_RUNS=4 $(LUAJIT) benchmarks/tactical_route.lua

benchmark-scaled:
	THOTH_BENCH_TICKS=900 THOTH_BENCH_RUNS=24 $(LUAJIT) benchmarks/tactical_route.lua

render-benchmark:
	@if command -v xvfb-run >/dev/null 2>&1; then \
		xvfb-run -a --server-args="-screen 0 1280x720x24" $(LOVE) . --render-benchmark; \
	else \
		$(LOVE) . --render-benchmark; \
	fi

package-build:
	mkdir -p dist
	rm -f $(PACKAGE)
	zip -9 -r $(PACKAGE) $(PACKAGE_INPUTS) -x "assets/previews/*" "assets/press/*" "assets/replays/*"
	zip -T $(PACKAGE)

package-title-smoke: package-build
	@tmp_home=$$(mktemp -d); \
	HOME="$$tmp_home" SDL_AUDIODRIVER=dummy $(LOVE) $(PACKAGE) --title-smoke; \
	rc=$$?; \
	rm -rf "$$tmp_home"; \
	exit $$rc

package: check

clean:
	rm -rf dist
