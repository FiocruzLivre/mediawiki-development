#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  helper="$root/.docker/mediawiki/scripts/mediawiki-prepare"
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/source/includes" "$tmp/wiki" "$tmp/src/mediawiki"
  printf '%s\n' "<?php define( 'MW_VERSION', '1.46.2' );" > "$tmp/source/includes/Defines.php"
  echo "source" > "$tmp/source/index.php"
}

teardown() {
  rm -rf "$tmp"
}

prepare() {
  bash "$helper" "$tmp/source" "$tmp/wiki" "$tmp/src/mediawiki" 1.46.2
}

@test "a fresh wiki receives source files and site configuration" {
  echo "site settings" > "$tmp/src/mediawiki/LocalSettings.php"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/wiki/index.php")" = "source" ]
  [ -L "$tmp/wiki/LocalSettings.php" ]
  [ "$(cat "$tmp/wiki/LocalSettings.php")" = "site settings" ]
}

@test "restarting preserves existing content and configuration" {
  prepare
  echo "edited content" > "$tmp/wiki/custom.txt"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/wiki/custom.txt")" = "edited content" ]
}

@test "a version mismatch refuses startup without modifying persistent files" {
  prepare
  echo "modified" > "$tmp/wiki/index.php"
  printf '%s\n' "<?php define( 'MW_VERSION', '1.47.0' );" > "$tmp/wiki/includes/Defines.php"
  run prepare
  [ "$status" -ne 0 ]
  [[ "$output" == *"differs from image version"* ]]
  [ "$(cat "$tmp/wiki/index.php")" = "modified" ]
  grep -q "1.47.0" "$tmp/wiki/includes/Defines.php"
}

@test "a partially initialized volume is not overwritten" {
  echo "existing installation file" > "$tmp/wiki/configuration.php"
  run prepare
  [ "$status" -ne 0 ]
  [ "$(cat "$tmp/wiki/configuration.php")" = "existing installation file" ]
  [ ! -e "$tmp/wiki/index.php" ]
}

@test "an invalid image source does not populate a new volume" {
  rm "$tmp/source/includes/Defines.php"
  run prepare
  [ "$status" -ne 0 ]
  [ ! -f "$tmp/wiki/index.php" ]
}

@test "configuration conflicts preserve existing files" {
  prepare
  echo "local version" > "$tmp/wiki/LocalSettings.php"
  echo "new version" > "$tmp/src/mediawiki/LocalSettings.php"
  run prepare
  [ "$status" -ne 0 ]
  [ "$(cat "$tmp/wiki/LocalSettings.php")" = "local version" ]
}

@test "unexpected symlinks are rejected without modifying their targets" {
  prepare
  echo "original" > "$tmp/external"
  ln -s "$tmp/external" "$tmp/wiki/LocalSettings.php"
  echo "new settings" > "$tmp/src/mediawiki/LocalSettings.php"
  run prepare
  [ "$status" -ne 0 ]
  [ "$(cat "$tmp/external")" = "original" ]
  [ "$(readlink "$tmp/wiki/LocalSettings.php")" = "$tmp/external" ]
}

@test "all configuration destinations are checked before adding links" {
  prepare
  echo "new settings" > "$tmp/src/mediawiki/A.php"
  echo "conflicting settings" > "$tmp/src/mediawiki/Z.php"
  echo "protected file" > "$tmp/wiki/Z.php"
  run prepare
  [ "$status" -ne 0 ]
  [ ! -e "$tmp/wiki/A.php" ]
  [ "$(cat "$tmp/wiki/Z.php")" = "protected file" ]
}

@test "matching configuration links remain unchanged on repeated startup" {
  echo "site" > "$tmp/src/mediawiki/LocalSettings.php"
  prepare
  target="$(readlink "$tmp/wiki/LocalSettings.php")"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(readlink "$tmp/wiki/LocalSettings.php")" = "$target" ]
}

@test "existing source files survive removal of a blocking sticky bit" {
  prepare
  chmod 1777 "$tmp/wiki"
  run prepare
  [ "$status" -eq 0 ]
  [ ! -k "$tmp/wiki" ]
  [ -f "$tmp/wiki/index.php" ]
}
