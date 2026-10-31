#!/usr/bin/env bats

setup() {
  root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  helper="$root/.docker/mediawiki/scripts/mediawiki-prepare"
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/source/includes" "$tmp/wiki" "$tmp/src/mediawiki"
  printf '%s\n' '<?php define( '"'"'MW_VERSION'"'"', '"'"'1.46.2'"'"' );' > "$tmp/source/includes/Defines.php"
  echo "source" > "$tmp/source/index.php"
}

teardown() {
  rm -rf "$tmp"
}

prepare() {
  bash "$helper" "$tmp/source" "$tmp/wiki" "$tmp/src/mediawiki" 1.46.2
}

@test "uma wiki nova recebe código e configuração, sem sobrescrever fontes" {
  echo "configurações" > "$tmp/src/mediawiki/LocalSettings.php"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/wiki/index.php")" = "source" ]
  [ -L "$tmp/wiki/LocalSettings.php" ]
  [ "$(cat "$tmp/wiki/LocalSettings.php")" = "configurações" ]
}

@test "reiniciar não altera conteúdo já editado nem a configuração existente" {
  prepare
  echo "edição editorial" > "$tmp/wiki/custom.txt"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(cat "$tmp/wiki/custom.txt")" = "edição editorial" ]
}

@test "mudança de versão bloqueia inicialização sem alterar o código persistido" {
  prepare
  echo "modificado" > "$tmp/wiki/index.php"
  printf '%s\n' '<?php define( '"'"'MW_VERSION'"'"', '"'"'1.47.0'"'"' );' > "$tmp/wiki/includes/Defines.php"
  run prepare
  [ "$status" -ne 0 ]
  [[ "$output" == *"differs from image version"* ]]
  [ "$(cat "$tmp/wiki/index.php")" = "modificado" ]
  grep -q "1.47.0" "$tmp/wiki/includes/Defines.php"
}

@test "não substitui volume inicializado parcialmente" {
  echo "arquivo da instalação" > "$tmp/wiki/configuration.php"
  run prepare
  [ "$status" -ne 0 ]
  [ "$(cat "$tmp/wiki/configuration.php")" = "arquivo da instalação" ]
  [ ! -e "$tmp/wiki/index.php" ]
}

@test "não publica imagem com origem inválida ou versão não correspondente" {
  rm "$tmp/source/includes/Defines.php"
  run prepare
  [ "$status" -ne 0 ]
  [ ! -f "$tmp/wiki/index.php" ]
}

@test "recusa conflito de configuração sem apagar ou substituir arquivo" {
  prepare
  echo "versão local" > "$tmp/wiki/LocalSettings.php"
  echo "versão nova" > "$tmp/src/mediawiki/LocalSettings.php"
  run prepare
  [ "$status" -ne 0 ]
  [ "$(cat "$tmp/wiki/LocalSettings.php")" = "versão local" ]
}

@test "recusa symlink alheio sem apagar seu alvo" {
  prepare
  echo "original" > "$tmp/externo"
  ln -s "$tmp/externo" "$tmp/wiki/LocalSettings.php"
  echo "nova configuração" > "$tmp/src/mediawiki/LocalSettings.php"
  run prepare
  [ "$status" -ne 0 ]
  [ "$(cat "$tmp/externo")" = "original" ]
  [ "$(readlink "$tmp/wiki/LocalSettings.php")" = "$tmp/externo" ]
}

@test "valida todas as configurações antes de criar qualquer link" {
  prepare
  echo "novo" > "$tmp/src/mediawiki/A.php"
  echo "colisão" > "$tmp/src/mediawiki/Z.php"
  echo "protegido" > "$tmp/wiki/Z.php"
  run prepare
  [ "$status" -ne 0 ]
  [ ! -e "$tmp/wiki/A.php" ]
  [ "$(cat "$tmp/wiki/Z.php")" = "protegido" ]
}

@test "configuração aceita continua idempotente" {
  echo "site" > "$tmp/src/mediawiki/LocalSettings.php"
  prepare
  target="$(readlink "$tmp/wiki/LocalSettings.php")"
  run prepare
  [ "$status" -eq 0 ]
  [ "$(readlink "$tmp/wiki/LocalSettings.php")" = "$target" ]
}

@test "remove sticky bit que bloqueia seguir links sem alterar arquivos existentes" {
  prepare
  chmod 1777 "$tmp/wiki"
  run prepare
  [ "$status" -eq 0 ]
  [ ! -k "$tmp/wiki" ]
  [ -f "$tmp/wiki/index.php" ]
}
