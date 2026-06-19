# Thoth Model Assets

No external model pack files are committed yet.

Import pipeline:

- CLI: `love . --model-import --model-source <source.obj> --model-out <model.obj> --model-manifest <manifest.lua>`
- Smoke: `make model-import-smoke`

Runtime target: g3d OBJ models. glTF sources must be converted to OBJ before import.
