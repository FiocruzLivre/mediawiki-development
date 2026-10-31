#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  script="$root/scripts/check-release-tag"
}

@test "a MediaWiki version followed by a positive image revision is accepted" {
  run bash "$script" 1.46.2-r1 1.46.2
  [ "$status" -eq 0 ]
  run bash "$script" 1.46.2-r23 1.46.2
  [ "$status" -eq 0 ]
}

@test "the release tag cannot declare another MediaWiki version" {
  run bash "$script" 1.46.3-r1 1.46.2
  [ "$status" -ne 0 ]
}

@test "latest, revision zero, and malformed tags are rejected" {
  for tag in latest 1.46.2 1.46.2-r0 v1.46.2-r1 1.46.2-r1-extra; do
    run bash "$script" "$tag" 1.46.2
    [ "$status" -ne 0 ]
  done
}
