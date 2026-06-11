.PHONY: test cpp-configure cpp-build cpp-test cpp-benchmark cpp-benchmark-large cpp-benchmark-stress cpp-export-atlas cpp-export-authored-atlas cpp-export-audio cpp-export-authored-audio cpp-export-media-preview cpp-export-playtest-telemetry cpp-smoke-window cpp-validate-assets cpp-validate-replays cpp-run clean

cpp-configure:
	cmake -S . -B build/app -DTHOTH_BUILD_APP=ON -DTHOTH_BUILD_TESTS=ON -DTHOTH_BUILD_BENCHMARKS=ON

cpp-build: cpp-configure
	cmake --build build/app --target thoth_raylib thoth_tests

test cpp-test: cpp-build
	ctest --test-dir build/app --output-on-failure

cpp-benchmark: cpp-configure
	cmake --build build/app --target thoth_benchmark
	./build/app/thoth_benchmark

cpp-benchmark-large: cpp-configure
	cmake --build build/app --target thoth_benchmark
	THOTH_BENCHMARK_BURNER_LINES=96 THOTH_BENCHMARK_POWERED_LINES=32 THOTH_BENCHMARK_MAX_US_PER_TICK=10000 THOTH_BENCHMARK_MAX_US_PER_MACHINE_TICK=4 ./build/app/thoth_benchmark

cpp-benchmark-stress: cpp-configure
	cmake --build build/app --target thoth_benchmark
	THOTH_BENCHMARK_TICKS=600 THOTH_BENCHMARK_BURNER_LINES=512 THOTH_BENCHMARK_POWERED_LINES=128 THOTH_BENCHMARK_MAX_US_PER_TICK=12000 THOTH_BENCHMARK_MAX_US_PER_MACHINE_TICK=4 ./build/app/thoth_benchmark

cpp-export-atlas: cpp-build
	./build/app/thoth_raylib --export-atlas

cpp-export-authored-atlas: cpp-build
	./build/app/thoth_raylib --export-authored-atlas

cpp-export-audio: cpp-build
	./build/app/thoth_raylib --export-audio

cpp-export-authored-audio: cpp-build
	./build/app/thoth_raylib --export-authored-audio

cpp-export-media-preview: cpp-build
	./build/app/thoth_raylib --export-media-preview

cpp-export-playtest-telemetry: cpp-build
	./build/app/thoth_raylib --export-playtest-telemetry

cpp-smoke-window: cpp-build
	./build/app/thoth_raylib --window-smoke

cpp-validate-assets: cpp-build
	./build/app/thoth_raylib --validate-assets

cpp-validate-replays: cpp-build
	./build/app/thoth_raylib --validate-replays

cpp-run: cpp-build
	./build/app/thoth_raylib

clean:
	rm -rf build
