# Release Build Workflow

Status: GitHub Actions packaging pipeline for TODO 8.1.

Workflow: `.github/workflows/release-build.yml`

Triggers:

- manual `workflow_dispatch`
- tag pushes matching `v*`
- tag pushes matching `phase*-*`

Outputs:

- `thoth-love`: `.love` package
- `thoth-windows-x64`: Windows x64 executable package
- `thoth-windows-x86`: Windows x86 executable package
- `thoth-macos`: macOS app package
- `thoth-linux-appimage`: Linux x86_64 AppImage package

Source staging mirrors the local `Makefile` package allowlist:

- `main.lua`
- `conf.lua`
- `TODO.md`
- `src/`
- `assets/`
- `docs/`
- `vendor/g3d/g3d`
- `vendor/g3d/LICENSE`

Excluded from release staging:

- `assets/previews/`
- `assets/replays/`

Builder selection:

- Uses `nhartland/love-build@v1` because its documented outputs cover `.love`, Win32, Win64, macOS, and Linux x86_64 AppImage builds for LÖVE 11.x: `https://github.com/nhartland/love-build/blob/main/action.yml`
- Did not use `MisterDA/love-release`; the repository is archived/read-only as of 2025-07-09: `https://github.com/MisterDA/love-release`

Verification:

- Local syntax check: `ruby -e 'require "yaml"; YAML.parse_file(".github/workflows/release-build.yml"); puts "yaml ok"'`
- Local package/test check: `make check`
- Remote GitHub Actions packaging run: not run locally.

Out of scope:

- itch.io butler upload remains TODO 8.2.
- GitHub Release attach/changelog automation remains TODO 8.3.
