#!/usr/bin/env bash
# Reproducibly downloads all CC0 assets for nobody-home. Re-runnable; skips existing.
# Sources: ambientCG (CC0), PolyHaven (CC0), three.js examples. See ASSETS.md.
set -euo pipefail
cd "$(dirname "$0")"
TEX="assets/textures"; mkdir -p "$TEX" assets/hdri assets/models vendor

# name:ID:RES  (ambientCG)
SETS=(
  "asphalt:Asphalt031:2K"
  "ground:Ground037:1K"
  "siding:WoodSiding008:2K"
  "brick:Bricks075A:2K"
  "roof:RoofingTiles013A:1K"
  "wood:Wood066:1K"
  "concrete:Concrete034:1K"
)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
copymap(){ if [ -f "$1" ]; then cp "$1" "$2"; else echo "   (no $(basename "$2") for $name)"; fi; }
for s in "${SETS[@]}"; do
  IFS=: read -r name id res <<<"$s"
  out="$TEX/$name"; mkdir -p "$out"
  if [ -f "$out/color.jpg" ]; then echo "skip $name"; continue; fi
  echo "fetch $name ($id $res)"
  curl -sSL --fail -m 120 "https://ambientcg.com/get?file=${id}_${res}-JPG.zip" -o "$tmp/$name.zip"
  unzip -oq "$tmp/$name.zip" -d "$tmp/$name"
  copymap "$tmp/$name/${id}_${res}-JPG_Color.jpg"            "$out/color.jpg"
  copymap "$tmp/$name/${id}_${res}-JPG_NormalGL.jpg"         "$out/normal.jpg"
  copymap "$tmp/$name/${id}_${res}-JPG_Roughness.jpg"        "$out/roughness.jpg"
  copymap "$tmp/$name/${id}_${res}-JPG_AmbientOcclusion.jpg" "$out/ao.jpg"
done

# Night HDRI (PolyHaven, CC0)
[ -f assets/hdri/night.hdr ] || curl -sSL --fail -m 120 \
  "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/cobblestone_street_night_2k.hdr" \
  -o assets/hdri/night.hdr

# Car model (three.js examples)
[ -f assets/models/car.glb ] || curl -sSL --fail -m 120 \
  "https://threejs.org/examples/models/gltf/ferrari.glb" -o assets/models/car.glb

# --- vendored three.js (offline) ---
V=vendor; BASE="https://cdn.jsdelivr.net/npm/three@0.160.0"
mkdir -p "$V/addons/controls" "$V/addons/loaders" "$V/addons/utils"
[ -f "$V/three.module.js" ] || curl -sSL --fail -m 120 "$BASE/build/three.module.js" -o "$V/three.module.js"
[ -f "$V/addons/controls/PointerLockControls.js" ] || curl -sSL --fail -m 120 "$BASE/examples/jsm/controls/PointerLockControls.js" -o "$V/addons/controls/PointerLockControls.js"
[ -f "$V/addons/loaders/GLTFLoader.js" ] || curl -sSL --fail -m 120 "$BASE/examples/jsm/loaders/GLTFLoader.js" -o "$V/addons/loaders/GLTFLoader.js"
[ -f "$V/addons/loaders/RGBELoader.js" ] || curl -sSL --fail -m 120 "$BASE/examples/jsm/loaders/RGBELoader.js" -o "$V/addons/loaders/RGBELoader.js"
[ -f "$V/addons/utils/BufferGeometryUtils.js" ] || curl -sSL --fail -m 120 "$BASE/examples/jsm/utils/BufferGeometryUtils.js" -o "$V/addons/utils/BufferGeometryUtils.js"

echo "DONE"
