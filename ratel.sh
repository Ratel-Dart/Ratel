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
  [[ -z "$1" ]] && { echo "Usage: ratel create <app_name>"; exit 1; }
  check_dart
  dart create --template console-simple "$1"
  cd "$1" || exit
  mkdir -p lib/src lib/models bin config
  touch lib/app.dart bin/main.dart
  echo "✅ Created $1 - cd $1 && dart run"
}

version() { 
  echo "Ratel CLI v$RATEL_VERSION" 
}

info() {
  printf "Ratel Framework\nVersion: %s\nAuthor:  %s\nGitHub:  %s\n" \
    "$RATEL_VERSION" "$RATEL_AUTHOR" "$RATEL_GITHUB"
}

install() {
  LOCAL_SCRIPT_PATH="$(realpath "$0")"

  echo "Updating Ratel CLI..."
  sudo cp "$LOCAL_SCRIPT_PATH" /usr/local/bin/ratel
  sudo chmod +x /usr/local/bin/ratel
  echo "Ratel v$RATEL_VERSION installed. Run 'ratel' for help."
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