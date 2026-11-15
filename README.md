# HOST CASCADE

**Possess enemies. Leap-chain into bigger bodies. Mutate between biomes. Extract rich — or greed for the Apex Host.**

Godot **4.7.2** · typed GDScript · procedural art/audio

## Why it’s sticky
- Worm form is a ticking bomb — leap or die (with short grace after spawns/ejects)
- Hosts are temporary thrones with unique kits
- Combos multiply essence when you chain leaps
- Mutations stick to *you* across the run and unlock in the lab
- End-of-Cathedral fork: **Extract** safely or **Greed** for Apex

## Play
```bash
godot --path .
```

| Action | Input |
|--------|--------|
| Move | WASD / Arrows |
| Aim | Mouse |
| Attack | Left Click / J |
| Leap / possess | Space / Shift |
| Eject | F / E |
| Pause | Esc |

## Run structure
**Sewers (3 waves)** → mutation vault → **Neon Sprawl (3)** → vault → **Cathedral (4)** → **Extract or Apex**

## Balance (1.0 ship)
- Worm timer **3.8s** (+0.6 with Second Lung); grace on biome/wave start and eject
- Leap magnet + near-miss combo forgiveness
- Tutorial grunt spawns near you at run start
- Wave size caps at 9

## Dev
```bash
godot --path . -- --ship-test   # CI full-run (shop→apex→win)
godot --path . -- --autoplay
```

## Export
Use `export_presets.cfg` with Godot **4.7.2** export templates → output to `export/`.
