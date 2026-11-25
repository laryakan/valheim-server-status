#!/bin/bash

vss_bepinex_copy_legacy_data() {
  local legacy_root="$1/BepInEx"
  local profile_root="$2/BepInEx"
  local source_path
  local relative_path
  local destination

  [[ -d "$legacy_root" ]] || return 0

  while IFS= read -r -d '' source_path; do
    relative_path="${source_path#"$legacy_root"/}"
    case "$relative_path" in
      plugins|plugins/*|config|config/*) ;;
      *) continue ;;
    esac
    case "$relative_path" in
      config/BepInEx.cfg) continue ;;
    esac

    destination="$profile_root/$relative_path"
    if [[ -d "$source_path" && ! -L "$source_path" ]]; then
      if [[ -e "$destination" || -L "$destination" ]]; then
        [[ -d "$destination" && ! -L "$destination" ]] || {
          printf 'Cannot migrate BepInEx directory over existing profile path: %s\n' "$destination" >&2
          return 1
        }
      else
        mkdir -p -- "$destination" || return 1
      fi
    elif [[ ! -e "$destination" && ! -L "$destination" ]]; then
      mkdir -p -- "$(dirname -- "$destination")" || return 1
      cp -a -- "$source_path" "$destination" || return 1
    fi
  done < <(find "$legacy_root" -mindepth 1 -print0)
}

vss_bepinex_link_files() {
  local source_dir="$1"
  local profile_dir="$2"
  local current_dir="$3"
  local source_file
  local relative_path
  local destination
  local source_subdir
  local relative_subdir
  local profile_subdir
  local profile_link
  local link_target
  local relative_link
  local file_count=0

  [[ -d "$source_dir" ]] || {
    printf 'BepInEx shared directory not found: %s\n' "$source_dir" >&2
    return 1
  }

  while IFS= read -r -d '' source_subdir; do
    relative_subdir="${source_subdir#"$source_dir"/}"
    profile_subdir="$profile_dir/$relative_subdir"
    if [[ -L "$profile_subdir" || ( -e "$profile_subdir" && ! -d "$profile_subdir" ) ]]; then
      printf 'BepInEx shared-file parent must be a real directory: %s\n' "$profile_subdir" >&2
      return 1
    fi
    mkdir -p -- "$profile_subdir" || return 1
  done < <(find "$source_dir" -mindepth 1 -type d -print0)

  while IFS= read -r -d '' source_file; do
    relative_path="${source_file#"$source_dir"/}"
    destination="$profile_dir/$relative_path"
    link_target="$current_dir/$relative_path"
    mkdir -p -- "$(dirname -- "$destination")" || return 1

    if [[ -e "$destination" || -L "$destination" ]]; then
      if [[ -L "$destination" && "$(readlink -- "$destination")" == "$link_target" ]]; then
        file_count=$((file_count + 1))
        continue
      fi
      printf 'Refusing to replace non-VSS BepInEx file: %s\n' "$destination" >&2
      return 1
    fi
    ln -s -- "$link_target" "$destination" || return 1
    file_count=$((file_count + 1))
  done < <(find "$source_dir" -type f -print0)

  [[ "$file_count" -gt 0 ]] || {
    printf 'No shared BepInEx files found in %s\n' "$source_dir" >&2
    return 1
  }

  while IFS= read -r -d '' profile_link; do
    relative_link="${profile_link#"$profile_dir"/}"
    link_target="$(readlink -- "$profile_link")" || return 1
    case "$link_target" in
      "$current_dir"/*)
        if [[ ! -f "$source_dir/$relative_link" ]]; then
          rm -- "$profile_link" || return 1
        fi
        ;;
    esac
  done < <(find "$profile_dir" -type l -print0)
}

vss_bepinex_link_doorstop_file() {
  local source_file="$1"
  local destination="$2"
  local link_target="$3"
  local existing_target

  [[ -f "$source_file" ]] || {
    printf 'Doorstop library not found: %s\n' "$source_file" >&2
    return 1
  }

  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ -L "$destination" ]]; then
      existing_target="$(readlink -- "$destination")" || return 1
      [[ "$existing_target" == "$link_target" ]] && return 0
      case "$existing_target" in
        "$VSSDIR"/bepinex/*/libdoorstop.so|"$VSSDIR"/bepinex/*/doorstop_libs/libdoorstop.so)
          rm -- "$destination" || return 1
          ;;
        *)
          printf 'Refusing to replace non-VSS Doorstop library: %s\n' "$destination" >&2
          return 1
          ;;
      esac
    else
      printf 'Refusing to replace non-symbolic Doorstop library: %s\n' "$destination" >&2
      return 1
    fi
  fi

  ln -s -- "$link_target" "$destination" || return 1
}

vss_bepinex_remove_legacy_doorstop_link() {
  local profile_root="$1"
  local legacy_dir="$profile_root/doorstop_libs"
  local legacy_file="$legacy_dir/libdoorstop.so"
  local link_target

  [[ -d "$legacy_dir" && ! -L "$legacy_dir" ]] || return 0

  if [[ -L "$legacy_file" ]]; then
    link_target="$(readlink -- "$legacy_file")" || return 1
    case "$link_target" in
      "$VSSDIR"/bepinex/*/doorstop_libs/libdoorstop.so)
        rm -- "$legacy_file" || return 1
        ;;
    esac
  fi

  if [[ -z "$(find "$legacy_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    rmdir -- "$legacy_dir" || return 1
  fi
}

vss_bepinex_link_profile_config() (
  local config="$1"
  local target="$2"
  local policy="${3:-strict}"
  local tmp_dir

  case "$policy" in
    strict|defer|replace) ;;
    *) printf 'Invalid BepInEx configuration link policy: %s\n' "$policy" >&2; return 1 ;;
  esac
  if [[ -L "$config" && "$(readlink -- "$config")" == "$target" ]]; then
    return 0
  fi
  if [[ -e "$config" || -L "$config" ]]; then
    if [[ ! -f "$config" && ! -L "$config" ]]; then
      printf 'Refusing to replace non-file BepInEx configuration: %s\n' "$config" >&2
      return 1
    fi
    case "$policy" in
      strict) printf 'Refusing to replace profile-specific BepInEx.cfg: %s\n' "$config" >&2; return 1 ;;
      defer) return 0 ;;
    esac
    if ! tmp_dir="$(mktemp -d "${config%/*}/.vss-bepinex-link.XXXXXX")"; then
      printf 'Could not prepare BepInEx configuration link: %s\n' "$config" >&2
      return 1
    fi
    trap 'rm -f -- "$tmp_dir/BepInEx.cfg"; rmdir -- "$tmp_dir"' EXIT
    if ! ln -s -- "$target" "$tmp_dir/BepInEx.cfg" ||
       ! mv -fT -- "$tmp_dir/BepInEx.cfg" "$config"; then
      printf 'Could not replace BepInEx configuration with a link: %s\n' "$config" >&2
      return 1
    fi
    printf 'Replaced profile-specific BepInEx configuration with the shared link: %s\n' "$config" >&2
  else
    ln -s -- "$target" "$config" || return 1
  fi
)

vss_bepinex_prepare_profile() {
  local profile_root="$1"
  local image_root="$2"
  local legacy_image_root="${3:-}"
  local profile_bepinex="$profile_root/BepInEx"
  local expected_cfg="$VSSDIR/bepinex/current/BepInEx/config/BepInEx.cfg"
  local profile_cfg="$profile_bepinex/config/BepInEx.cfg"
  local profile_marker="$profile_root/.vss-bepinex-profile"
  local image_doorstop_library
  local current_doorstop_library
  local path

  if [[ -L "$profile_marker" || ( -e "$profile_marker" && ! -f "$profile_marker" ) ]]; then
    printf 'Invalid BepInEx profile marker: %s\n' "$profile_marker" >&2
    return 1
  fi

  [[ -f "$image_root/BepInEx/config/BepInEx.cfg" ]] || {
    printf 'BepInEx config not found in image: %s\n' "$image_root" >&2
    return 1
  }
  [[ -f "$image_root/BepInEx/core/BepInEx.Preloader.dll" ]] || {
    printf 'BepInEx preloader not found in image: %s\n' "$image_root" >&2
    return 1
  }
  if [[ -f "$image_root/libdoorstop.so" ]]; then
    image_doorstop_library="$image_root/libdoorstop.so"
    current_doorstop_library="$VSSDIR/bepinex/current/libdoorstop.so"
  elif [[ -f "$image_root/doorstop_libs/libdoorstop.so" ]]; then
    image_doorstop_library="$image_root/doorstop_libs/libdoorstop.so"
    current_doorstop_library="$VSSDIR/bepinex/current/doorstop_libs/libdoorstop.so"
  else
    printf 'Doorstop library not found in image: %s\n' "$image_root" >&2
    return 1
  fi

  for path in \
    "$profile_root" \
    "$profile_bepinex" \
    "$profile_bepinex/core" \
    "$profile_bepinex/config" \
    "$profile_bepinex/plugins" \
    "$profile_bepinex/patchers" \
    "$profile_bepinex/cache"; do
    if [[ -L "$path" ]]; then
      printf 'BepInEx profile directories must not be symbolic links: %s\n' "$path" >&2
      return 1
    fi
    if [[ -e "$path" && ! -d "$path" ]]; then
      printf 'BepInEx profile path is not a directory: %s\n' "$path" >&2
      return 1
    fi
  done

  mkdir -p -- \
    "$profile_bepinex/core" \
    "$profile_bepinex/config" \
    "$profile_bepinex/plugins" \
    "$profile_bepinex/patchers" \
    "$profile_bepinex/cache" || return 1

  if [[ ! -f "$profile_marker" ]]; then
    if [[ -n "$legacy_image_root" && -d "$legacy_image_root" ]]; then
      vss_bepinex_copy_legacy_data "$legacy_image_root" "$profile_root" || return 1
    fi
  fi

  vss_bepinex_link_files \
    "$image_root/BepInEx/core" \
    "$profile_bepinex/core" \
    "$VSSDIR/bepinex/current/BepInEx/core" || return 1
  vss_bepinex_link_doorstop_file \
    "$image_doorstop_library" \
    "$profile_root/libdoorstop.so" \
    "$current_doorstop_library" || return 1
  vss_bepinex_remove_legacy_doorstop_link "$profile_root" || return 1

  vss_bepinex_link_profile_config "$profile_cfg" "$expected_cfg" "${4:-strict}" || return 1

  [[ -f "$profile_marker" ]] || : > "$profile_marker" || return 1
}

vss_bepinex_remove_doorstop_preload() {
  local preload_entry
  local remaining_preloads=''
  local -a preload_entries=()

  IFS=': ' read -r -a preload_entries <<< "${LD_PRELOAD:-}"
  for preload_entry in "${preload_entries[@]}"; do
    [[ -n "$preload_entry" ]] || continue
    if [[ "${preload_entry##*/}" == "libdoorstop.so" ]]; then
      continue
    fi
    remaining_preloads="${remaining_preloads:+$remaining_preloads:}$preload_entry"
  done

  if [[ -n "$remaining_preloads" ]]; then
    export LD_PRELOAD="$remaining_preloads"
  else
    unset LD_PRELOAD
  fi
}

vss_bepinex_remove_library_paths() {
  local library_path_entry
  local profile_path_suffix
  local remaining_library_paths=''
  local profile_doorstop_dir="${VSSBEPINEXDIR%/}"
  local -a library_path_entries=()

  IFS=':' read -r -a library_path_entries <<< "${LD_LIBRARY_PATH:-}"
  for library_path_entry in "${library_path_entries[@]}"; do
    [[ -n "$library_path_entry" ]] || continue
    if [[ "$library_path_entry" == "$profile_doorstop_dir" ||
          "$library_path_entry" == "$profile_doorstop_dir/" ||
          "$library_path_entry" == "$VSSDIR"/bepinex/current ||
          "$library_path_entry" == "$VSSDIR"/bepinex/current/ ||
          "$library_path_entry" == "$VSSDIR"/bepinex/*/doorstop_libs ]]; then
      continue
    fi
    if [[ "$library_path_entry" == "$VSSDIR"/bepinex/profiles/* ]]; then
      profile_path_suffix="${library_path_entry#"$VSSDIR"/bepinex/profiles/}"
      profile_path_suffix="${profile_path_suffix%/}"
      [[ "$profile_path_suffix" != */* ]] && continue
    fi
    remaining_library_paths="${remaining_library_paths:+$remaining_library_paths:}$library_path_entry"
  done

  if [[ -n "$remaining_library_paths" ]]; then
    export LD_LIBRARY_PATH="$remaining_library_paths"
  else
    unset LD_LIBRARY_PATH
  fi
}

vss_bepinex_configure_runtime() {
  local preloader="$VSSBEPINEXDIR/BepInEx/core/BepInEx.Preloader.dll"
  local doorstop_dir="${VSSBEPINEXDIR%/}"
  local doorstop_library="$doorstop_dir/libdoorstop.so"

  vss_bepinex_remove_library_paths
  if [[ "${VSSBEPINEXENABLED:-0}" == "1" ]]; then
    [[ -f "$preloader" ]] || {
      printf 'BepInEx is enabled for %s but its profile preloader is missing. Run setup to install it: %s\n' \
        "${VSS_SERVER_NAME:-unknown}" "$preloader" >&2
      return 1
    }
    [[ -f "$doorstop_library" ]] || {
      printf 'BepInEx is enabled for %s but its profile Doorstop library is missing. Run setup to install it: %s\n' \
        "${VSS_SERVER_NAME:-unknown}" "$doorstop_library" >&2
      return 1
    }

    vss_bepinex_remove_doorstop_preload
    unset DOORSTOP_INVOKE_DLL_PATH DOORSTOP_MANAGED_FOLDER_DIR
    export DOORSTOP_ENABLED=1
    export DOORSTOP_TARGET_ASSEMBLY="$preloader"
    export LD_LIBRARY_PATH="$doorstop_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LD_PRELOAD="$doorstop_library${LD_PRELOAD:+:$LD_PRELOAD}"
  else
    unset DOORSTOP_ENABLED DOORSTOP_TARGET_ASSEMBLY DOORSTOP_INVOKE_DLL_PATH DOORSTOP_MANAGED_FOLDER_DIR
    vss_bepinex_remove_doorstop_preload
  fi
}

vss_bepinex_remove_legacy_server_links() {
  local server_dir="$1"
  local path
  local link_target

  [[ -d "$server_dir" ]] || return 0
  for path in "$server_dir"/*; do
    [[ -L "$path" ]] || continue
    link_target="$(readlink -- "$path")" || return 1
    case "$link_target" in
      "$VSSDIR"/bepinex/*)
        rm -- "$path" || return 1
        ;;
    esac
  done
}
