# Implantação com Docker Compose

O `docker-compose.yml` da raiz oferece um ambiente local com MariaDB e Mailpit. Para produção ou banco externo, mantenha a configuração própria da instalação em `docker-compose.override.yml`, **não versionado**, e as credenciais em `.env`. Não altere o Compose compartilhado.

## Banco externo e proxy reverso

1. Configure no `.env`: `WG_SERVER` (URL pública), `WG_DB_SERVER`, `WG_DB_NAME`, `WG_DB_USER` e `WG_DB_PASSWORD`. Não use as senhas de desenvolvimento.
2. Crie `docker-compose.override.yml` na raiz da instalação:

```yaml
services:
  mediawiki:
    ports: !reset []
    depends_on: !reset {}
    build:
      args:
        ENABLE_XDEBUG: "0"
    environment:
      XDEBUG_MODE: "off"
      WG_SERVER: ${WG_SERVER:?Set WG_SERVER in .env}
      WG_DB_SERVER: ${WG_DB_SERVER:?Set WG_DB_SERVER in .env}
      WG_DB_NAME: ${WG_DB_NAME:?Set WG_DB_NAME in .env}
      WG_DB_USER: ${WG_DB_USER:?Set WG_DB_USER in .env}
      WG_DB_PASSWORD: ${WG_DB_PASSWORD:?Set WG_DB_PASSWORD in .env}
      WG_SMTP_HOST: ${WG_SMTP_HOST:-}

  database:
    profiles: [local-only]
    ports: !reset []

  mailpit:
    profiles: [local-only]
    ports: !reset []
```

3. Conecte o contêiner MediaWiki às redes necessárias para alcançar o banco e o proxy. Isso depende da infraestrutura de cada instalação; não exponha a porta HTTP diretamente.
4. Antes de iniciar, confira o resultado combinado:

```sh
docker compose config --quiet
docker compose config --services
docker compose up -d
```

Nesse exemplo, somente `mediawiki` e `memcached` são iniciados; MariaDB e Mailpit internos ficam desativados. Se o banco externo não usar a porta 3306, defina `WG_DB_PORT` no `.env`. O entrypoint verifica a autenticação no MySQL antes de inicializar a wiki e o Apache, aguardando até 60 segundos por padrão (`WAIT_FOR_DB_TIMEOUT`, ajustável no Compose override). Se a conexão não estiver disponível, ele falha; a política de reinício do Docker tenta novamente. Isso não substitui a recuperação de conexões durante o funcionamento do MediaWiki.

## Atualizações

A imagem nova não substitui o código existente em `volumes/mediawiki` nem migra o banco automaticamente. Antes de promover uma versão, valide compatibilidade das extensões, backup e restauração em uma cópia isolada, e planeje reversão conjunta de dados e código.
