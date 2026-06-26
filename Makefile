.PHONY: run test smoke diagnostics render-smoke walk-smoke clean

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

clean:
	rm -rf dist
