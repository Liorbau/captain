#!/usr/bin/env bats
#
# Tests for bin/cptn. Network is stubbed by pointing BASE_URL at a local
# file:// fixture, so these run offline and deterministically.

setup() {
  SRC="$(mktemp -d)"
  printf '# Full Policy\nrule one\nrule two\n' > "$SRC/AGENTS.md"
  mkdir -p "$SRC/cursor/rules"
  printf 'RULE CONTENT\n' > "$SRC/cursor/rules/engineering-ownership.mdc"

  WORK="$(mktemp -d)"
  sed "s#https://raw.githubusercontent.com/Liorbau/captain/\${CAPTAIN_REF}#file://$SRC#" \
    "$BATS_TEST_DIRNAME/../bin/cptn" > "$WORK/cptn"
  chmod +x "$WORK/cptn"
  CPTN="$WORK/cptn"

  REPO="$(mktemp -d)"
  cd "$REPO"
  git init -q
}

teardown() {
  rm -rf "$SRC" "$WORK" "$REPO"
}

@test "init vendors the full policy into a fresh AGENTS.md and CLAUDE.md" {
  run "$CPTN" init
  [ "$status" -eq 0 ]
  grep -qF "AI Engineering Policy (managed by cptn)" AGENTS.md
  grep -qF "Full Policy" AGENTS.md
  grep -qF "Full Policy" CLAUDE.md
  [ -f ai-engineering-policy.md ]
  [ -f .cursor/rules/engineering-ownership.mdc ]
}

@test "init is idempotent (no duplicate managed blocks)" {
  "$CPTN" init
  run "$CPTN" init
  [ "$status" -eq 0 ]
  run grep -cF "managed by cptn" AGENTS.md
  [ "$output" -eq 1 ]
}

@test "an existing AGENTS.md is preserved and gets an @import appended" {
  printf '# my own rules\nkeep me\n' > AGENTS.md
  run "$CPTN" init
  [ "$status" -eq 0 ]
  grep -qF "keep me" AGENTS.md
  grep -qF "@ai-engineering-policy.md" AGENTS.md
}

@test "a pre-existing cursor rule is never overwritten" {
  mkdir -p .cursor/rules
  printf 'MY CUSTOM RULE\n' > .cursor/rules/engineering-ownership.mdc
  run "$CPTN" init
  [ "$status" -eq 0 ]
  run cat .cursor/rules/engineering-ownership.mdc
  [ "$output" = "MY CUSTOM RULE" ]
}

@test "status reports the installed state" {
  "$CPTN" init
  run "$CPTN" status
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF "AGENTS.md carries the policy"
}

@test "init outside a git repository fails" {
  NOGIT="$(mktemp -d)"
  cd "$NOGIT"
  run "$CPTN" init
  [ "$status" -ne 0 ]
  rm -rf "$NOGIT"
}

@test "version prints the cptn version" {
  run "$CPTN" version
  [ "$status" -eq 0 ]
  echo "$output" | grep -qF "cptn"
}

@test "unknown command exits non-zero and shows help" {
  run "$CPTN" frobnicate
  [ "$status" -ne 0 ]
  echo "$output" | grep -qF "Usage:"
}
