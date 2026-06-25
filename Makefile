.PHONY: run test smoke render-smoke clean

LOVE ?= love
LUAJIT ?= luajit

run:
	$(LOVE) .

test:
	$(LUAJIT) tests/run.lua

smoke:
	$(LUAJIT) tests/run.lua --smoke

render-smoke:
	SDL_AUDIODRIVER=dummy $(LOVE) . --render-smoke

clean:
	rm -rf dist
