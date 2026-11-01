#!/usr/bin/env bats

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.."
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
  if [ -n "${standalone_container:-}" ]; then
    docker rm -f "$standalone_container" >/dev/null 2>&1 || true
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

# This uses the Compose MariaDB as an independently running service.
# Without LocalSettings.php, HTTP 200 may be the installer: this checks
# startup readiness, not the behavior of an installed wiki.
@test "a standalone image connects to the database before serving HTTP" {
  database="$(docker compose ps -q database)"
  image="$(docker compose images -q mediawiki)"
  [ -n "$database" ]
  [ -n "$image" ]

  network="$(docker inspect "$database" --format '{{json .NetworkSettings.Networks}}' | jq -r 'keys[0]')"
  config="$(docker compose config --format json)"
  db_name="$(printf '%s' "$config" | jq -r '.services.database.environment.MYSQL_DATABASE')"
  db_user="$(printf '%s' "$config" | jq -r '.services.database.environment.MYSQL_USER')"
  db_password="$(printf '%s' "$config" | jq -r '.services.database.environment.MYSQL_PASSWORD')"
  [ -n "$network" ]
  [ -n "$db_name" ]
  [ -n "$db_user" ]
  [ -n "$db_password" ]

  standalone_container="mediawiki-db-contract-${BATS_TEST_NUMBER}"
  docker run -d --rm --name "$standalone_container" \
    --network "$network" --publish 127.0.0.1::80 \
    --volume /var/www/mediawiki \
    -e WG_DB_TYPE=mysql -e WG_DB_SERVER=database \
    -e WG_DB_NAME="$db_name" -e WG_DB_USER="$db_user" \
    -e WG_DB_PASSWORD="$db_password" -e WAIT_FOR_DB_TIMEOUT=20 \
    "$image" >/dev/null

  port="$(docker port "$standalone_container" 80/tcp | sed -nE 's/.*:([0-9]+)$/\1/p' | head -n 1)"
  [ -n "$port" ]

  response=""
  for attempt in $(seq 1 40); do
    response="$(curl --silent --location --max-redirs 3 --max-time 3 \
      --output /dev/null --write-out '%{http_code}' "http://127.0.0.1:$port/" || true)"
    [ "$response" = 200 ] && break
    [ "$(docker inspect "$standalone_container" --format '{{.State.Running}}')" = true ] || break
    sleep 1
  done
  [ "$response" = 200 ]

  run docker logs "$standalone_container"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MySQL database connection ready"* ]]
}
