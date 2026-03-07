# Expand input and platform coverage across the runtime and adapters

## Summary

The current input manager covers keyboard, mouse buttons, and simple axes, but it does not yet support the broader set of controls expected from a cross-engine gameplay runtime. Add richer input bindings and map the available platform events through the new adapter capability contract.

## Scope

- Add gamepad button and analog-axis bindings.
- Add touch bindings and touch-friendly action mapping.
- Add deadzone, sensitivity, and response-curve support for analog inputs.
- Add runtime rebinding helpers and binding profile persistence.
- Expand adapters to surface text input, mouse wheel, touch, and gamepad data where the host engine supports them.

## Acceptance criteria

- `thoth.game.input` supports gamepad and touch binding specs without breaking current keyboard/mouse usage.
- Input profiles can be exported, persisted, imported, and rebound at runtime.
- Analog bindings support configurable deadzones.
- Tests cover rebind flows, profile persistence, and analog edge cases.

## Depends on

- Capability-based adapter contract.
