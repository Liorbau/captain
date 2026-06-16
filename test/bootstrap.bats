#!/usr/bin/env bats
#
# Tests for bootstrap.sh. The download is stubbed via a file:// fixture and the
# installer runs against a throwaway HOME so it never touches the real system.

setup() {
  SRC="$(mktemp -d)"
  mkdir -p "$SRC/bin"
  cp "$BATS_TEST_DIRNAME/../bin/cptn" "$SRC/bin/cptn"

  WORK="$(mktemp -d)"
  sed "s#https://raw.githubusercontent.com/Liorbau/captain/\${CAPTAIN_REF}#file://$SRC#" \
    "$BATS_TEST_DIRNAME/../bootstrap.sh" > "$WORK/bootstrap.sh"

  FH="$(mktemp -d)"
}

teardown() {
  rm -rf "$SRC" "$WORK" "$FH"
}

@test "installs cptn to the install dir" {
  run env HOME="$FH" SHELL=/bin/zsh PATH="/usr/bin:/bin" \
    CAPTAIN_INSTALL_DIR="$FH/bin" bash "$WORK/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ -x "$FH/bin/cptn" ]
}

@test "adds install dir to PATH in .zshrc when missing, idempotently" {
  env HOME="$FH" SHELL=/bin/zsh PATH="/usr/bin:/bin" \
    CAPTAIN_INSTALL_DIR="$FH/bin" bash "$WORK/bootstrap.sh"
  env HOME="$FH" SHELL=/bin/zsh PATH="/usr/bin:/bin" \
    CAPTAIN_INSTALL_DIR="$FH/bin" bash "$WORK/bootstrap.sh"
  run grep -cF "$FH/bin" "$FH/.zshrc"
  [ "$output" -eq 1 ]
}

@test "--no-modify-path leaves the shell rc untouched" {
  run env HOME="$FH" SHELL=/bin/zsh PATH="/usr/bin:/bin" \
    CAPTAIN_INSTALL_DIR="$FH/bin" bash "$WORK/bootstrap.sh" --no-modify-path
  [ "$status" -eq 0 ]
  [ ! -f "$FH/.zshrc" ]
  echo "$output" | grep -qF "Add this line"
}

@test "does not edit rc when the install dir is already on PATH" {
  run env HOME="$FH" SHELL=/bin/zsh PATH="$FH/bin:/usr/bin:/bin" \
    CAPTAIN_INSTALL_DIR="$FH/bin" bash "$WORK/bootstrap.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$FH/.zshrc" ]
}

@test "rejects unknown options" {
  run env HOME="$FH" SHELL=/bin/zsh PATH="/usr/bin:/bin" \
    CAPTAIN_INSTALL_DIR="$FH/bin" bash "$WORK/bootstrap.sh" --bogus
  [ "$status" -ne 0 ]
}
