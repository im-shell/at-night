# Nobody-Home Environment Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat-box look and the mirror-void floor of `nobody-home` with real CC0 PBR textures, a night env map for reflections, and a GLTF car — while keeping the dark foggy horror mood and shipping bundled+offline for the Android/Capacitor target.

**Architecture:** A committed `fetch-assets.sh` downloads CC0 assets into `nobody-home/assets/`. three.js + the GLTF/RGBE loaders are vendored into `nobody-home/vendor/` so the game runs offline on-device. Inside `index.html`, an asset-loading layer (`loadPBR`/`loadGLTF`/`loadEnv`) plus a `Promise.all` loading gate replaces the inline flat materials; on any load failure it falls back to today's materials so the game always runs.

**Tech Stack:** three.js r0.160.0 (vendored), `GLTFLoader`, `RGBELoader`, `PMREMGenerator`, ambientCG CC0 PBR textures, PolyHaven CC0 night HDRI, ES module + importmap, no build step.

## Global Constraints

- **three.js version:** `0.160.0` exactly (matches current importmap) — vendored copy must be this version.
- **No build step / no npm:** single `index.html` + sibling `vendor/` and `assets/` folders, ES modules only.
- **Mood is non-negotiable:** scene stays dark/foggy. All loaded materials tinted darker via `material.color`; env map intensity kept low. Never raise ambient/exposure to "show off" textures.
- **Fog budget:** `FogExp2` density `0.085` — detail only matters within ~12–15 m. Do not add far-object detail.
- **Mobile-GPU aware, not size-aware:** download size is a non-concern; texture-memory/fill-rate is. Hero close surfaces 2K, everything else 1K. `LOW` quality mode (`localStorage nh_q==="LOW"`) drops to 1K + no env map + falls back toward flat materials.
- **Offline:** no runtime CDN fetches. All of three.js, loaders, textures, HDRI, models load from relative paths.
- **Graceful fallback:** any asset load failure logs and uses the pre-overhaul material/geometry; the game must never fail to start because an asset is missing.
- **Dev serving:** verify in a browser via `python3 -m http.server` from repo root (textures won't load on `file://`).

## Concrete Asset Manifest (verified reachable 2026-06-24)

ambientCG (download `https://ambientcg.com/get?file=<ID>_<RES>-JPG.zip`, maps used: `_Color`, `_NormalGL`, `_Roughness`, `_AmbientOcclusion`):

| Logical name | ambientCG ID | Res | Use |
|---|---|---|---|
| `asphalt` | `Asphalt031` | 2K | ground / road |
| `ground` | `Ground037` | 1K | dirt/verge |
| `siding` | `WoodSiding008` | 2K | house walls |
| `brick` | `Bricks075A` | 2K | house wall variant |
| `roof` | `RoofingTiles013A` | 1K | roofs |
| `wood` | `Wood066` | 1K | fences/porch/poles |
| `concrete` | `Concrete034` | 1K | water tower / spire / curbs |

PolyHaven HDRI: `cobblestone_street_night` 2K →
`https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/cobblestone_street_night_2k.hdr`

GLTF car: `https://threejs.org/examples/models/gltf/ferrari.glb` (verified 200; darkened in-material; drop-in swappable for a Kenney Car-Kit sedan later — same loader).

Vendored libs (download from jsDelivr at the pinned version):
- `https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js`
- `https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/controls/PointerLockControls.js`
- `https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/loaders/GLTFLoader.js`
- `https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/loaders/RGBELoader.js`

---

### Task 1: Asset fetch script + downloaded assets

**Files:**
- Create: `nobody-home/fetch-assets.sh`
- Create: `nobody-home/ASSETS.md`
- Create (generated): `nobody-home/assets/textures/<name>/{color,normal,roughness,ao}.jpg`, `nobody-home/assets/hdri/night.hdr`, `nobody-home/assets/models/car.glb`

**Interfaces:**
- Produces: an `assets/` tree with this exact layout, consumed by the loader layer in Task 3:
  - `assets/textures/{asphalt,ground,siding,brick,roof,wood,concrete}/{color,normal,roughness,ao}.jpg`
  - `assets/hdri/night.hdr`
  - `assets/models/car.glb`

- [ ] **Step 1: Write `nobody-home/fetch-assets.sh`**

```bash
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
for s in "${SETS[@]}"; do
  IFS=: read -r name id res <<<"$s"
  out="$TEX/$name"; mkdir -p "$out"
  if [ -f "$out/color.jpg" ]; then echo "skip $name"; continue; fi
  echo "fetch $name ($id $res)"
  curl -sSL --fail -m 120 "https://ambientcg.com/get?file=${id}_${res}-JPG.zip" -o "$tmp/$name.zip"
  unzip -oq "$tmp/$name.zip" -d "$tmp/$name"
  cp "$tmp/$name/${id}_${res}-JPG_Color.jpg"            "$out/color.jpg"
  cp "$tmp/$name/${id}_${res}-JPG_NormalGL.jpg"         "$out/normal.jpg"
  cp "$tmp/$name/${id}_${res}-JPG_Roughness.jpg"        "$out/roughness.jpg"
  cp "$tmp/$name/${id}_${res}-JPG_AmbientOcclusion.jpg" "$out/ao.jpg"
done

# Night HDRI (PolyHaven, CC0)
[ -f assets/hdri/night.hdr ] || curl -sSL --fail -m 120 \
  "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/cobblestone_street_night_2k.hdr" \
  -o assets/hdri/night.hdr

# Car model (three.js examples)
[ -f assets/models/car.glb ] || curl -sSL --fail -m 120 \
  "https://threejs.org/examples/models/gltf/ferrari.glb" -o assets/models/car.glb

echo "DONE"
```

- [ ] **Step 2: Write `nobody-home/ASSETS.md`** recording each asset's logical name, source URL, and license (all CC0 except the three.js example car — note it as "three.js examples, swappable"). Include one line per row of the manifest table above plus the HDRI and car.

- [ ] **Step 3: Run the fetch script**

Run: `bash nobody-home/fetch-assets.sh`
Expected: prints `fetch ...` per set then `DONE`, exit 0.

- [ ] **Step 4: Verify the asset tree**

Run:
```bash
find nobody-home/assets -type f | sort
test $(find nobody-home/assets/textures -name '*.jpg' | wc -l) -eq 28 && echo "TEX OK"
test -s nobody-home/assets/hdri/night.hdr && echo "HDRI OK"
node -e "const b=require('fs').readFileSync('nobody-home/assets/models/car.glb');if(b.slice(0,4).toString()!=='glTF')process.exit(1);console.log('GLB OK')"
```
Expected: 28 jpgs (7 sets × 4 maps), `TEX OK`, `HDRI OK`, `GLB OK`.

- [ ] **Step 5: Add `.gitignore` for binary assets, keep script as source of truth**

```bash
printf 'assets/\nvendor/\n' > nobody-home/.gitignore
```
Rationale: assets/vendor are reproducible from `fetch-assets.sh`; keep the repo lean and avoid committing large binaries. (If the user prefers committing binaries for offline-clone reliability, skip this step.)

- [ ] **Step 6: Commit**

```bash
git add nobody-home/fetch-assets.sh nobody-home/ASSETS.md nobody-home/.gitignore
git commit -m "feat(nobody-home): add CC0 asset fetch script + manifest"
```

---

### Task 2: Vendor three.js + loaders for offline use

**Files:**
- Modify: `nobody-home/fetch-assets.sh` (add a vendor section)
- Create (generated): `nobody-home/vendor/three.module.js`, `nobody-home/vendor/addons/controls/PointerLockControls.js`, `nobody-home/vendor/addons/loaders/GLTFLoader.js`, `nobody-home/vendor/addons/loaders/RGBELoader.js`
- Modify: `nobody-home/index.html:119-124` (importmap), `:126-127` (imports)

**Interfaces:**
- Produces: importmap names `three` → `./vendor/three.module.js` and `three/addons/` → `./vendor/addons/`, so all `import ... from 'three'`/`'three/addons/...'` resolve offline. Consumed by every task that imports a loader.

- [ ] **Step 1: Add a vendor section to `fetch-assets.sh`** (before the final `echo "DONE"`):

```bash
# --- vendored three.js (offline) ---
V=vendor; BASE="https://cdn.jsdelivr.net/npm/three@0.160.0"
mkdir -p "$V/addons/controls" "$V/addons/loaders"
[ -f "$V/three.module.js" ] || curl -sSL --fail -m 120 "$BASE/build/three.module.js" -o "$V/three.module.js"
[ -f "$V/addons/controls/PointerLockControls.js" ] || curl -sSL --fail -m 120 "$BASE/examples/jsm/controls/PointerLockControls.js" -o "$V/addons/controls/PointerLockControls.js"
[ -f "$V/addons/loaders/GLTFLoader.js" ] || curl -sSL --fail -m 120 "$BASE/examples/jsm/loaders/GLTFLoader.js" -o "$V/addons/loaders/GLTFLoader.js"
[ -f "$V/addons/loaders/RGBELoader.js" ] || curl -sSL --fail -m 120 "$BASE/examples/jsm/loaders/RGBELoader.js" -o "$V/addons/loaders/RGBELoader.js"
```

- [ ] **Step 2: Run the script to download vendor files**

Run: `bash nobody-home/fetch-assets.sh`
Expected: exit 0; vendor files present.

- [ ] **Step 3: Verify vendor files exist and are JS modules**

Run:
```bash
for f in vendor/three.module.js vendor/addons/controls/PointerLockControls.js vendor/addons/loaders/GLTFLoader.js vendor/addons/loaders/RGBELoader.js; do
  test -s "nobody-home/$f" && head -c 200 "nobody-home/$f" | grep -q . && echo "OK $f"; done
```
Expected: four `OK` lines.

- [ ] **Step 4: Point the importmap at vendored files** — replace `index.html:119-124`:

```html
<script type="importmap">
{ "imports": {
  "three": "./vendor/three.module.js",
  "three/addons/": "./vendor/addons/"
}}
</script>
```

- [ ] **Step 5: Verify the page still loads identically (no behavior change yet)**

Run: `python3 -m http.server 8000` (from repo root, background), then load `http://localhost:8000/nobody-home/` in a browser.
Expected: title screen renders, **zero red errors** in the `#err` overlay and zero console import errors. If the console names a missing relative dependency pulled in by an addon, add that exact file to the vendor section of `fetch-assets.sh`, re-run, and reload until clean.

- [ ] **Step 6: Commit**

```bash
git add nobody-home/index.html nobody-home/fetch-assets.sh
git commit -m "feat(nobody-home): vendor three.js + loaders for offline play"
```

---

### Task 3: Asset-loading layer + loading gate + env map

**Files:**
- Modify: `nobody-home/index.html:126-127` (add loader imports), and add a loader block after the imports; modify the existing flow so `start()`/world-build waits on `Promise.all`.
- Modify: `nobody-home/index.html` (add a loading-screen element near the other `.screen` divs around `:111`).

**Interfaces:**
- Produces:
  - `async function loadPBR(name, {repeat=[1,1], res})` → `MeshStandardMaterial` with `map/normalMap/roughnessMap/aoMap` from `assets/textures/<name>/`, `RepeatWrapping`, `repeat` applied, max anisotropy, `map.colorSpace=SRGBColorSpace`, data maps left linear, `color` tinted to `0x8a8a8a` (darkens for mood). On any texture error → resolves to a fallback flat material passed in.
  - `async function loadGLTF(url)` → `THREE.Group` (the loaded `scene`), or `null` on failure.
  - `async function loadEnv(url)` → sets `scene.environment` to a PMREM-filtered night HDRI (skipped when `LOW`), resolves either way.
  - `const ASSETS = {}` populated before world build; consumed by Tasks 4–7.

- [ ] **Step 1: Add loader imports** at `index.html:127` (after the PointerLockControls import):

```javascript
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RGBELoader } from 'three/addons/loaders/RGBELoader.js';
```

- [ ] **Step 2: Add a loading screen element** near the other screens (after the `#pause` block, before `#err`):

```html
<div class="screen" id="loading">
  <div class="title" style="font-size:clamp(22px,5vw,34px)">LOADING</div>
  <div class="sub" id="loadingSub">waking the street…</div>
</div>
```

- [ ] **Step 3: Add the loader layer** immediately after the QUALITY/renderer setup (after `index.html:144`, where `renderer` and `QUALITY` exist):

```javascript
/* ---------------- asset loading ---------------- */
const LOWQ = QUALITY==="LOW";
const texLoader = new THREE.TextureLoader();
const maxAniso = renderer.capabilities.getMaxAnisotropy();
const loadingSub = document.getElementById("loadingSub");
function tex(url, srgb){
  return new Promise(res=>{
    texLoader.load(url, t=>{
      t.wrapS=t.wrapT=THREE.RepeatWrapping; t.anisotropy=maxAniso;
      if(srgb) t.colorSpace=THREE.SRGBColorSpace;
      res(t);
    }, undefined, ()=>res(null));
  });
}
async function loadPBR(name, {repeat=[1,1]}={}, fallback){
  const base=`assets/textures/${name}`;
  const [c,n,r,a] = await Promise.all([
    tex(`${base}/color.jpg`, true), tex(`${base}/normal.jpg`,false),
    tex(`${base}/roughness.jpg`,false), tex(`${base}/ao.jpg`,false)
  ]);
  if(!c){ console.warn("PBR fallback:", name); return fallback; }
  for(const t of [c,n,r,a]) if(t) t.repeat.set(repeat[0],repeat[1]);
  return new THREE.MeshStandardMaterial({
    map:c, normalMap:n||null, roughnessMap:r||null, aoMap:a||null,
    color:0x8a8a8a, metalness:0.0, roughness:1.0
  });
}
async function loadGLTF(url){
  try{ const g=await new GLTFLoader().loadAsync(url); return g.scene; }
  catch(e){ console.warn("GLTF fallback:", url, e); return null; }
}
async function loadEnv(url){
  if(LOWQ) return;
  try{
    const hdr=await new RGBELoader().loadAsync(url);
    const pmrem=new THREE.PMREMGenerator(renderer);
    scene.environment=pmrem.fromEquirectangular(hdr).texture;
    scene.environmentIntensity=0.25; // keep dark; reflections only
    hdr.dispose(); pmrem.dispose();
  }catch(e){ console.warn("env fallback", e); }
}
const ASSETS={};
```

- [ ] **Step 4: Gate world build / start on asset loading.** Wrap the existing world-construction + first render in an async init. Add after `scene` exists and before houses/ground are built, load assets:

```javascript
async function loadAllAssets(){
  loadingSub.textContent="loading textures…";
  const R = LOWQ ? "1K":"2K"; // (resolution already baked per-set by fetch; flag reserved for future swap)
  ASSETS.asphalt  = await loadPBR("asphalt",  {repeat:[40,40]}, null);
  ASSETS.ground   = await loadPBR("ground",   {repeat:[30,30]}, null);
  ASSETS.siding   = await loadPBR("siding",   {repeat:[2,2]},   null);
  ASSETS.brick    = await loadPBR("brick",    {repeat:[2,2]},   null);
  ASSETS.roof     = await loadPBR("roof",     {repeat:[3,2]},   null);
  ASSETS.wood     = await loadPBR("wood",     {repeat:[1,4]},   null);
  ASSETS.concrete = await loadPBR("concrete", {repeat:[2,2]},   null);
  loadingSub.textContent="loading lighting…";
  await loadEnv("assets/hdri/night.hdr");
  loadingSub.textContent="loading props…";
  ASSETS.car = await loadGLTF("assets/models/car.glb");
}
```

- [ ] **Step 5: Call the gate, then reveal the title.** Find where the title screen is shown / game initialized and ensure `loadAllAssets()` runs first, hiding `#loading` on resolve:

```javascript
document.getElementById("loading").classList.remove("hide");
await loadAllAssets();
document.getElementById("loading").classList.add("hide");
```
(Place this so it runs once on boot, before the player can start. Keep the existing title/start logic after it. Materials in `ASSETS` are wired into geometry in Tasks 4–7; this task only proves loading + gating.)

- [ ] **Step 6: Verify the loading gate works**

Run: serve via `python3 -m http.server 8000`, load `http://localhost:8000/nobody-home/`.
Expected: a LOADING screen appears, then hides; title screen shows; **no red `#err` text**. In devtools console, confirm `scene.environment` is set (not null) on HIGH. Take a screenshot of the title screen.

- [ ] **Step 7: Commit**

```bash
git add nobody-home/index.html
git commit -m "feat(nobody-home): asset loader layer, loading gate, night env map"
```

---

### Task 4: Ground overhaul — kill mirror plane, apply wet asphalt

**Files:**
- Modify: `nobody-home/index.html:183-190` (ground + water plane)

**Interfaces:**
- Consumes: `ASSETS.asphalt` (from Task 3).

- [ ] **Step 1: Replace the ground + flood-sheen block** (`index.html:183-190`) with:

```javascript
/* ground (wet asphalt, real PBR; reflections come from env map) */
const groundMat = ASSETS.asphalt || new THREE.MeshStandardMaterial({color:0x0c0f15,roughness:0.7,metalness:0.0});
groundMat.roughness = 0.55; // slight wet sheen via env reflection, not a mirror
const ground=new THREE.Mesh(new THREE.PlaneGeometry(180,180),groundMat);
ground.rotation.x=-Math.PI/2; ground.position.y=0; ground.receiveShadow=true; scene.add(ground);
ground.geometry.setAttribute('uv2', ground.geometry.attributes.uv); // aoMap needs uv2
/* (flood-sheen mirror plane removed — it caused the unreadable shiny floor) */
```

- [ ] **Step 2: Verify the floor reads as ground, not a mirror**

Run: serve + load the game, start play, look down and around with the flashlight.
Expected: floor shows asphalt texture, dark and slightly wet from env reflection, no mirror-void. No `#err`. Take before/after screenshots (compare to the shiny original).

- [ ] **Step 3: Commit**

```bash
git add nobody-home/index.html
git commit -m "feat(nobody-home): real wet-asphalt ground, remove mirror plane"
```

---

### Task 5: Building materials (walls, roofs, porch, door)

**Files:**
- Modify: `nobody-home/index.html:192-209` (`wallMat`, `roofMat`, `makeHouse` body/roof/porch/door)

**Interfaces:**
- Consumes: `ASSETS.siding`, `ASSETS.brick`, `ASSETS.roof`, `ASSETS.wood`.

- [ ] **Step 1: Swap the shared building materials** at `index.html:193-194`:

```javascript
const wallMat = ASSETS.siding || new THREE.MeshStandardMaterial({color:0x14161d,roughness:0.9,metalness:0.0});
const wallMatB = ASSETS.brick || wallMat;
const roofMat = ASSETS.roof  || new THREE.MeshStandardMaterial({color:0x0d0f15,roughness:1.0});
```

- [ ] **Step 2: Give house meshes uv2 for AO and vary wall material.** In `makeHouse` (`:201`), after creating `body`, add `body.geometry.setAttribute('uv2', body.geometry.attributes.uv);` and pick `wallMat` vs `wallMatB` deterministically (e.g. by house index/position parity) so the street isn't uniform. Apply the same `uv2` line to the `roof` mesh (`:202`) and keep the porch/door using `ASSETS.wood`/dark material.

```javascript
const useBrick = (Math.abs(Math.round(x))+Math.abs(Math.round(z)))%2===0;
const body=new THREE.Mesh(new THREE.BoxGeometry(w,h,d), useBrick?wallMatB:wallMat);
body.geometry.setAttribute('uv2', body.geometry.attributes.uv);
body.position.y=h/2; body.castShadow=true; body.receiveShadow=true; g.add(body);
```

- [ ] **Step 3: Verify houses read as real walls/roofs**

Run: serve + load + walk up to a house with the flashlight.
Expected: siding/brick + shingle textures visible up close, still dark; some houses brick, some siding. No `#err`. Screenshot.

- [ ] **Step 4: Commit**

```bash
git add nobody-home/index.html
git commit -m "feat(nobody-home): textured house walls and roofs"
```

---

### Task 6: Fences, lamp poles, water tower, spire (wood + concrete)

**Files:**
- Modify: `nobody-home/index.html:220` (`fenceMat`), `:235-245` (`watertower`, `spire`), `:249` (`streetlamp` pole)

**Interfaces:**
- Consumes: `ASSETS.wood`, `ASSETS.concrete`.

- [ ] **Step 1: Swap structural materials.** Replace `fenceMat` (`:220`) source to `ASSETS.wood || <existing>`; in `watertower` swap the tank/`MeshStandardMaterial` to `ASSETS.concrete || <existing>`; in `spire` swap the body/tower to `ASSETS.concrete || wallMat`. Add `uv2` to any mesh that uses an AO-mapped material:

```javascript
const fenceMat = ASSETS.wood || new THREE.MeshStandardMaterial({color:0x10131a,roughness:1});
const concreteMat = ASSETS.concrete || new THREE.MeshStandardMaterial({color:0x161a22,roughness:1});
```
(Apply `mesh.geometry.setAttribute('uv2', mesh.geometry.attributes.uv)` after creating tank/spire-body meshes.)

- [ ] **Step 2: Verify**

Run: serve + load + approach a fence, the water tower, and the church spire.
Expected: weathered-wood fences and concrete structures read as real materials, still dark/foggy. No `#err`. Screenshot.

- [ ] **Step 3: Commit**

```bash
git add nobody-home/index.html
git commit -m "feat(nobody-home): wood/concrete on fences, water tower, spire"
```

---

### Task 7: GLTF car swap

**Files:**
- Modify: `nobody-home/index.html:253-261` (`car`)

**Interfaces:**
- Consumes: `ASSETS.car` (a `THREE.Group` or `null`).

- [ ] **Step 1: Use the GLTF model with box fallback.** Replace the body of `car(x,z)` so it clones `ASSETS.car` when present, scales/orients it to fit the ~2×4.4 footprint, darkens its materials for mood, enables `castShadow`, and falls back to the existing box car when `ASSETS.car` is null:

```javascript
function car(x,z){
  const g=new THREE.Group(); g.position.set(x,0,z);
  if(ASSETS.car){
    const m=ASSETS.car.clone(true);
    m.scale.setScalar(0.5);                 // ferrari.glb ~ fits street car footprint
    m.traverse(o=>{ if(o.isMesh){ o.castShadow=true;
      if(o.material){ o.material=o.material.clone(); o.material.color&&o.material.color.multiplyScalar(0.35); o.material.metalness=0.3; o.material.roughness=0.6; } }});
    g.add(m);
  } else {
    const b=new THREE.Mesh(new THREE.BoxGeometry(2,0.9,4.4),new THREE.MeshStandardMaterial({color:0x191b22,roughness:0.6,metalness:0.3})); b.position.y=0.7; b.castShadow=true; g.add(b);
    const cab=new THREE.Mesh(new THREE.BoxGeometry(1.8,0.8,2.2),new THREE.MeshStandardMaterial({color:0x0d0f14,roughness:0.3,metalness:0.4})); cab.position.set(0,1.45,-0.2); g.add(cab);
  }
  scene.add(g); return g;
}
```
(If the original `car` adds wheels/extra meshes after the body, fold them into the `else` box-fallback branch only.)

- [ ] **Step 2: Verify the car renders**

Run: serve + load + walk to a parked car.
Expected: a real 3D car (dark) sits where the box car was; fallback box appears only if the GLB failed. No `#err`. Screenshot.

- [ ] **Step 3: Commit**

```bash
git add nobody-home/index.html
git commit -m "feat(nobody-home): GLTF car model with box fallback"
```

---

### Task 8: LOW quality mode + mood/perf final pass

**Files:**
- Modify: `nobody-home/index.html` (loader layer + any tints needing adjustment)

**Interfaces:**
- Consumes: all `ASSETS.*`; honors `localStorage nh_q`.

- [ ] **Step 1: Confirm LOW path.** `loadEnv` already early-returns on `LOWQ` (Task 3). Ensure that with `nh_q==="LOW"`: env map is off, and the scene still renders correctly using textures without reflections (materials must not depend on `scene.environment`). No code change if Task 3 holds; otherwise guard any env-dependent tweak.

- [ ] **Step 2: Mood pass.** Compare HIGH screenshots against the original mood. If textures lifted the blacks, lower `groundMat.color`/wall `color` multipliers (e.g. `0x8a8a8a`→`0x6a6a6a`) and/or `scene.environmentIntensity` (0.25→0.18) until the scene is as dark/threatening as before. Keep fog unchanged.

- [ ] **Step 3: Verify both quality modes**

Run:
```javascript
// in devtools console, then reload for each:
localStorage.setItem('nh_q','HIGH'); // reload → textured + reflections
localStorage.setItem('nh_q','LOW');  // reload → textured, no env map, runs smooth
```
Expected: HIGH looks rich + dark with wet reflections; LOW renders without env map and without errors. Capture one screenshot each. Confirm no `#err` in either.

- [ ] **Step 4: Final mood/readability sign-off.** Side-by-side the original shiny-floor screenshot vs the new ground: floor must read clearly as wet asphalt (not a mirror-void), buildings/props read as real materials, and the scene is still dark and scary.

- [ ] **Step 5: Commit**

```bash
git add nobody-home/index.html
git commit -m "feat(nobody-home): LOW quality mode + final mood/readability pass"
```

---

## Self-Review Notes

- **Spec coverage:** assets fetch (T1) ✓; vendoring/offline (T2) ✓; loader layer + gate + env map (T3) ✓; remove mirror plane + ground (T4) ✓; walls/roofs (T5) ✓; fences/concrete structures (T6) ✓; GLTF car (T7) ✓; LOW mode + mood preservation (T8) ✓; fog/dark-tint constraints enforced via `color` multiply + `environmentIntensity`.
- **Verification reality:** this is a browser graphics task with no unit-test harness, so each task's "test" is a runnable shell assertion (file/format checks) where possible and a served-in-browser screenshot + `#err`/console-error check for visual changes. This is the honest verification path, not fabricated pytest.
- **aoMap caveat:** three.js `aoMap` requires a second UV set; every AO-mapped mesh gets `uv2` copied from `uv` (T4–T6).
- **Type consistency:** `ASSETS.{asphalt,ground,siding,brick,roof,wood,concrete,car}` defined in T3 and consumed by exactly those names in T4–T7; `loadPBR/loadGLTF/loadEnv` signatures stable.
