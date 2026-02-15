TEST_RUNNER := lua
TEST_DIR := test

all:

up:
	git pull
	git status

clean:
	rm -rf .git .gitignore $(TEST_DIR) Makefile README.md

test: testMath testMath2D testStringify testTables testLinks testQueues testStacks testTrees testCache testEvents testGraphs testHeaps testTries testValidate testSerialize testPerformance

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

testCache:
	@echo "Running cache tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testCache.lua

testEvents:
	@echo "Running events tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testEvents.lua

testGraphs:
	@echo "Running graphs tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testGraphs.lua

testHeaps:
	@echo "Running heaps tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testHeaps.lua

testTries:
	@echo "Running tries tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testTries.lua

testValidate:
	@echo "Running validate tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testValidate.lua

testSerialize:
	@echo "Running serialize tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testSerialize.lua

testPerformance:
	@echo "Running performance tests..."
	$(TEST_RUNNER) $(TEST_DIR)/testPerformance.lua

.PHONY: all up clean test testMath testMath2D testStringify testTables testLinks testQueues testStacks testTrees testCache testEvents testGraphs testHeaps testTries testValidate testSerialize testPerformance
