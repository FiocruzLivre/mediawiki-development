#!/usr/bin/env bats

setup() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.."
  name="mediawiki-external-db-contract-${BATS_TEST_NUMBER}"
}

teardown() {
  docker rm -f "$name" >/dev/null 2>&1 || true
}

@test "a standalone MediaWiki image starts with an independently managed database" {
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

  docker run -d --rm --name "$name" \
    --network "$network" --publish 127.0.0.1::80 \
    --volume /var/www/mediawiki \
    -e WG_DB_TYPE=mysql -e WG_DB_SERVER=database \
    -e WG_DB_NAME="$db_name" -e WG_DB_USER="$db_user" \
    -e WG_DB_PASSWORD="$db_password" -e WAIT_FOR_DB_TIMEOUT=20 \
    "$image" >/dev/null

  port="$(docker port "$name" 80/tcp | sed -nE 's/.*:([0-9]+)$/\1/p' | head -n 1)"
  [ -n "$port" ]

  status=""
  for attempt in $(seq 1 40); do
    status="$(curl --silent --location --max-redirs 3 --max-time 3 --output /dev/null \
      --write-out '%{http_code}' "http://127.0.0.1:$port/" || true)"
    [ "$status" = 200 ] && break
    [ "$(docker inspect "$name" --format '{{.State.Running}}')" = true ] || break
    sleep 1
  done
  [ "$status" = 200 ]

  run docker logs "$name"
  [ "$status" -eq 0 ]
  [[ "$output" == *"MySQL database connection ready"* ]]
}
