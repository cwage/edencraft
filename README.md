# edenpack

A Minecraft 1.21.11 Fabric modpack targeting the [EdenMC](https://edenmc.miraheze.org/wiki/Main_Page) server.

Mod list is curated from Eden's [Recommended Mods](https://edenmc.miraheze.org/wiki/Recommended_Mods) page and vetted against the server [Rules](https://edenmc.miraheze.org/wiki/Rules).

## Status

- Target: Minecraft 1.21.11
- Modloader: Fabric
- Tooling: packwiz + Modrinth export (`.mrpack`)

## Usage

```
./setup.sh              # build/export edenpack.mrpack
./setup.sh --upgrade    # bump pinned mods to latest matching MC version
./setup.sh --export-mods  # dump current pack to mods.yaml
```

Output lands in `./edenpack.mrpack` — import via Prism / MultiMC / Modrinth App.

## Files

- `setup.sh` — idempotent builder/exporter
- `mods.yaml` — curated mod list (source of truth; edit this, not the generated `.pw.toml` files)
- `AGENTS.md` — project conventions

## Intentional omissions

- **Combat Radar** — CivModern already includes a radar.
- **Iris Shaders** — not on Eden's recommended list. Add separately if you use shaders.
- **JourneyMap** — Eden recommends Xaero's World Map + Minimap instead.
- **Indium** — obsolete since Sodium 0.6 (which now ships native Fabric Rendering API support).

## Config notes for rule compliance

A few mods need configuration after first launch to stay within [Eden's rules](https://edenmc.miraheze.org/wiki/Rules):

- **Xaero's World Map / Minimap** — cave mode allowed *in the Nether only*. Disable cave mode elsewhere.
- **CivModern radar** — must show only entity type/item/name/X/Z, not Y. Default config is compliant.
- **Litematica** — printer / automatic block placement is only for vanity builds that don't affect gameplay.
