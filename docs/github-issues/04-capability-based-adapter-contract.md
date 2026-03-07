# Replace the minimal adapter contract with a capability-based contract

## Summary

The current adapter contract only validates `now`, `isDown`, and `getAxis`, which is too shallow for the direction of the runtime. Replace it with a capability-based contract that describes what an adapter can do and validates the shape of each supported interface.

## Scope

- Define capability groups for lifecycle, keyboard, mouse, touch, gamepad, text input, storage, audio, windowing, and debug drawing.
- Replace the static required-method list with validators that can enforce required and optional capability shapes.
- Update the null adapter to expose no-op implementations for supported capabilities.
- Ensure shipped adapters declare capability tables consistently.
- Document how custom adapters can implement only the capability groups they need.

## Acceptance criteria

- Adapter validation reports missing or malformed capabilities clearly.
- Love2D, Defold, Solar2D, and the null adapter declare their supported capabilities.
- Runtime and input code branch on adapter capabilities instead of ad hoc method checks.
- Tests cover capability validation and null-adapter behavior.

## Primary files

- `thoth/adapters/contract.lua`
- `thoth/adapters/love2d.lua`
- `thoth/adapters/defold.lua`
- `thoth/adapters/solar2d.lua`
