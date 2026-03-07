DEFAULT_TEST_RUNNER := $(shell sh -c 'for runner in luajit lua lua5.4 lua5.3 lua5.2 lua5.1; do if command -v $$runner >/dev/null 2>&1; then printf "%s" "$$runner"; exit 0; fi; done')
TEST_RUNNER ?= $(DEFAULT_TEST_RUNNER)
TEST_FILES := $(sort $(wildcard test/test*.lua))
PROJECT_LUA_PATH := ./?.lua;./?/init.lua
EXISTING_LUA_PATH := $(value LUA_PATH)
export LUA_PATH := $(PROJECT_LUA_PATH);$(if $(strip $(EXISTING_LUA_PATH)),$(EXISTING_LUA_PATH),;)

.PHONY: test clean print-test-runner

ifeq ($(strip $(TEST_RUNNER)),)
$(error No Lua interpreter found on PATH. Install luajit or lua, or run make test TEST_RUNNER=/path/to/lua)
endif

test:
	@for file in $(TEST_FILES); do \
		echo "Running $$file..."; \
		$(TEST_RUNNER) $$file || exit 1; \
	done

print-test-runner:
	@echo $(TEST_RUNNER)

clean:
	rm -rf .cache *.rock
