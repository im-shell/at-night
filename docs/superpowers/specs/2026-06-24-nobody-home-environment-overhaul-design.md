# Nobody-Home — Realistic Environment Overhaul (Design Spec)

**Date:** 2026-06-24
**Game:** `nobody-home` (foggy-suburb horror, three.js, eventual Android/Capacitor target)
**Status:** Approved design — pending spec review

## Problem

The world is built entirely from flat procedural boxes/planes. The ground reads as a
shiny mirror: it is two stacked planes — a `MeshStandardMaterial` asphalt
(`roughness 0.45, metalness 0.35`) plus a second semi-transparent "flood sheen" plane
(`roughness 0.12, metalness 0.7`, `index.html:188–190`). The second plane acts like a
mirror with nothing real to reflect, so the floor is hard to read. The player wants the
environment to look real — using real image/GLTF assets — rather than untextured boxes.

## Goal

A **full environment overhaul** using **real CC0 PBR textures and GLTF models**, while
**preserving the dark, foggy, menacing horror mood**. Realistic but wet, grungy, and dim
— not a bright asset-store demo.

## Hard Constraints / Art Direction

- **Fog dominates.** `FogExp2` density `0.085` hides everything past ~12–15 m. Detail only
  matters in the close zone around the player + flashlight cone. Budget detail accordingly;
  do not lavish geometry/texture on far objects the fog erases.
- **Stay dark.** All assets tinted darker via material `color` multiply; low/no emissive.
  The new look must not wash out the scare atmosphere.
- **Mobile-GPU aware, not size-aware.** Download size is explicitly a non-concern (it ships
  bundled inside an Android APK). Runtime cost on a phone GPU (texture memory, shadow/fill
  rate) IS a concern. Hero close surfaces get 2K maps; everything else 1K; `LOW` quality
  mode drops to 1K/no-envmap.

## Platform Notes

- **Android (Capacitor):** the webview serves bundled files from a local origin, so relative
  `assets/...` paths load with no `file://`/CORS issue. No HTTP concern on device.
- **Desktop dev:** must be served over HTTP (`python3 -m http.server`) — textures won't load
  from `file://`. Already the dev workflow.
- **Offline + vendoring (in scope):** three.js and its addons are currently imported from the
  jsDelivr CDN via importmap. The new loaders (`GLTFLoader`, `RGBELoader`) come from the same
  CDN addons path and would **fail offline on device**. As part of this work we vendor
  `three.module.js` + the needed addon loaders into `nobody-home/vendor/` and point the
  importmap at relative paths, so the game is fully offline-capable.

## Architecture

### New files
```
nobody-home/
  index.html            (modified)
  vendor/               three.module.js + GLTFLoader.js + RGBELoader.js + deps
  assets/
    textures/<material>/{color,normal,roughness,ao}.jpg
    hdri/night.hdr
    models/*.glb
  fetch-assets.sh       committed, reproducible re-download of every CC0 asset + attribution
  ASSETS.md             source URLs + licenses (CC0) for each asset
```

### In `index.html`, an asset-loading layer (added near top of the module)
- `loadPBR(name, {repeat, srgb})` → returns a configured `MeshStandardMaterial`:
  loads color/normal/roughness/ao, sets `wrapS/wrapT = RepeatWrapping`, applies `repeat`,
  sets `colorSpace` (sRGB for color, linear for data maps), tints `color` darker.
- `loadGLTF(url)` → resolves a cloneable scene.
- `loadEnv(url)` → `RGBELoader` → `PMREMGenerator` → `scene.environment` (subtle, low
  intensity) for wet-surface reflections.
- **Loading gate:** a loading screen; `Promise.all([...])` of all asset loads resolves
  before `start()`. On any failure, log and **fall back to the current flat materials**
  (game still runs).

### Rendering changes
- **Delete** the fake flood-sheen mirror plane (`index.html:188–190`).
- Ground becomes a real wet-asphalt PBR material; wetness/reflection now comes from the
  **night HDRI env map**, not a mirror plane — this fixes readability.
- Keep `useLegacyLights=true` (the scene's dark lighting is tuned around it); env map is
  added at low intensity so reflections read without lifting the blacks.

## Materials (CC0, ambientCG, 1K/2K JPG, maps: Color + NormalGL + Roughness + AO)

| Surface | Asset family | Res |
|---|---|---|
| Ground / road | Wet asphalt (+ cracked/marking variant) | 2K |
| Grass/dirt verge | Dark wet ground / sparse grass | 1K |
| House walls | Painted wood siding / brick | 2K (near) |
| Roofs | Asphalt shingle | 1K |
| Fences / porch / lamp poles | Weathered wood + dark metal | 1K |
| Concrete (water tower, curbs, spire) | Dark concrete | 1K |

Plus **one night HDRI** (PolyHaven, 1–2K) as `scene.environment`.

## Props → GLTF (CC0, Quaternius/Kenney)

- Replace box `car()` with a low-poly GLTF car (instanced/cloned for the few parked cars).
- Optional: streetlamp + foliage/bush props near the path.
- Distant fog-hidden props stay as boxes — no detail wasted where it can't be seen.

## Asset Sourcing (verified reachable)

- **ambientCG API** (`/api/v2/full_json`) → resolves real 1K/2K JPG zip download URLs.
  Verified: Asphalt031 set downloads + unzips with full PBR maps. CC0.
- **PolyHaven API** (`api.polyhaven.com`) → night HDRI. CC0.
- **GitHub-raw / Quaternius / Kenney** → CC0 GLTF models.
- `fetch-assets.sh` curls each, unzips, keeps only the maps we use (color/normal/roughness/ao),
  discards displacement/blend/usdc to keep the tree clean.

## Performance / Quality Modes

- `HIGH` (default): 2K hero + 1K rest, env map on, shadows on.
- `LOW`: 1K everywhere or color-only, env map off, falls back toward current flat look.
- Mipmaps + anisotropy on tiling ground for clean grazing angles.

## Out of Scope

- Rewriting lighting model / switching to physically-correct lights.
- New gameplay, AI, or level-layout changes.
- Sky/weather systems beyond the env map.

## Success Criteria

1. Floor reads clearly as wet ground (no mirror-void), still dark and wet.
2. Houses/roofs/fences/props read as real materials, not flat boxes, within the visible
   (fog-limited) zone.
3. Mood preserved — scene stays dark and threatening.
4. Runs on the Android/Capacitor build with bundled assets, fully offline (vendored three.js).
5. `LOW` mode keeps weak phones playable.
6. `fetch-assets.sh` reproducibly rebuilds `assets/` with CC0 attribution recorded.
