# contributing

## setup

```console
$ git clone https://github.com/gongahkia/thoth
$ cd thoth
$ make test
```

## standards

- keep changes focused and minimal.
- preserve backwards compatibility for `v4.x` unless a breaking change is explicitly approved.
- add or update tests for behavioral changes.
- keep module namespaces under `thoth.core.*`, `thoth.game.*`, and `thoth.adapters.*`.

## pull request checklist

- [ ] tests pass locally with `make test`
- [ ] new/changed behavior is covered in `test/test*.lua`
- [ ] docs updated for public API changes
- [ ] migration guidance added when imports or behavior changes
