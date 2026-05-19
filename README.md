# edenpack

A Minecraft 1.21.11 Fabric modpack targeting the [EdenMC](https://edenmc.miraheze.org/wiki/Main_Page) server.

Mod list is curated from Eden's [Recommended Mods](https://edenmc.miraheze.org/wiki/Recommended_Mods) page and vetted against the server [Rules](https://edenmc.miraheze.org/wiki/Rules).

## Status

- Target: Minecraft 1.21.11, Fabric 0.19.2
- Mods: 26 (Eden's list minus Xaero family + JourneyMap + 4 transitive deps + Iris)
- Output: `./edenpack.mrpack` (Modrinth format)

## Usage

```
./setup.sh                # build/export edenpack.mrpack
./setup.sh --upgrade      # bump pinned mods to latest matching MC version
./setup.sh --export-mods  # dump current pack to mods.yaml
```

Import the resulting `edenpack.mrpack` into Prism / PolyMC / Modrinth App.

### Releases

Tagged releases (`v*`) trigger `.github/workflows/release.yml`, which builds the pack in CI and attaches `edenpack-<tag>.mrpack` plus a SHA-256 sum to a GitHub Release. Pull the latest from [Releases](https://github.com/cwage/edencraft/releases) instead of building locally if you just want to play.

To cut a release locally:

```
git tag v1.0.0 && git push --tags
```

The tag's leading `v` is stripped before being written into `pack.toml` / the mrpack manifest (so `v1.0.0` → `versionId: 1.0.0`), but the release asset filename keeps the tag verbatim.

## What's bundled

- All 26 mods listed in `mods.yaml`, downloaded by the launcher on import.
- Sodium pinned to 0.8.11 via `mr_version:` (Voxy 0.2.15-beta rejects 0.8.12).
- **`shaderpacks/ComplementaryUnbound_r5.5.1.zip`** — bundled inline as an override; auto-installs to the client's shaderpacks folder. Enable in Video Settings → Shaders.
- **`config/civmodern.properties`** — pre-configured CivModern layout (radar bottom-right, built-in minimap disabled since JourneyMap fills that role). Bundled as a config override so every fresh import starts with a sane default.
- **`pack-root/options.txt`** — Minecraft client defaults including the JourneyMap keybind swap (`M` opens the fullscreen map; `J` left unbound). Bundled at `overrides/options.txt` so fresh imports start with the right keybind. Also captures general client prefs (fov, render distance, gui scale, etc.) as first-launch defaults — Minecraft persists player edits after that.

## Project layout

| Path | Purpose |
|---|---|
| `mods.yaml` | Curated mod list — source of truth. Edit this, then run `setup.sh`. |
| `setup.sh` | Idempotent builder/exporter. Calls packwiz under the hood. |
| `shaderpacks/` | Files dropped here get bundled into `overrides/shaderpacks/` of the mrpack. |
| `config/` | Same, but for `overrides/config/`. Use for pre-baked mod configs. |
| `resourcepacks/` | Same, but for `overrides/resourcepacks/`. |
| `pack-root/` | Single files (not directories) that should land at `.minecraft/` root — `options.txt` etc. |
| `edenpack/` | Generated packwiz pack state (pack.toml, index.toml, mods/*.pw.toml). Committed. |
| `AGENTS.md` | Working conventions for this repo. |

## Intentional omissions

- **Combat Radar** — CivModern already includes a radar.
- **Xaero's Minimap / World Map / XaeroPlus / Border Limit** — Eden's wiki recommends Xaero's, but we ship JourneyMap instead (preference, more mature codebase). JM and Xaero's are equally rule-compliant when configured; this is a deliberate trade-off — most of the Eden community uses Xaero's.
- **CivModern's built-in minimap** — disabled in our bundled config; JourneyMap fills that role.
- **Indium** — obsolete since Sodium 0.6 (which now ships native Fabric Rendering API support).

## Config notes for rule compliance

Most rule-compliance comes for free, but a couple of items need a config tweak after first launch — see [Eden's rules](https://edenmc.miraheze.org/wiki/Rules):

- **JourneyMap** — cave mode is allowed *only in the Nether*. In each non-Nether dimension, open the full map (`M`), click the gear → "Dimensions" → set cave layers off. Also under Map Options, hide Y-coordinate of other entities (Eden rules allow type/item/name/X/Z only, not Y).
- **Litematica** — printer / automatic block placement is only for vanity builds that don't affect gameplay.
