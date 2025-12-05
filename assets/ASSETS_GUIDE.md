# Vecinus Visual Kit

This guide lists the production assets required by the new premium UI and the prompts you can use in tools such as Midjourney, DALL·E or Figma/Illustrator to recreate them. Export everything in 1x/2x/3x for Retina displays and keep the naming structure below so Flutter can load them automatically.

## Asset Checklist

| Path | Purpose | Notes |
| --- | --- | --- |
| `assets/images/logo_1x.png` | Primary logo (1x) | 512×512 px |
| `assets/images/logo_2x.png` | Primary logo (2x) | 1024×1024 px |
| `assets/images/logo_3x.png` | Primary logo (3x) | 1536×1536 px |
| `assets/images/splash_background.svg` | Splash gradient waves | Use as background + shader |
| `assets/images/waves_light.svg` | Light mode background texture | Optional overlay for dashboard |
| `assets/images/waves_dark.svg` | Dark mode background texture | Low-opacity overlay |
| `assets/lottie/particles.json` | Floating particles for splash | 24–30 fps, loopable |

> Place exported files inside the folders already referenced by `pubspec.yaml` (`assets/images`, `assets/icons`, `assets/lottie`). Keep alpha transparency for overlays.

## Prompt Library

**LOGO**
```
minimalist geometric logo for a condominium management mobile app, soft fintech aesthetic, high contrast sky-blue (#1d9bf0), vector, ultra crisp, retina-ready, centered mark, clean edges, 2D modern icon, suitable for splash screen.
```

**SPLASH BACKGROUND**
```
soft flowing gradient background in lilac (#eff2ff) and sky-blue (#1d9bf0), abstract waves, glowing edges, premium fintech mobile style, retina ready 300dpi, seamless, ultra clean.
```

**DARK MODE BACKGROUND**
```
deep navy gradient (#0a0f1f to #121212), subtle particles, elegant glow, premium app wallpaper, retina 3x resolution.
```

**LOTTIE PARTICLES**
```
animated floating particles in soft blue and lilac colors, minimal motion, smooth easing, suitable for splashscreen animation, lottie json style.
```

## Export Tips

- Keep corner radii at 24 px to match the card look.
- When exporting SVG waves, remove embedded rasters and keep fills editable.
- For the particles animation, prefer After Effects + Bodymovin to keep the JSON file under 200 KB.
- Always test assets on both light/dark themes inside `AnimatedSplashScreen` and the dashboard hero cards for visual parity.
