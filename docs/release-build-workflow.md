# Release Build Workflow

Status: GitHub Actions packaging pipeline for TODO 8.1.

Workflow: `.github/workflows/release-build.yml`

Triggers:

- manual `workflow_dispatch`
- tag pushes matching `v*`
- tag pushes matching `phase*-*`

Manual input:

- `upload_to_itch`: uploads built packages to itch.io with butler when true.
- `create_github_release`: creates a GitHub Release and attaches packages when true.
- `release_tag`: tag used for manual GitHub Release creation.

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

GitHub Release integration:

- Tag-triggered workflow runs create a GitHub Release for the pushed tag.
- Manual runs create a GitHub Release when `create_github_release=true` and `release_tag` is non-empty.
- If the manual `release_tag` does not already exist, `gh release create` creates it at the workflow commit via `--target "$GITHUB_SHA"`.
- Existing releases are detected with `gh release view`; assets are refreshed with `gh release upload --clobber`.
- Release notes are generated with `gh release create --generate-notes`.
- The five built packages are attached as release assets with display labels.
- Non-`v*` release tags are marked prerelease and not latest.
- Uses `GH_TOKEN: ${{ github.token }}` per GitHub CLI workflow auth guidance.
- Sources: `https://cli.github.com/manual/gh_release_create`, `https://cli.github.com/manual/gh_release_upload`, `https://docs.github.com/actions/using-workflows/using-github-cli-in-workflows`

Verification:

- Local syntax check: `ruby -e 'require "yaml"; YAML.parse_file(".github/workflows/release-build.yml"); puts "yaml ok"'`
- Local package/test check: `make check`
- Remote GitHub Actions packaging run: not run locally.

Out of scope:
- Clean-install verification remains TODO 8.4.
