#!/bin/bash
set -e

URL="https://music.163.com/st/webplayer"
APP_NAME="netease-music-web"
APP_DISPLAY_NAME="网易云音乐 (网页版)"
APP_DISPLAY_NAME_EN="NetEase CloudMusic (Web)"
COMMENT="网易云音乐网页版 - music.163.com"

BROWSERS=(
  google-chrome-stable
  google-chrome
  chromium
  chromium-browser
  brave-browser
  microsoft-edge-stable
  vivaldi
)

detect_browser() {
  for b in "${BROWSERS[@]}"; do
    local path
    path=$(command -v "$b" 2>/dev/null || which "$b" 2>/dev/null || true)
    if [ -n "$path" ] && [ -x "$path" ]; then
      echo "$path"
      return 0
    fi
  done

  for b in "${BROWSERS[@]}"; do
    local common=(
      "/usr/bin/$b"
      "/usr/local/bin/$b"
      "/opt/$b/$b"
      "/snap/bin/$b"
    )
    for p in "${common[@]}"; do
      if [ -x "$p" ]; then
        echo "$p"
        return 0
      fi
    done
  done

  return 1
}

find_data_home() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}"
}

download_icon() {
  local icon_dir="$1"
  local ico_file="/tmp/netease_favicon.ico"
  local png_file="$icon_dir/$APP_NAME.png"

  mkdir -p "$icon_dir"

  if command -v wget &>/dev/null; then
    wget -q -O "$ico_file" "https://music.163.com/favicon.ico" 2>/dev/null || true
  elif command -v curl &>/dev/null; then
    curl -s -o "$ico_file" "https://music.163.com/favicon.ico" 2>/dev/null || true
  fi

  if [ ! -f "$ico_file" ]; then
    echo "Warning: Could not download icon from music.163.com"
    return 1
  fi

  if command -v python3 &>/dev/null; then
    python3 -c "
from PIL import Image
img = Image.open('$ico_file')
img = img.resize((128, 128), Image.LANCZOS)
img.save('$png_file')
print('Icon saved to $png_file')
" 2>/dev/null && return 0
  fi

  if command -v convert &>/dev/null; then
    convert "$ico_file" -resize 128x128 "$png_file" 2>/dev/null && return 0
  fi

  cp "$ico_file" "$png_file" 2>/dev/null && return 0

  return 1
}

write_desktop_file() {
  local apps_dir="$1"
  local browser_path="$2"
  local browser_name
  browser_name=$(basename "$browser_path")

  mkdir -p "$apps_dir"

  local exec_cmd
  exec_cmd="$browser_path --app=$URL --no-first-run --class=$APP_NAME"

  cat > "$apps_dir/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Name=$APP_DISPLAY_NAME
Name[en]=$APP_DISPLAY_NAME_EN
Comment=$COMMENT
Exec=$exec_cmd
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Player;
StartupNotify=true
StartupWMClass=$APP_NAME
EOF

  chmod +x "$apps_dir/$APP_NAME.desktop"
  echo "Created: $apps_dir/$APP_NAME.desktop"
  echo "  Name: $APP_DISPLAY_NAME"
  echo "  Exec: $exec_cmd"
  echo "  Icon: $APP_NAME"
}

update_desktop_cache() {
  local apps_dir="$1"
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$apps_dir" 2>/dev/null || true
    echo "Desktop database updated"
  fi
}

main() {
  echo "==> Detecting browser..."
  local browser_path
  browser_path=$(detect_browser) || {
    echo "Error: No supported browser found (Chrome/Chromium/Brave/Edge/Vivaldi)."
    echo "Please install one of: google-chrome, chromium, brave-browser, microsoft-edge-stable, vivaldi"
    exit 1
  }
  echo "  Found: $browser_path"

  local data_home
  data_home=$(find_data_home)
  local apps_dir="$data_home/applications"
  local icon_dir="$data_home/icons/hicolor/128x128/apps"

  echo ""
  echo "==> Setting up icon..."
  if download_icon "$icon_dir"; then
    echo "  Icon installed"
  else
    echo "  Warning: Using fallback icon"
  fi

  echo ""
  echo "==> Creating desktop entry..."
  write_desktop_file "$apps_dir" "$browser_path"

  echo ""
  echo "==> Updating desktop cache..."
  update_desktop_cache "$apps_dir"

  echo ""
  echo "================================================"
  echo "Installation complete!"
  echo ""
  echo "You can now:"
  echo "  1. Launch from application menu: $APP_DISPLAY_NAME"
  echo "  2. Pin to taskbar/dock after launching"
  echo ""
  echo "Or run directly:"
  echo "  $browser_path --app=$URL"
  echo "================================================"
}

main "$@"
