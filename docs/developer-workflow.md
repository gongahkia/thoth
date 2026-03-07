# Developer Workflow

## Testing

`make test` now handles local module resolution without requiring a manual `LUA_PATH` export.

The Makefile will use the first available interpreter from this list:

1. `luajit`
2. `lua`
3. `lua5.4`
4. `lua5.3`
5. `lua5.2`
6. `lua5.1`

Override the interpreter when needed:

```sh
make test TEST_RUNNER=lua5.4
```

Inspect the detected runner:

```sh
make print-test-runner
```

The exported module path prepends the project root so direct test execution still resolves `thoth`, `thoth.core.*`, `thoth.game.*`, and `thoth.adapters.*`.
