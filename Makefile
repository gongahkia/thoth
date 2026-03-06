TEST_RUNNER ?= lua
TEST_FILES := $(sort $(wildcard test/test*.lua))

.PHONY: test clean

test:
	@for file in $(TEST_FILES); do \
		echo "Running $$file..."; \
		$(TEST_RUNNER) $$file || exit 1; \
	done

clean:
	rm -rf .cache *.rock
