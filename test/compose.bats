#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "Compose renders without local configuration files" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --quiet
  [ "$status" -eq 0 ]
}

@test "runtime images are versioned and PHP build version has one source of truth" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.build.args.MEDIAWIKI_VERSION != "" and
    ([.services.database.image, .services.memcached.image, .services.mailpit.image] |
     all(. != null and (. | contains(":")) and (endswith(":latest") | not)))'
  # Do not duplicate the default core version in the Dockerfile.
  run grep -E '^ARG MEDIAWIKI_VERSION=' "$REPO_ROOT/.docker/mediawiki/Dockerfile"
  [ "$status" -ne 0 ]
}

@test "database credentials use the same environment overrides" {
  run env WG_DB_NAME=override_db WG_DB_USER=override_user WG_DB_PASSWORD=override_pw \
    docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.environment.WG_DB_NAME == .services.database.environment.MYSQL_DATABASE and
    .services.mediawiki.environment.WG_DB_USER == .services.database.environment.MYSQL_USER and
    .services.mediawiki.environment.WG_DB_PASSWORD == .services.database.environment.MYSQL_PASSWORD'
}

@test "debugger is opt-in and development services are private" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.environment.XDEBUG_MODE == "off" and
    .services.mediawiki.build.args.ENABLE_XDEBUG == "0" and
    (all(.services.mediawiki.ports[]; .host_ip == "127.0.0.1")) and
    (all(.services.database.ports[]; .host_ip == "127.0.0.1")) and
    (all(.services.mailpit.ports[]; .host_ip == "127.0.0.1"))'
}

@test "debugger and port settings can be overridden in an untracked .env" {
  run env ENABLE_XDEBUG=1 XDEBUG_MODE=debug HTTP_PORT=19081 MAILPIT_PORT=19082 \
    docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.environment.XDEBUG_MODE == "debug" and
    .services.mediawiki.build.args.ENABLE_XDEBUG == "1" and
    .services.mediawiki.ports[0].published == "19081" and
    .services.mailpit.ports[0].published == "19082"'
}

@test "wiki waits for a healthy database and keeps data on volumes" {
  run docker compose -f "$REPO_ROOT/docker-compose.yml" config --format json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '
    .services.mediawiki.depends_on.database.condition == "service_healthy" and
    .services.database.healthcheck.test != null and
    ([.services.mediawiki.volumes[].target] | index("/var/www/mediawiki") != null) and
    ([.services.database.volumes[].target] | index("/var/lib/mysql") != null)'
}
