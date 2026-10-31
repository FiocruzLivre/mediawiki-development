#!/usr/bin/env bats

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.."
}

@test "servidor e capturador de e-mail respondem no ambiente isolado" {
  for attempt in $(seq 1 45); do
    if curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done
  run curl -fsS http://127.0.0.1:8080/
  [ "$status" -eq 0 ]
  run curl -fsS http://127.0.0.1:8025/
  [ "$status" -eq 0 ]
}

@test "versões do PHP e MediaWiki são as especificadas no Compose" {
  expected_php="$(docker compose config --format json | jq -r '.services.mediawiki.build.args.PHP_RUNTIME_VERSION | split("-")[0]')"
  run docker compose exec -T mediawiki php -r 'echo PHP_VERSION;'
  [ "$status" -eq 0 ]
  [ "$output" = "$expected_php" ]

  expected_wiki="$(docker compose config --format json | jq -r '.services.mediawiki.build.args.MEDIAWIKI_VERSION')"
  run docker compose exec -T mediawiki grep -m1 "define( 'MW_VERSION'" includes/Defines.php
  [ "$status" -eq 0 ]
  [[ "$output" == *"'$expected_wiki'"* ]]
}

@test "imagem oferece extensões PHP e ferramentas efetivamente usadas" {
  run docker compose exec -T mediawiki php -m
  [ "$status" -eq 0 ]
  for name in memcached gd luasandbox apcu; do
    printf '%s\n' "$output" | grep -Fxi "$name"
  done
  run docker compose exec -T mediawiki sh -c 'command -v composer && command -v git && command -v unzip && command -v mediawiki-prepare'
  [ "$status" -eq 0 ]
}

@test "dependências carregadas não possuem alertas de segurança conhecidos" {
  run docker compose exec -T mediawiki composer audit --locked --no-dev
  [ "$status" -eq 0 ]
}

@test "MediaWiki não reescreve arquivos existentes após reinício" {
  before="$(docker compose exec -T mediawiki sha256sum composer.lock | cut -d ' ' -f1)"
  run docker compose restart mediawiki
  [ "$status" -eq 0 ]
  after="$(docker compose exec -T mediawiki sha256sum composer.lock | cut -d ' ' -f1)"
  [ -n "$before" ]
  [ "$before" = "$after" ]
}

@test "banco local atinge o estado saudável" {
  run docker compose exec -T database healthcheck.sh --connect --innodb_initialized
  [ "$status" -eq 0 ]
}
