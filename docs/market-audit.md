# Thoth Product Notes

Date: 2026-06-18

Thoth is being rebuilt as a smaller Lua/LOVE automation game instead of continuing the C++/raylib prototype.

## Reboot Position

- Keep the deterministic automation premise.
- Start with a readable ore-to-plate factory loop.
- Add exploration, pressure, bosses, rifts, and late content only after the new Lua foundation is stable.
- Treat the old C++ implementation as reference material, not a parity target.

## Near-Term Product Risk

- The current Lua slice is intentionally small.
- The first test of quality is whether movement, mining, crafting, placement, and a starter factory feel legible in LOVE.
- Late-game systems from the C++ prototype should return only when they create new player decisions instead of checklist sprawl.
