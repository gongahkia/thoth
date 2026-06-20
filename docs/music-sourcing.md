# Music Sourcing

Sourcing date: 2026-06-19

## License Notes

- FreePD is closed as of the checked date, so it is not a usable source for this pass: `https://freepd.com/`
- Pixabay's current license summary says content can be used for free, attribution is not required, and modification/adaptation is allowed, subject to prohibited uses: `https://pixabay.com/service/license-summary/`
- Pixabay's terms say non-CC0 downloads use a royalty-free Content License, and prohibit standalone redistribution of the raw content: `https://pixabay.com/service/terms/`
- [Inference] Shipping these tracks inside Thoth as mixed game audio is not standalone redistribution, but store each downloaded license certificate at import time.
- Keep creator credit in `docs/asset-licenses.md` after files are imported, even when attribution is not required.

## Selected Candidates

| Slot | Candidate | Creator | Duration | Source | License state | Fit |
|---|---|---|---:|---|---|---|
| estate | Old Money Estate | Shorts_by_PazuzuStudio | 0:30 | `https://pixabay.com/music/modern-classical-old-money-estate-534048/` | Pixabay Content License; page marks Content ID registered. | [Inference] Best fit for the Estate: restrained, institutional piano. |
| expedition calm | Dark Fantasy Ambient (Dungeon Synth) | DeusLower | 1:47 | `https://pixabay.com/music/ambient-dark-fantasy-ambient-dungeon-synth-248213/` | Pixabay Content License. | [Inference] Fits low-risk corridor traversal and room scanning. |
| expedition tense | Tense Horror Background | Universfield | 1:32 | `https://pixabay.com/music/mystery-tense-horror-background-174809/` | Pixabay Content License. | [Inference] Fits torch pressure, scout uncertainty, and pre-combat tension. |
| combat normal | Battle - Battle Music | PaulYudin | 2:42 | `https://pixabay.com/music/adventure-battle-battle-music-491417/` | Pixabay Content License; page marks Content ID registered. | [Inference] Usable combat bed if mixed lower than UI impacts. |
| combat boss | Dark Epic | NastelBom | 2:29 | `https://pixabay.com/music/adventure-dark-epic-487720/` | Pixabay Content License; page marks Content ID registered. | [Inference] Bigger boss-combat profile without leaving dark fantasy tone. |
| victory sting | Victory | NastelBom | 1:57 | `https://pixabay.com/music/main-title-victory-400621/` | Pixabay Content License; page marks Content ID registered. | [Inference] Import a 6-10s opening/ending cue rather than the full track. |
| death sting | Evil organ sting (Medium) | Cartoon-Music-Game-Sfx | 0:22 | `https://pixabay.com/music/horror-scene-evil-organ-sting-medium-529241/` | Pixabay Content License. | [Inference] Short enough for death-door/death failure without extra editing. |
| credits | Ambient Cinematic | AtlasAudio | 2:04 | `https://pixabay.com/music/ambient-ambient-cinematic-510518/` | Pixabay Content License; page marks Content ID registered. | [Inference] Neutral credits bed after a dark run. |

## Import Notes For 3.12

- Download MP3 files and Pixabay license certificates together.
- Store files under `assets/music/` using slot names, not original titles.
- For Content ID registered tracks, keep the certificate path in the eventual manifest.
- Cut `victory` to a short sting in import tooling; keep the source URL for traceability.
- Do not import AI-generated music unless no human-composed candidate remains.
