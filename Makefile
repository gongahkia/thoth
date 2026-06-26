.PHONY: run test smoke diagnostics render-smoke walk-smoke export-smoke clean

LOVE ?= love
LUAJIT ?= luajit

run:
	$(LOVE) .

test:
	$(LUAJIT) tests/run.lua

smoke:
	$(LUAJIT) tests/run.lua --smoke

diagnostics:
	$(LUAJIT) tests/run.lua --diagnostics

render-smoke:
	SDL_AUDIODRIVER=dummy $(LOVE) . --render-smoke

walk-smoke:
	SDL_AUDIODRIVER=dummy $(LOVE) . --walk-smoke --walk-smoke-frames 240 --perf-interval 0.5

export-smoke:
	rm -rf dist/export-smoke
	mkdir -p dist/export-smoke
	SDL_AUDIODRIVER=dummy $(LOVE) . --export-map dist/export-smoke/map --export-size 64

clean:
	rm -rf dist
