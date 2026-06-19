# Release Build Workflow

Status: GitHub Actions packaging pipeline for TODO 8.1.

Workflow: `.github/workflows/release-build.yml`

Triggers:

- manual `workflow_dispatch`
- tag pushes matching `v*`
- tag pushes matching `phase*-*`

Manual input:

- `upload_to_itch`: uploads built packages to itch.io with butler when true.

Outputs:

- `thoth-love`: `.love` package
- `thoth-windows-x64`: Windows x64 executable package
- `thoth-windows-x86`: Windows x86 executable package
- `thoth-macos`: macOS app package
- `thoth-linux-appimage`: Linux x86_64 AppImage package

itch.io upload channels:

- `love`
- `windows-x64`
- `windows-x86`
- `macos`
- `linux-appimage`

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

itch.io upload configuration:

- Secret `BUTLER_API_KEY`: itch.io butler API key for CI.
- Variable `ITCH_TARGET`: itch target in `user/game` format.
- Variable `ITCH_UPLOAD_ENABLED`: set to `true` to upload on tag-triggered release builds.
- Without `ITCH_UPLOAD_ENABLED=true`, upload only runs for manual dispatches with `upload_to_itch=true`.

Butler integration:

- Installs latest stable Linux butler from the automation-friendly broth URL: `https://itch.io/docs/butler/installing.html`
- Pushes each built package with `butler push path user/game:channel`: `https://itch.io/docs/butler/pushing.html`
- Uses `BUTLER_API_KEY` for CI auth: `https://itch.io/docs/butler/login.html`
- Sets `--userversion` to the Git ref name for each pushed channel.

Verification:

- Local syntax check: `ruby -e 'require "yaml"; YAML.parse_file(".github/workflows/release-build.yml"); puts "yaml ok"'`
- Local package/test check: `make check`
- Remote GitHub Actions packaging run: not run locally.

Out of scope:

- GitHub Release attach/changelog automation remains TODO 8.3.
