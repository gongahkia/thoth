# Trailer Production 8.7

Status: production plan only. Do not remove TODO 8.7 until a final 60-90s gameplay trailer is rendered, reviewed, and publicly available.

## Runtime Target

- Length: 60-90 seconds.
- Format: 1080p H.264 MP4 minimum.
- Audio: final music mix or trailer-safe licensed track.
- Source: captured gameplay only; no misleading mockups.

## Shot List

| Time | Shot | Evidence |
|---:|---|---|
| 0-5s | Title and identity | `assets/previews/final-title.png` |
| 5-15s | Estate roster, provisions, mission choice | `assets/previews/final-estate.png` |
| 15-30s | Expedition movement, torch, room state | `assets/previews/final-expedition.png` |
| 30-50s | Combat target selection and turn order | `assets/previews/final-combat.png` |
| 50-65s | Stress/pressure/camping or route consequence | gameplay capture TBD |
| 65-80s | Game-over or campaign-sealed outcome | `assets/previews/final-gameover.png` |
| 80-90s | itch/GitHub CTA | public links TBD |

## Capture Commands

Static preview capture:

```sh
SDL_AUDIODRIVER=dummy love . --title-smoke --preview-capture assets/previews/final-title.png
SDL_AUDIODRIVER=dummy love . --estate-smoke --preview-capture assets/previews/final-estate.png
SDL_AUDIODRIVER=dummy love . --tactical-smoke --preview-capture assets/previews/final-route.png
SDL_AUDIODRIVER=dummy love . --tactical-smoke --preview-capture assets/previews/final-tactical.png
SDL_AUDIODRIVER=dummy love . --gameover-smoke --preview-capture assets/previews/final-gameover.png
```

Live capture requirement:

```text
Record full gameplay video from a local release build or clean package. Static smoke captures are acceptable references, not trailer footage.
```

## Completion Evidence Required

- Source capture path recorded.
- Music/license row recorded in `docs/asset-licenses.md`.
- Exported MP4 path recorded.
- Public trailer URL recorded.
- Trailer verified in private/incognito browser.
- Trailer embedded on itch final page.
