# Press Assets

Project-authored press/logo source assets.

Current assets:

- `thoth-logo.svg` - source logo, transparent background.
- `thoth-logo-512.png` - generated PNG export.
- `thoth-logo-1024.png` - generated PNG export.
- `thoth-logo-2048.png` - generated PNG export.

Regenerate PNG exports:

```sh
convert -background none assets/press/thoth-logo.svg -resize 512x256 assets/press/thoth-logo-512.png
convert -background none assets/press/thoth-logo.svg -resize 1024x512 assets/press/thoth-logo-1024.png
convert -background none assets/press/thoth-logo.svg -resize 2048x1024 assets/press/thoth-logo-2048.png
```
