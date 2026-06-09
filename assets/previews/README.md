# Thoth Preview Exports

Run `make cpp-export-media-preview`, or `./build/app/thoth_raylib --export-media-preview`, to export `thoth_full_flow_preview.png` from the packaged full-flow replay without opening a window.

The preview is deterministic and uses the authored atlas source plus replay validation, so it can be checked in CI and reviewed without launching the interactive raylib app.

Run `make cpp-smoke-window`, or `./build/app/thoth_raylib --window-smoke`, to open the actual raylib window, load the authored visual/audio assets, render the full-flow replay state, save `thoth_window_smoke.png`, and exit. On headless Linux, use `xvfb-run -a -s "-screen 0 1280x720x24" make cpp-smoke-window`.
