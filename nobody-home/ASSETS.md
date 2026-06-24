# Asset Manifest

CC0 PBR textures and HDR environment for nobody-home.

| Logical Name | Source URL | License |
|--------------|-----------|---------|
| asphalt | https://ambientcg.com/get?file=Asphalt031_2K-JPG.zip | CC0 |
| ground | https://ambientcg.com/get?file=Ground037_1K-JPG.zip | CC0 |
| siding | https://ambientcg.com/get?file=WoodSiding008_2K-JPG.zip | CC0 |
| brick | https://ambientcg.com/get?file=Bricks075A_2K-JPG.zip | CC0 |
| roof | https://ambientcg.com/get?file=RoofingTiles013A_1K-JPG.zip | CC0 |
| wood | https://ambientcg.com/get?file=Wood066_1K-JPG.zip | CC0 |
| concrete | https://ambientcg.com/get?file=Concrete034_1K-JPG.zip | CC0 |
| night (HDRI) | https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/cobblestone_street_night_2k.hdr | CC0 (PolyHaven) |
| car (GLB) | https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/ToyCar | CC0 1.0 (Khronos ToyCar) — non-Draco; `Fabric` cloth + Camera nodes stripped at load |

> Note: `wood` (Wood066) and `concrete` (Concrete034) ship without an
> AmbientOcclusion map. The fetch script skips the missing `ao.jpg` for these
> sets (only color/normal/roughness are produced); the loader tolerates a
> missing AO map.
