#!/usr/bin/env bash
set -euo pipefail

# edenpack builder/exporter — Eden MC (Fabric, MC 1.21.8)

PACK_NAME="edenpack"
MC_VERSION="1.21.11"

# Modloader selection: fabric | neoforge | forge
MODLOADER="fabric"

# Loader version pins (pick the one matching MODLOADER)
FABRIC_LOADER="0.19.2"
NEOFORGE_VERSION="21.1.72"
FORGE_VERSION=""  # Not recommended for MC 1.21; prefer NeoForge

AUTHOR="cwage"
OUT_DIR="$PWD"
PACK_DIR="$OUT_DIR/$PACK_NAME"
MRPACK="$OUT_DIR/${PACK_NAME}.mrpack"
PW="packwiz -y"
MODS_YAML="$OUT_DIR/mods.yaml"

UPGRADE=0
EXPORT=0
UPGRADE_ONLY=""
declare -A UPGRADE_ONLY_SET=()

usage() {
  cat <<EOF
Usage: ./setup.sh [--mc-version X] [--modloader fabric|neoforge|forge] [--loader-version X] [--upgrade] [--upgrade-only a,b] [--export-mods]

  --mc-version      Override Minecraft version (default: $MC_VERSION)
  --modloader       fabric | neoforge | forge (default: $MODLOADER)
  --loader-version  Loader version matching selected modloader
  --upgrade         Update pinned mods to latest (re-adds each mod)
  --upgrade-only    Comma-separated slugs to upgrade (others stay pinned)
  --export-mods     Generate mods.yaml from current pack and exit
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mc-version)
      MC_VERSION="${2:?missing value}"; shift 2 ;;
    --modloader)
      MODLOADER="${2:?missing value}"; shift 2 ;;
    --loader-version)
      case "$MODLOADER" in
        fabric) FABRIC_LOADER="${2:?missing value}" ;;
        neoforge) NEOFORGE_VERSION="${2:?missing value}" ;;
        forge) FORGE_VERSION="${2:?missing value}" ;;
        *) echo "Unknown modloader: $MODLOADER"; exit 1 ;;
      esac
      shift 2 ;;
    --upgrade)
      UPGRADE=1; shift ;;
    --upgrade-only)
      UPGRADE_ONLY="${2:-}"; shift 2 ;;
    --export-mods)
      EXPORT=1; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

# Build selection set if --upgrade-only was provided
if [[ -n "$UPGRADE_ONLY" ]]; then
  UPGRADE_ONLY=$(printf '%s' "$UPGRADE_ONLY" | tr -d ' \t\r\n')
  IFS=',' read -r -a __uo_arr <<< "$UPGRADE_ONLY"
  declare -A UPGRADE_ONLY_SET
  for __slug in "${__uo_arr[@]}"; do
    [[ -z "$__slug" ]] && continue
    UPGRADE_ONLY_SET["$__slug"]=1
  done
fi

echo "==> Reset"
rm -f "$MRPACK"
mkdir -p "$PACK_DIR"
cd "$PACK_DIR"

REINIT=""

init_pack() {
  local ok=false
  for attempt in 1 2; do
    [[ $attempt -gt 1 ]] && echo "    Init attempt $attempt/2..." && sleep 2
    case "$MODLOADER" in
      fabric)
        $PW init \
          ${REINIT:+-r} \
          --name "$PACK_NAME" \
          --author "$AUTHOR" \
          --version "0.0.1" \
          --mc-version "$MC_VERSION" \
          --modloader fabric \
          --fabric-version "$FABRIC_LOADER" && ok=true && break ;;
      neoforge)
        $PW init \
          ${REINIT:+-r} \
          --name "$PACK_NAME" \
          --author "$AUTHOR" \
          --version "0.0.1" \
          --mc-version "$MC_VERSION" \
          --modloader neoforge \
          --neoforge-version "$NEOFORGE_VERSION" && ok=true && break ;;
      forge)
        $PW init \
          ${REINIT:+-r} \
          --name "$PACK_NAME" \
          --author "$AUTHOR" \
          --version "0.0.1" \
          --mc-version "$MC_VERSION" \
          --modloader forge \
          --forge-version "${FORGE_VERSION:?Forge version required for --modloader forge}" && ok=true && break ;;
      *) echo "Unknown modloader: $MODLOADER"; exit 1 ;;
    esac
  done
  if [[ "$ok" != true ]]; then
    echo "ERROR: Failed to initialize pack"
    exit 1
  fi
}

if [[ ! -f "$PACK_DIR/pack.toml" ]]; then
  echo "==> Init pack (MC $MC_VERSION, $MODLOADER)"
  init_pack
  echo "==> Accept MC family"
  case "$MC_VERSION" in
    1.21.*|1.21) base="1.21" ;;
    1.20.*|1.20) base="1.20" ;;
    *) base="${MC_VERSION%%.*}.${MC_VERSION#*.}" ;;
  esac
  $PW settings acceptable-versions --add "$base" || true
  $PW settings acceptable-versions --add "$MC_VERSION" || true
else
  echo "==> Pack exists; verifying versions"
  desired_loader_key=""
  desired_loader_version=""
  case "$MODLOADER" in
    fabric) desired_loader_key="fabric"; desired_loader_version="$FABRIC_LOADER" ;;
    neoforge) desired_loader_key="neoforge"; desired_loader_version="$NEOFORGE_VERSION" ;;
    forge) desired_loader_key="forge"; desired_loader_version="$FORGE_VERSION" ;;
  esac
  current_loader_key=$(awk -F'=' '/^\[versions\]/{in_v=1;next} /^\[/{in_v=0} in_v && /^(fabric|neoforge|forge)[[:space:]]*=/{gsub(/[[:space:]"]/,"",$1);print $1; exit}' pack.toml || true)
  current_loader_version=$(awk -F'=' -v key="$current_loader_key" '/^\[versions\]/{in_v=1;next} /^\[/{in_v=0} in_v && $1 ~ key {gsub(/[[:space:]"]/,"",$2);print $2; exit}' pack.toml || true)
  current_mc_version=$(awk -F'=' '/^\[versions\]/{in_v=1;next} /^\[/{in_v=0} in_v && /^minecraft[[:space:]]*=/ {gsub(/[[:space:]"]/,"",$2);print $2; exit}' pack.toml || true)
  need_reinit=0
  [[ "$current_loader_key" != "$desired_loader_key" ]] && need_reinit=1
  [[ -n "$desired_loader_version" && "$current_loader_version" != "$desired_loader_version" ]] && need_reinit=1
  [[ -n "$current_mc_version" && "$current_mc_version" != "$MC_VERSION" ]] && need_reinit=1
  if [[ $need_reinit -eq 1 ]]; then
    echo "==> Reinitializing pack to update loader/MC versions"
    REINIT="1"; init_pack && echo "    ✓ reinit"; REINIT=""
    echo "==> Accept MC family"
    case "$MC_VERSION" in
      1.21.*|1.21) base="1.21" ;;
      1.20.*|1.20) base="1.20" ;;
      *) base="${MC_VERSION%%.*}.${MC_VERSION#*.}" ;;
    esac
    $PW settings acceptable-versions --add "$base" || true
    $PW settings acceptable-versions --add "$MC_VERSION" || true
  else
    echo "    ✓ Loader/MC versions OK ($current_loader_key $current_loader_version, MC $current_mc_version)"
  fi
fi

# Copy locally-stashed assets (shaders, resource packs, config defaults) from
# the repo root into the pack dir so packwiz tracks them as overrides in the
# mrpack. Source dirs live at repo root so they survive `rm -rf $PACK_DIR`
# between runs. `config/` supports subdirectories (e.g. config/civmodern/...).
for asset_dir in shaderpacks resourcepacks config; do
  src="$OUT_DIR/$asset_dir"
  [[ -d "$src" ]] || continue
  shopt -s nullglob
  files=("$src"/*)
  shopt -u nullglob
  [[ ${#files[@]} -eq 0 ]] && continue
  echo "==> Staging $asset_dir/ ($(printf '%s\n' "${files[@]##*/}" | tr '\n' ' '))"
  mkdir -p "$PACK_DIR/$asset_dir"
  cp -ru "${files[@]}" "$PACK_DIR/$asset_dir/"
done

# Index helpers
declare -A IDX_MR IDX_CF IDX_SLUG

is_network_error() {
  local s=${1:-}
  [[ "$s" == *network* || "$s" == *connection* || "$s" == *TLS* || "$s" == *timeout* || "$s" == *SSL* ]]
}

build_index() {
  IDX_MR=(); IDX_CF=(); IDX_SLUG=()
  local f slug mr proj
  for f in "$PACK_DIR"/mods/*.pw.toml; do
    [[ -e "$f" ]] || continue
    slug="${f##*/}"; slug="${slug%.pw.toml}"
    read mr proj < <(awk '
      BEGIN{mr="";proj=""}
      /\[update.modrinth\]/{in_mr=1;next}
      /\[update.curseforge\]/{in_cf=1;next}
      /\[/{in_mr=0;in_cf=0}
      in_mr && /mod-id =/ {gsub(/.*= "|"/,"",$0);mr=$0}
      in_cf && /project-id =/ {gsub(/.*= /,"",$0);proj=$0}
      END{print mr, proj}
    ' "$f")
    [[ -n "$mr" ]] && IDX_MR["$mr"]="$f"
    [[ -n "$proj" ]] && IDX_CF["$proj"]="$f"
    IDX_SLUG["$slug"]="$f"
  done
}

find_mod_file_by_mr() { local mr_id="$1"; echo "${IDX_MR[$mr_id]:-}"; }
find_mod_file_by_cf() { local cf_proj="$1"; echo "${IDX_CF[$cf_proj]:-}"; }
find_mod_file_by_slug() { local slug="$1"; echo "${IDX_SLUG[$slug]:-}"; }

add_mod_with_retry() {
  local name="$1"; local slug="$2"; local mr="$3"; local cf="$4"; local mr_version="$5"
  local max_attempts=2
  echo "Adding: $name ($slug)"
  local attempt output exit_code
  if [[ -n "$mr" ]]; then
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
      [[ $attempt -gt 1 ]] && echo "    Retry MR $attempt/$max_attempts..." && sleep $((attempt-1))
      if [[ -n "$mr_version" ]]; then
        output=$($PW modrinth add --project-id "$mr" --version-id "$mr_version" 2>&1); exit_code=$?
      else
        output=$($PW modrinth add "$mr" 2>&1); exit_code=$?
      fi
      if [[ $exit_code -eq 0 ]]; then
        [[ -n "$mr_version" ]] && echo "    ✓ MR (pinned $mr_version)" || echo "    ✓ MR"
        return 0
      fi
      is_network_error "$output" || break
    done
  fi
  if [[ -n "$cf" ]]; then
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
      [[ $attempt -gt 1 ]] && echo "    Retry CF $attempt/$max_attempts..." && sleep $((attempt-1))
      output=$($PW curseforge add "$cf" 2>&1); exit_code=$?
      if [[ $exit_code -eq 0 ]]; then echo "    ✓ CF (id)"; return 0; fi
      is_network_error "$output" || true
      output=$($PW curseforge add "$slug" 2>&1); exit_code=$?
      if [[ $exit_code -eq 0 ]]; then echo "    ✓ CF (slug)"; return 0; fi
      is_network_error "$output" || break
    done
  fi
  return 0
}

process_mod() {
  local name="$1" slug="$2" mr="$3" cf="$4" mr_version="${5:-}"
  local modfile=""
  [[ -n "$mr" ]] && modfile=$(find_mod_file_by_mr "$mr") || true
  [[ -z "$modfile" && -n "$cf" ]] && modfile=$(find_mod_file_by_cf "$cf") || true
  [[ -z "$modfile" && -n "$slug" ]] && modfile=$(find_mod_file_by_slug "$slug") || true

  # If mr_version is set, check if the existing pin already matches. If not,
  # force-re-add so the version pin takes effect. This handles the case where
  # packwiz auto-resolved this mod as a dependency of an earlier add (at the
  # latest version) before we got to its explicit entry.
  if [[ -n "$modfile" && -n "$mr_version" ]]; then
    local existing_version
    existing_version=$(awk -F'"' '/\[update.modrinth\]/{in_mr=1;next} /\[/{in_mr=0} in_mr && /version =/ {print $2; exit}' "$modfile")
    if [[ "$existing_version" != "$mr_version" ]]; then
      echo "    ~ Re-pinning $name to $mr_version (was $existing_version)"
      rm -f "$modfile"; build_index; modfile=""
    fi
  fi

  if [[ -n "$modfile" ]]; then
    if [[ ${#UPGRADE_ONLY_SET[@]} -gt 0 ]]; then
      if [[ -n "${UPGRADE_ONLY_SET[$slug]:-}" ]]; then
        echo "    ~ Upgrading (selected): $name"; rm -f "$modfile"; build_index
      else
        echo "    ✓ Present (pinned): $name"; return 0
      fi
    elif [[ $UPGRADE -eq 1 ]]; then
      echo "    ~ Upgrading: $name"; rm -f "$modfile"; build_index
    else
      echo "    ✓ Present (pinned): $name"; return 0
    fi
  fi
  add_mod_with_retry "$name" "$slug" "$mr" "$cf" "$mr_version"
  build_index
}

export_mods_yaml() {
  echo "mods:" > "$MODS_YAML"
  for f in "$PACK_DIR"/mods/*.pw.toml; do
    [[ -e "$f" ]] || continue
    local name slug mr cf proj
    name=$(grep -m1 '^name = ' "$f" | sed -E 's/^name = "?([^"]+)"?/\1/')
    slug="${f##*/}"; slug="${slug%.pw.toml}"
    read mr proj < <(awk '
      BEGIN{mr="";proj=""}
      /\[update.modrinth\]/{in_mr=1;next}
      /\[update.curseforge\]/{in_cf=1;next}
      /\[/{in_mr=0;in_cf=0}
      in_mr && /mod-id =/ {gsub(/.*= "|"/,"",$0);mr=$0}
      in_cf && /project-id =/ {gsub(/.*= /,"",$0);proj=$0}
      END{print mr, proj}
    ' "$f")
    cf="$proj"
    printf "  - name: \"%s\"\n    slug: %s\n    mr: %s\n    cf: %s\n" "$name" "$slug" "${mr:-}" "${cf:-}" >> "$MODS_YAML"
  done
  echo "==> Wrote $MODS_YAML"
}

if [[ $EXPORT -eq 1 ]]; then
  echo "==> Exporting installed mods to mods.yaml"
  export_mods_yaml
  exit 0
fi

if [[ ! -f "$MODS_YAML" ]]; then
  echo "ERROR: mods.yaml not found at $MODS_YAML"
  echo "Hint: run './setup.sh --export-mods' to bootstrap from current pack."
  exit 1
fi

echo "==> Ensuring mods from mods.yaml (upgrade=$UPGRADE)"
build_index

# Track desired identifiers to enable robust pruning of removed mods
# We track: slugs, Modrinth project IDs, and CurseForge project IDs
declare -A DESIRED_SLUGS=()
declare -A DESIRED_MR=()
declare -A DESIRED_CF=()

if command -v yq >/dev/null 2>&1; then
  while IFS=$'\t' read -r name slug mr cf mr_version; do
    [[ -z "$name" || -z "$slug" ]] && continue
    DESIRED_SLUGS["$slug"]=1
    [[ -n "$mr" ]] && DESIRED_MR["$mr"]=1
    [[ -n "$cf" ]] && DESIRED_CF["$cf"]=1
    process_mod "$name" "$slug" "${mr:-}" "${cf:-}" "${mr_version:-}"
  done < <(yq -r '.mods[] | [.name, .slug, (.mr // ""), (.cf // ""), (.mr_version // "")] | @tsv' "$MODS_YAML")
else
  current_key=""; name=""; slug=""; mr=""; cf=""; mr_version=""; have_record=0
  parse_kv_line() {
    local raw="$1"
    # Strip inline trailing comment (but not # inside a quoted string — we don't have those)
    raw="${raw%%#*}"
    raw="${raw%"${raw##*[![:space:]]}"}"  # rtrim
    local k="${raw%%:*}"
    local v="${raw#*:}"; v=${v#"${v%%[![:space:]]*}"}; v="${v#\"}"; v="${v%\"}"
    case "$k" in
      name)       name="$v" ;;
      slug)       slug="$v" ;;
      mr)         mr="$v" ;;
      cf)         cf="$v" ;;
      mr_version) mr_version="$v" ;;
    esac
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed=${line#"${line%%[![:space:]]*}"}
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" =~ ^# ]] && continue
    if [[ "$trimmed" == -* ]]; then
      if [[ $have_record -eq 1 ]]; then
        [[ -n "$slug" ]] && DESIRED_SLUGS["$slug"]=1
        [[ -n "$mr" ]] && DESIRED_MR["$mr"]=1
        [[ -n "$cf" ]] && DESIRED_CF["$cf"]=1
        process_mod "$name" "$slug" "$mr" "$cf" "$mr_version"
      fi
      name=""; slug=""; mr=""; cf=""; mr_version=""; have_record=1
      # The "- " line typically also holds the first key (e.g. "- name: X").
      # Strip the leading "-" and any whitespace, then parse the remainder.
      rest="${trimmed#-}"; rest="${rest#"${rest%%[![:space:]]*}"}"
      [[ -n "$rest" ]] && parse_kv_line "$rest"
      continue
    fi
    parse_kv_line "$trimmed"
  done < "$MODS_YAML"
  if [[ $have_record -eq 1 ]]; then
    [[ -n "$slug" ]] && DESIRED_SLUGS["$slug"]=1
    [[ -n "$mr" ]] && DESIRED_MR["$mr"]=1
    [[ -n "$cf" ]] && DESIRED_CF["$cf"]=1
    process_mod "$name" "$slug" "$mr" "$cf" "$mr_version"
  fi
fi

# Prune any mods not listed in mods.yaml
echo "==> Pruning removed mods"
pruned_any=0
for f in "$PACK_DIR"/mods/*.pw.toml; do
  [[ -e "$f" ]] || continue
  base="${f##*/}"; slug="${base%.pw.toml}"
  # Read Modrinth/CurseForge identifiers from the mod file
  read mr proj < <(awk '
    BEGIN{mr="";proj=""}
    /\[update.modrinth\]/{in_mr=1;next}
    /\[update.curseforge\]/{in_cf=1;next}
    /\[/{in_mr=0;in_cf=0}
    in_mr && /mod-id =/ {gsub(/.*= "|"/,"",$0);mr=$0}
    in_cf && /project-id =/ {gsub(/.*= /,"",$0);proj=$0}
    END{print mr, proj}
  ' "$f")
  keep=0
  [[ -n "$mr" && -n "${DESIRED_MR[$mr]:-}" ]] && keep=1
  [[ -n "$proj" && -n "${DESIRED_CF[$proj]:-}" ]] && keep=1
  [[ -n "${DESIRED_SLUGS[$slug]:-}" ]] && keep=1
  if [[ $keep -eq 0 ]]; then
    echo "    - Removing: $slug ($base)"
    rm -f "$f"
    pruned_any=1
  fi
done
[[ $pruned_any -eq 1 ]] && build_index || true

echo "==> Refresh index"
$PW refresh

echo "==> Export Modrinth pack (.mrpack)"
set +e
$PW modrinth export --output "$MRPACK" --restrictDomains=false
export_exit=$?
set -e

if [[ $export_exit -ne 0 ]]; then
  echo "ERROR: packwiz export failed (exit $export_exit). See output above for details."
  if [[ -f "$MRPACK" ]]; then
    sz=$(stat -c%s "$MRPACK" 2>/dev/null || echo 0)
    echo "Note: current '$MRPACK' size=${sz} bytes"
  fi
  echo "Common causes:"
  echo " - API/network errors (rate limiting or DNS)."
  echo " - Mods requiring manual download due to licensing."
  exit $export_exit
fi

if [[ ! -s "$MRPACK" ]]; then
  echo "ERROR: '$MRPACK' is empty (0 bytes). Export did not complete successfully."
  exit 1
fi

echo
echo "==> Done."
echo "Import '$MRPACK' in PolyMC/Prism: Add Instance -> Import from zip (.mrpack)."
