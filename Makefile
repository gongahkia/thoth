TEST_RUNNER := lua
TEST_DIR := test

all:

up:
	git pull
	git status

clean:
	rm -rf .git .gitignore $(TEST_DIR) Makefile README.md

test: testMath testMath2D testStringify testTables testLinks testQueues testStacks testTrees

testMath:
	@echo "Running math tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testMath.lua

testMath2D:
	@echo "Running math2D tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testMath2D.lua

testStringify:
	@echo "Running stringify tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testStringify.lua

testTables:
	@echo "Running tables tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testTables.lua

testLinks:
	@echo "Running links tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testLinks.lua

testQueues:
	@echo "Running queues tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testQueues.lua

testStacks:
	@echo "Running stacks tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testStacks.lua

testTrees:
	@echo "Running trees tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testTrees.lua

.PHONY: all up clean test testMath testMath2D testStringify testTables testLinks testQueues testStacks testTrees
