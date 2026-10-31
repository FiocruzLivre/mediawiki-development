#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  compose="$root/docker-compose.yml"
  external="$root/docker-compose.override.example.yml"
}

@test "configuracao local funciona sem arquivos particulares" {
  run docker compose -f "$compose" config --quiet
  [ "$status" -eq 0 ]
}

@test "versoes ficam no Compose e a imagem nao as duplica" {
  run docker compose -f "$compose" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    (.services.mediawiki.build.args.MEDIAWIKI_VERSION | test("^[0-9]+[.][0-9]+[.][0-9]+$")) and
    (.services.mediawiki.build.args.PHP_RUNTIME_VERSION | test("^[0-9]+[.][0-9]+[.][0-9]+-apache-")) and
    ([.services.database.image, .services.memcached.image, .services.mailpit.image] |
      all(. != null and (contains(":")) and (endswith(":latest") | not)))'
  ! grep -Eq '^ARG (MEDIAWIKI_VERSION|PHP_RUNTIME_VERSION)=' "$root/.docker/mediawiki/Dockerfile"
}

@test "credenciais locais sao as mesmas no banco e MediaWiki" {
  run env WG_DB_NAME=banco_teste WG_DB_USER=usuario_teste WG_DB_PASSWORD=teste     docker compose -f "$compose" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.environment.WG_DB_NAME == .services.database.environment.MYSQL_DATABASE and
    .services.mediawiki.environment.WG_DB_USER == .services.database.environment.MYSQL_USER and
    .services.mediawiki.environment.WG_DB_PASSWORD == .services.database.environment.MYSQL_PASSWORD'
}

@test "modo local deixa portas apenas no loopback e debug desligado" {
  run docker compose -f "$compose" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.environment.XDEBUG_MODE == "off" and
    .services.mediawiki.build.args.ENABLE_XDEBUG == "0" and
    (all(.services.mediawiki.ports[]; .host_ip == "127.0.0.1")) and
    (all(.services.database.ports[]; .host_ip == "127.0.0.1")) and
    (all(.services.mailpit.ports[]; .host_ip == "127.0.0.1"))'
}

@test "modo externo exige configuracao explicita em vez de senha local" {
  run env -u WG_DB_PASSWORD -u WG_DB_NAME -u WG_DB_USER -u WG_DB_SERVER -u WG_SERVER     docker compose -f "$compose" -f "$external" config --quiet
  [ "$status" -ne 0 ]
}

@test "modo externo remove portas e dependencia do banco embutido" {
  run env WG_SERVER=https://wiki.example.invalid WG_DB_SERVER=banco-externo     WG_DB_NAME=producao WG_DB_USER=wiki WG_DB_PASSWORD=teste     docker compose -f "$compose" -f "$external" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    (.services.mediawiki.ports // [] | length) == 0 and
    (.services.mediawiki.depends_on // {} | length) == 0 and
    .services.mediawiki.environment.WG_DB_SERVER == "banco-externo" and
    .services.mediawiki.environment.XDEBUG_MODE == "off" and
    .services.mediawiki.build.args.ENABLE_XDEBUG == "0" and
    (.services | has("database") | not) and
    (.services | has("mailpit") | not)'
  run env WG_SERVER=https://wiki.example.invalid WG_DB_SERVER=banco-externo     WG_DB_NAME=producao WG_DB_USER=wiki WG_DB_PASSWORD=teste     docker compose -f "$compose" -f "$external" config --services
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'mediawiki\nmemcached')" ]
}

@test "configuracao de cada instalacao permanece ignorada pelo Git" {
  run git -C "$root" check-ignore docker-compose.override.yml
  [ "$status" -eq 0 ]
}
