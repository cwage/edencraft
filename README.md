# edenpack

A Minecraft 1.21.11 Fabric modpack targeting the [EdenMC](https://edenmc.miraheze.org/wiki/Main_Page) server.

Mod list is curated from Eden's [Recommended Mods](https://edenmc.miraheze.org/wiki/Recommended_Mods) page and vetted against the server [Rules](https://edenmc.miraheze.org/wiki/Rules).

## Status

- Target: Minecraft 1.21.11, Fabric 0.19.2
- Mods: 29 (24 from Eden's list + 4 transitive deps + Iris)
- Output: `./edenpack.mrpack` (Modrinth format)

## Usage

```
./setup.sh                # build/export edenpack.mrpack
./setup.sh --upgrade      # bump pinned mods to latest matching MC version
./setup.sh --export-mods  # dump current pack to mods.yaml
```

Import the resulting `edenpack.mrpack` into Prism / PolyMC / Modrinth App.

## What's bundled

- All 29 mods listed in `mods.yaml`, downloaded by the launcher on import.
- Sodium pinned to 0.8.11 via `mr_version:` (Voxy 0.2.15-beta rejects 0.8.12).
- **`shaderpacks/ComplementaryUnbound_r5.5.1.zip`** — bundled inline as an override; auto-installs to the client's shaderpacks folder. Enable in Video Settings → Shaders.
- **`config/civmodern.properties`** — pre-configured CivModern layout (radar bottom-right). Bundled as a config override so every fresh import starts with a sane default.

## Project layout

| Path | Purpose |
|---|---|
| `mods.yaml` | Curated mod list — source of truth. Edit this, then run `setup.sh`. |
| `setup.sh` | Idempotent builder/exporter. Calls packwiz under the hood. |
| `shaderpacks/` | Files dropped here get bundled into `overrides/shaderpacks/` of the mrpack. |
| `config/` | Same, but for `overrides/config/`. Use for pre-baked mod configs. |
| `resourcepacks/` | Same, but for `overrides/resourcepacks/`. |
| `edenpack/` | Generated packwiz pack state (pack.toml, index.toml, mods/*.pw.toml). Committed. |
| `AGENTS.md` | Working conventions for this repo. |

## Intentional omissions

- **Combat Radar** — CivModern already includes a radar.
- **JourneyMap** — Eden's wiki recommends Xaero's World Map + Minimap instead.
- **Indium** — obsolete since Sodium 0.6 (which now ships native Fabric Rendering API support).

## Config notes for rule compliance

Most rule-compliance comes for free, but a couple of items need a config tweak after first launch — see [Eden's rules](https://edenmc.miraheze.org/wiki/Rules):

- **Xaero's Minimap & World Map** — cave mode is allowed *only in the Nether*. Disable cave mode for the overworld in both mods (settings live separately per mod: minimap config via `Y`, world map config via `M` then the cog).
- **CivModern minimap** — defaults to top-right, overlaps with Xaero's. Bundled config keeps it enabled; toggle off in ESC → Mod Menu → CivModern → Map if you'd rather only have Xaero's.
- **Litematica** — printer / automatic block placement is only for vanity builds that don't affect gameplay.
