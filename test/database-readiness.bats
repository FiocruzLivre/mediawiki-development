#!/usr/bin/env bats

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.."
}

teardown() {
  if [ -n "${wait_pid:-}" ]; then
    kill "$wait_pid" 2>/dev/null || true
  fi
  if [ "${db_stopped:-0}" = 1 ]; then
    docker compose start database >/dev/null
  fi
  if [ -n "${log_file:-}" ]; then
    rm -f "$log_file"
  fi
  if [ -n "${wiki_volume:-}" ]; then
    rm -rf "$wiki_volume"
  fi
}

@test "database readiness checks application credentials, not only an open port" {
  run docker compose exec -T mediawiki env WAIT_FOR_DB_TIMEOUT=3 \
    php /usr/local/bin/wait-for-db.php
  [ "$status" -eq 0 ]
  [[ "$output" == *"MySQL database connection ready"* ]]

  run docker compose exec -T mediawiki env \
    WG_DB_PASSWORD=deliberately-invalid-test-password WAIT_FOR_DB_TIMEOUT=2 \
    php /usr/local/bin/wait-for-db.php
  [ "$status" -ne 0 ]
  [[ "$output" == *"MySQL database unavailable"* ]]
  [[ "$output" != *"deliberately-invalid-test-password"* ]]
}

@test "unreachable external databases prevent source initialization and Apache startup" {
  image="$(docker compose images -q mediawiki)"
  [ -n "$image" ]
  wiki_volume="$(mktemp -d)"
  run docker run --rm --network none \
    -e WG_DB_TYPE=mysql -e WG_DB_SERVER=127.0.0.1 \
    -e WG_DB_USER=wiki -e WG_DB_PASSWORD=invalid \
    -e WG_DB_NAME=wiki -e WAIT_FOR_DB_TIMEOUT=2 \
    -v "$wiki_volume:/var/www/mediawiki" "$image"
  [ "$status" -ne 0 ]
  [[ "$output" == *"MySQL database unavailable"* ]]
  [ ! -e "$wiki_volume/index.php" ]
}

@test "startup readiness recovers when an unavailable database returns" {
  log_file="$(mktemp)"
  db_stopped=1
  docker compose stop database >/dev/null

  docker compose exec -T mediawiki env WAIT_FOR_DB_TIMEOUT=45 \
    php /usr/local/bin/wait-for-db.php >"$log_file" 2>&1 &
  wait_pid=$!

  sleep 2
  kill -0 "$wait_pid"

  docker compose start database >/dev/null
  db_stopped=0
  wait "$wait_pid"
  grep -q "MySQL database connection ready" "$log_file"
}

@test "SQLite does not wait for an external server and unsupported types fail closed" {
  run docker compose exec -T mediawiki env WG_DB_TYPE=sqlite \
    php /usr/local/bin/wait-for-db.php
  [ "$status" -eq 0 ]

  run docker compose exec -T mediawiki env WG_DB_TYPE=unsupported \
    php /usr/local/bin/wait-for-db.php
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported database type"* ]]
}
