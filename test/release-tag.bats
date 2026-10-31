#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  script="$root/scripts/check-release-tag"
}

@test "uma versão MediaWiki mais uma revisão da imagem é aceita" {
  run bash "$script" 1.46.2-r1 1.46.2
  [ "$status" -eq 0 ]
  run bash "$script" 1.46.2-r23 1.46.2
  [ "$status" -eq 0 ]
}

@test "tag não pode declarar outra versão do MediaWiki" {
  run bash "$script" 1.46.3-r1 1.46.2
  [ "$status" -ne 0 ]
}

@test "rejeita latest, revisão zero e tags incompletas" {
  for tag in latest 1.46.2 1.46.2-r0 v1.46.2-r1 1.46.2-r1-extra; do
    run bash "$script" "$tag" 1.46.2
    [ "$status" -ne 0 ]
  done
}
