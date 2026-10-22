#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lyszt (Joao Luis Almeida Santos)
#
# Installer for RISC-V tools featured on lyszt.net.
# Modeled after common curl-type installers (starship, zellij, rustup):
# detect OS and architecture, resolve the latest release from the GitHub API,
# verify the sha256 digest published by GitHub, install without sudo.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lyszt/lyszt-install-scripts_misc/main/install.sh | sh -s -- <tool> [options]
#   sh install.sh <tool> [options]
#
# Tools: ripes, rars
# Options:
#   --version <tag>     install a specific release tag (e.g. v2.3.0, pinned for courses)
#   --install-dir <dir> target directory (default: ~/.local/bin)
#   -h | --help         show this help

set -eu

PROGRAM="lyszt-install"
GITHUB_API="https://api.github.com"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

info() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found in PATH."
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

usage() {
  cat <<'EOF'
Usage: install.sh <tool> [options]

Tools:
  ripes    Ripes, the graphical RISC-V computer architecture simulator
  rars     RARS, the RISC-V Assembler and Runtime Simulator (requires Java)

Options:
  --version <tag>     install a specific release tag (e.g. v2.3.0)
  --install-dir <dir> target directory (default: ~/.local/bin)
  -h, --help          show this help

Examples:
  sh install.sh ripes
  sh install.sh rars --version v1.6
  sh install.sh ripes --install-dir ~/bin

Piping from curl:
  curl -fsSL <script-url> | sh -s -- ripes
EOF
}

# fetch <url> [destination]
fetch() {
  if have_cmd curl; then
    curl -fsSL "$1" ${2:+-o "$2"}
  elif have_cmd wget; then
    wget -qO "${2:--}" "$1"
  else
    die "neither curl nor wget is available."
  fi
}

# api_get <path>  -> prints the JSON response
api_get() {
  if have_cmd curl; then
    curl -fsSL -H "Accept: application/vnd.github+json" "${GITHUB_API}$1"
  else
    wget -qO- --header="Accept: application/vnd.github+json" "${GITHUB_API}$1"
  fi
}

sha256_of() {
  if have_cmd sha256sum; then
    sha256sum "$1" | cut -d' ' -f1
  elif have_cmd shasum; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    die "no sha256 tool found (need sha256sum or shasum)."
  fi
}

# Prints the distribution ID and ID_LIKE tokens from /etc/os-release
# (e.g. "ubuntu debian" on Ubuntu, "arch" on Arch). Empty on macOS.
distro_tokens() {
  for field in ID ID_LIKE; do
    grep -s "^${field}=" /etc/os-release | cut -d= -f2- | tr -d '"' | tr ' ' '\n'
  done
}

# Exact package name for AppImage FUSE support per distribution.
fuse_hint() {
  for token in $(distro_tokens); do
    case "$token" in
      ubuntu) printf 'sudo apt install libfuse2 (Ubuntu 24.04+: libfuse2t64)'; return 0 ;;
      debian) printf 'sudo apt install libfuse2'; return 0 ;;
      fedora) printf 'sudo dnf install fuse-libs'; return 0 ;;
      arch|archarm) printf 'sudo pacman -S fuse2'; return 0 ;;
      opensuse|suse) printf 'sudo zypper install fuse'; return 0 ;;
    esac
  done
  printf 'install the fuse2 package for your distribution'
}

# Java 17 install command per distribution (Linux only).
java_hint() {
  for token in $(distro_tokens); do
    case "$token" in
      ubuntu|debian) printf 'sudo apt install openjdk-17-jre'; return 0 ;;
      fedora) printf 'sudo dnf install java-17-openjdk'; return 0 ;;
      arch|archarm) printf 'sudo pacman -S jre-openjdk'; return 0 ;;
      opensuse|suse) printf 'sudo zypper install java-17-openjdk'; return 0 ;;
      rhel|centos|rocky|alma) printf 'sudo dnf install java-17-openjdk'; return 0 ;;
    esac
  done
  printf 'install a Java 17+ JRE for your distribution'
}

# Registers a graphical launcher so the tool shows up in the applications menu.
# write_desktop_entry <id> <name> <exec-path> <comment>
write_desktop_entry() {
  entry_id="$1"; entry_name="$2"; entry_exec="$3"; entry_comment="$4"
  apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$apps_dir"
  printf '%s\n' \
    "[Desktop Entry]" \
    "Type=Application" \
    "Name=${entry_name}" \
    "Exec=\"${entry_exec}\"" \
    "Terminal=false" \
    "Categories=Education;Science;" \
    "Comment=${entry_comment}" > "${apps_dir}/${entry_id}.desktop"
  if have_cmd update-desktop-database; then
    update-desktop-database "${apps_dir}" >/dev/null 2>&1 || true
  fi
}

# ---------------------------------------------------------------------------
# release resolution
# ---------------------------------------------------------------------------

# repo_for <tool>
repo_for() {
  case "$1" in
    ripes) echo "mortbopet/Ripes" ;;
    rars) echo "TheThirdOne/rars" ;;
    *) die "unknown tool '$1'. Valid tools: ripes, rars" ;;
  esac
}

# extract_release_tag <json>
extract_release_tag() {
  printf '%s' "$1" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

# Each asset object in a GitHub release JSON is pretty-printed with one field
# per line in alphabetical order, so browser_download_url, digest and name are
# emitted in that order per asset. Print one "name|digest|url" line per asset.
extract_assets() {
  printf '%s' "$1" | awk '
    /"browser_download_url":/ {
      url = $0
      sub(/.*"browser_download_url": *"/, "", url)
      sub(/",.*/, "", url)
    }
    /"digest":/ {
      digest = $0
      sub(/.*"digest": *"/, "", digest)
      sub(/",.*/, "", digest)
    }
    /"name":/ {
      name = $0
      sub(/.*"name": *"/, "", name)
      sub(/",.*/, "", name)
      if (url != "") { print name "|" digest "|" url; url = "" }
    }
  '
}

# find_asset <tool> <os> <arch> <asset-lines...>
find_asset() {
  tool="$1"; os="$2"; arch="$3"; shift 3
  for asset in "$@"; do
    name="${asset%%|*}"; rest="${asset#*|}"
    digest="${rest%%|*}"; url="${rest#*|}"
    case "$tool" in
      ripes)
        case "$os" in
          linux)  echo "$name" | grep -q 'linux-x86_64.*\.AppImage$' || continue ;;
          darwin) echo "$name" | grep -q 'mac.*\.zip$' || continue ;;
        esac
        ;;
      rars)
        echo "$name" | grep -qi '\.jar$' || continue
        ;;
    esac
    printf '%s\n' "$name"
    printf '%s\n' "$digest"
    printf '%s\n' "$url"
    return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# per-tool install steps
# ---------------------------------------------------------------------------

# install_ripes <file> <os> <install-dir> <tag>
install_ripes() {
  file="$1"; os="$2"; dir="$3"; tag="$4"
  case "$os" in
    linux)
      mkdir -p "$dir"
      mv "$file" "$dir/ripes"
      chmod +x "$dir/ripes"
      write_desktop_entry ripes "Ripes" "${dir}/ripes" "RISC-V processor simulator"
      info "installed ripes ${tag} -> ${dir}/ripes"
      info "run it with: ${dir}/ripes"
      if ! have_cmd fusermount && ! have_cmd fusermount3 && ! [ -e /dev/fuse ]; then
        warn "AppImages need FUSE. If ripes fails to start, run: $(fuse_hint)"
      fi
      ;;
    darwin)
      need_cmd unzip
      app_dir="${LYSZT_APP_DIR:-$HOME/Applications}"
      mkdir -p "$app_dir"
      rm -rf "${TMPDIR:-/tmp}/ripes-extract"
      mkdir -p "${TMPDIR:-/tmp}/ripes-extract"
      unzip -q "$file" -d "${TMPDIR:-/tmp}/ripes-extract"
      app_src=$(find "${TMPDIR:-/tmp}/ripes-extract" -maxdepth 2 -name '*.app' -print -quit)
      [ -n "$app_src" ] || die "could not find Ripes.app inside the downloaded archive."
      rm -rf "$app_dir/Ripes.app"
      mv "$app_src" "$app_dir/"
      rm -rf "${TMPDIR:-/tmp}/ripes-extract"
      info "installed ripes ${tag} -> ${app_dir}/Ripes.app"
      info "first run: xattr -dr com.apple.quarantine '${app_dir}/Ripes.app' (if macOS blocks it)"
      ;;
  esac
}

# install_rars <file> <os> <install-dir> <tag>
install_rars() {
  file="$1"; dir="$2"; tag="$3"
  mkdir -p "$dir"
  mv "$file" "$dir/rars.jar"
  cat > "$dir/rars" <<LAUNCHER
#!/bin/sh
exec java -jar "\$(dirname "\$0")/rars.jar" "\$@"
LAUNCHER
  chmod +x "$dir/rars"
  write_desktop_entry rars "RARS" "${dir}/rars" "RISC-V Assembler and Runtime Simulator"
  info "installed rars ${tag} -> ${dir}/rars (jar: ${dir}/rars.jar)"
  if ! have_cmd java; then
    warn "java was not found in PATH. RARS requires Java 8 or newer."
    if [ "$(uname -s)" = "Darwin" ]; then
      warn "  brew install openjdk@17            (macOS)"
    else
      warn "  $(java_hint)"
    fi
  fi
  if [ "$(uname -s)" != "Darwin" ]; then
    if have_cmd flatpak; then
      info "RARS is also on Flathub: flatpak install flathub io.github.TheThirdOne.rars"
    else
      info "RARS is also on Flathub: https://flathub.org/apps/io.github.TheThirdOne.rars"
    fi
  fi
  info "run it with: ${dir}/rars"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

main() {
  tool=""
  version=""
  install_dir="${LYSZT_INSTALL_DIR:-$HOME/.local/bin}"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --version) [ $# -ge 2 ] || die "--version requires a value."; version="$2"; shift 2 ;;
      --install-dir) [ $# -ge 2 ] || die "--install-dir requires a value."; install_dir="$2"; shift 2 ;;
      --) shift; break ;;
      -*) die "unknown option '$1'. Try --help." ;;
      *)
        [ -z "$tool" ] || die "unexpected extra argument '$1'."
        tool="$1"; shift
        ;;
    esac
  done
  [ $# -eq 0 ] || die "unexpected extra argument(s): $*"
  [ -n "$tool" ] || { usage >&2; die "no tool given. Usage: install.sh <tool>"; }

  case "$version" in
    v*) ;;
    "") ;;
    *) version="v$version" ;;
  esac

  need_cmd grep
  need_cmd sed
  need_cmd awk

  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$os" in
    linux*) os=linux ;;
    darwin*) os=darwin ;;
    *) die "unsupported operating system '$(uname -s)'. This installer supports Linux and macOS." ;;
  esac

  repo=$(repo_for "$tool")

  if [ -n "$version" ]; then
    info "resolving ${repo} release ${version}"
    release_json=$(api_get "/repos/${repo}/releases/tags/${version}") || die "release ${version} not found for ${repo}."
  else
    info "resolving latest release of ${repo}"
    release_json=$(api_get "/repos/${repo}/releases/latest") || die "could not reach the GitHub API for ${repo}."
  fi

  tag=$(extract_release_tag "$release_json")
  [ -n "$tag" ] || die "could not read the release tag from the GitHub response."

  asset_lines=$(extract_assets "$release_json")
  [ -n "$asset_lines" ] || die "no downloadable assets found for ${repo} ${tag}."

  asset_records=$(find_asset "$tool" "$os" "$(uname -m)" "$asset_lines")
  [ -n "$asset_records" ] || die "no ${os} asset found for ${tool} ${tag}. Download it from https://github.com/${repo}/releases"

  asset_name=$(printf '%s\n' "$asset_records" | sed -n 1p)
  asset_digest=$(printf '%s\n' "$asset_records" | sed -n 2p | sed 's/^sha256://')
  asset_url=$(printf '%s\n' "$asset_records" | sed -n 3p)

  info "downloading ${asset_name} ($(uname -m), ${os})"
  tmp_file=$(mktemp "${TMPDIR:-/tmp}/${tool}.XXXXXX")
  fetch "$asset_url" "$tmp_file"

  if [ -n "$asset_digest" ]; then
    info "verifying sha256 checksum"
    actual=$(sha256_of "$tmp_file")
    [ "$actual" = "$asset_digest" ] || die "checksum mismatch for ${asset_name}. Expected ${asset_digest}, got ${actual}."
  else
    warn "GitHub did not publish a digest for ${asset_name}; skipping checksum verification."
  fi

  case "$tool" in
    ripes) install_ripes "$tmp_file" "$os" "$install_dir" "$tag" ;;
    rars) install_rars "$tmp_file" "$os" "$install_dir" "$tag" ;;
  esac

  case ":$PATH:" in
    *":$install_dir:"*) ;;
    *) warn "${install_dir} is not in your PATH. Add it with: export PATH=\"\$PATH:${install_dir}\"" ;;
  esac

  info "done. Installed version: ${tag}"
}

main "$@"
