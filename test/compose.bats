#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export WG_SECRET_KEY="test-not-a-real-secret"
  export WG_UPGRADE_KEY="test-not-a-real-secret"
}

@test "Compose resolves without errors" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --quiet
  [ "$status" -eq 0 ]
}

@test "default MediaWiki and MariaDB releases are supported" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.services.mediawiki.build.args.MEDIAWIKI_VERSION == "1.46.2"'
  printf '%s\n' "$output" | jq -e '.services.database.image == "mariadb:11.8.6"'
}

@test "debugging is opt-in" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.services.mediawiki.environment.XDEBUG_MODE == "off"'
  printf '%s\n' "$output" | jq -e '.services.mediawiki.build.args.ENABLE_XDEBUG == "0"'
}

@test "explicit debugging options are passed through" {
  run env ENABLE_XDEBUG=1 XDEBUG_MODE=debug docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.services.mediawiki.environment.XDEBUG_MODE == "debug"'
  printf '%s\n' "$output" | jq -e '.services.mediawiki.build.args.ENABLE_XDEBUG == "1"'
}

@test "development ports default to localhost only" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e 'all(.services.mediawiki.ports[]; .host_ip == "127.0.0.1")'
  printf '%s\n' "$output" | jq -e 'all(.services.database.ports[]; .host_ip == "127.0.0.1")'
  printf '%s\n' "$output" | jq -e 'all(.services.mailhog.ports[]; .host_ip == "127.0.0.1")'
}
