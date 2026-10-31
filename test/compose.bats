#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  compose="$root/docker-compose.yml"
  external="$root/docker-compose.override.example.yml"
}

@test "local Compose configuration is valid without site-specific files" {
  run docker compose -f "$compose" config --quiet
  [ "$status" -eq 0 ]
}

@test "versions are set by Compose and are not duplicated in the Dockerfile" {
  run docker compose -f "$compose" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    (.services.mediawiki.build.args.MEDIAWIKI_VERSION | test("^[0-9]+[.][0-9]+[.][0-9]+$")) and
    (.services.mediawiki.build.args.PHP_RUNTIME_VERSION | test("^[0-9]+[.][0-9]+[.][0-9]+-apache-")) and
    ([.services.database.image, .services.memcached.image, .services.mailpit.image] |
      all(. != null and contains(":") and (endswith(":latest") | not)))'
  ! grep -Eq '^ARG (MEDIAWIKI_VERSION|PHP_RUNTIME_VERSION)=' "$root/.docker/mediawiki/Dockerfile"
}

@test "database and MediaWiki receive consistent local credentials" {
  run env WG_DB_NAME=test_db WG_DB_USER=test_user WG_DB_PASSWORD=test_pw \
    docker compose -f "$compose" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.environment.WG_DB_NAME == .services.database.environment.MYSQL_DATABASE and
    .services.mediawiki.environment.WG_DB_USER == .services.database.environment.MYSQL_USER and
    .services.mediawiki.environment.WG_DB_PASSWORD == .services.database.environment.MYSQL_PASSWORD'
}

@test "local services expose ports on loopback only and disable debugging" {
  run docker compose -f "$compose" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.environment.XDEBUG_MODE == "off" and
    .services.mediawiki.build.args.ENABLE_XDEBUG == "0" and
    (all(.services.mediawiki.ports[]; .host_ip == "127.0.0.1")) and
    (all(.services.database.ports[]; .host_ip == "127.0.0.1")) and
    (all(.services.mailpit.ports[]; .host_ip == "127.0.0.1"))'
}

@test "external database mode requires explicit connection settings" {
  run env -u WG_DB_PASSWORD -u WG_DB_NAME -u WG_DB_USER \
    -u WG_DB_SERVER -u WG_SERVER \
    docker compose -f "$compose" -f "$external" config --quiet
  [ "$status" -ne 0 ]
}

@test "external database mode removes ports and local-only services" {
  run env WG_SERVER=https://wiki.example.invalid WG_DB_SERVER=external-db \
    WG_DB_NAME=production WG_DB_USER=wiki WG_DB_PASSWORD=test_pw \
    docker compose -f "$compose" -f "$external" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    (.services.mediawiki.ports // [] | length) == 0 and
    (.services.mediawiki.depends_on // {} | length) == 0 and
    .services.mediawiki.environment.WG_DB_SERVER == "external-db" and
    .services.mediawiki.environment.XDEBUG_MODE == "off" and
    .services.mediawiki.build.args.ENABLE_XDEBUG == "0" and
    (.services | has("database") | not) and
    (.services | has("mailpit") | not)'

  run env WG_SERVER=https://wiki.example.invalid WG_DB_SERVER=external-db \
    WG_DB_NAME=production WG_DB_USER=wiki WG_DB_PASSWORD=test_pw \
    docker compose -f "$compose" -f "$external" config --services
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'mediawiki\nmemcached')" ]
}

@test "local deployment overrides remain ignored by Git" {
  run git -C "$root" check-ignore docker-compose.override.yml
  [ "$status" -eq 0 ]
}
