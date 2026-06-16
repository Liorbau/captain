#!/usr/bin/env bats
#
# Tests for bin/cptn. Network is stubbed by pointing BASE_URL at a local
# file:// fixture, so these run offline and deterministically.

setup() {
  SRC="$(mktemp -d)"
  # Note: deliberately NO trailing newline, mirroring a real policy file, so the
  # end-marker placement is exercised.
  printf '# Engineering Policy\nrule one\nrule two' > "$SRC/AGENTS.md"

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

@test "init writes the policy block into AGENTS.md and CLAUDE.md only" {
  run "$CPTN" init
  [ "$status" -eq 0 ]
  grep -qF "captain:begin" AGENTS.md
  grep -qF "rule one" AGENTS.md
  grep -qF "captain:begin" CLAUDE.md
  grep -qF "rule one" CLAUDE.md
  # nothing else should be created
  [ ! -f ai-engineering-policy.md ]
  [ ! -d .cursor ]
}

@test "end marker is on its own line even when policy has no trailing newline" {
  "$CPTN" init
  run grep -x -- "<!-- captain:end -->" AGENTS.md
  [ "$status" -eq 0 ]
  run grep -x -- "<!-- captain:end -->" CLAUDE.md
  [ "$status" -eq 0 ]
}

@test "init is idempotent (single block, byte-stable on re-run)" {
  "$CPTN" init
  run grep -cF "captain:begin" AGENTS.md
  [ "$output" -eq 1 ]
  before="$(cksum < AGENTS.md)"
  "$CPTN" update
  after="$(cksum < AGENTS.md)"
  [ "$before" = "$after" ]
}

@test "an existing AGENTS.md is preserved and gets the block appended" {
  printf '# my own rules\nkeep me\n' > AGENTS.md
  run "$CPTN" init
  [ "$status" -eq 0 ]
  grep -qF "keep me" AGENTS.md
  grep -qF "rule one" AGENTS.md
}

@test "an existing CLAUDE.md is never erased; content preserved, block appended" {
  printf '# My CLAUDE\nline one\nline two\n@AGENTS.md\n' > CLAUDE.md
  before="$(wc -l < CLAUDE.md)"
  run "$CPTN" init
  [ "$status" -eq 0 ]
  grep -qF "line one" CLAUDE.md
  grep -qF "line two" CLAUDE.md
  grep -qF "@AGENTS.md" CLAUDE.md
  grep -qF "rule one" CLAUDE.md
  after="$(wc -l < CLAUDE.md)"
  [ "$after" -gt "$before" ]
}

@test "update refreshes the block in place, preserving user content" {
  printf '# my own rules\nkeep me\n' > AGENTS.md
  "$CPTN" init
  grep -qF "keep me" AGENTS.md
  grep -qF "rule one" AGENTS.md
  # change the upstream policy, then update
  printf '# Engineering Policy v2\nNEW RULE\n' > "$SRC/AGENTS.md"
  "$CPTN" update
  grep -qF "keep me" AGENTS.md      # user content preserved
  grep -qF "NEW RULE" AGENTS.md     # new policy present
  run grep -cF "captain:begin" AGENTS.md
  [ "$output" -eq 1 ]               # still exactly one block
  run grep -qF "rule one" AGENTS.md
  [ "$status" -ne 0 ]               # old policy text removed
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
