#!/bin/bash

RATEL_VERSION="1.0.0"
RATEL_AUTHOR="Daniel"
RATEL_GITHUB="https://github.com/Ratel-Dart/Ratel"

check_dart() {
  command -v dart &> /dev/null || {
    echo "Error: Dart SDK not installed - https://dart.dev/get-dart"
    exit 1
  }
}

create_project() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Uso: ratel create <nome_do_app>"
    exit 1
  fi

  git clone --depth=1 --quiet https://github.com/Ratel-Dart/simple-brick.git "$name" > /dev/null 2>&1

  rm -rf "$name/.git"

  local pkg_name="${name//-/_}"
  sed -i "s/^name: .*/name: $pkg_name/" "$name/pubspec.yaml"

  echo "Project '$name' has been created!"
  echo "cd $name && dart run"
}

version() { 
  echo "Ratel CLI v$RATEL_VERSION" 
}

info() {
  printf "Ratel Framework\nVersion: %s\nAuthor:  %s\nGitHub:  %s\n" \
    "$RATEL_VERSION" "$RATEL_AUTHOR" "$RATEL_GITHUB"
}

install() {
  local script_path
  script_path="$(realpath "$0")"
  sudo cp "$script_path" /usr/local/bin/ratel
  sudo chmod +x /usr/local/bin/ratel
  echo "Ratel $RATEL_VERSION has been installed"
}

case "$1" in
  -v|--version) version ;;
  create) create_project "$2" ;;
  install) install ;;
  info) info ;;
  -h|--help|"")
    echo "Usage: ratel [command]"
    echo ""
    echo "Commands:"
    echo "  install           Install globally (requires sudo)"
    echo "  create <app_name> Create new Dart project"
    echo "  info              Show framework details"
    echo ""
    echo "Options:"
    echo "  -v, --version     Show CLI version"
    echo "  -h, --help        Show this help"
    exit 0
    ;;
  *)
    echo "Invalid command: $1"
    echo "Run 'ratel --help' for available commands"
    exit 1
    ;;
esac
