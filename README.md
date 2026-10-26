# MediaWiki development environment

Shared Docker development setup for MediaWiki deployments, including Mapa dos Movimentos Sociais em Saúde and WikiFavelas. Configuration, extensions, and application data belong to each wiki; they are **not** included in this repository.

## Supported default stack

- MediaWiki **1.46.2** (official Apache image, patched PHP 8.3.36 or later).
- MariaDB **11.8.6**; Memcached 1.6.
- Xdebug is **not installed or enabled by default**.
- Host-published development ports bind to **127.0.0.1**, not to the public network.

See [the upgrade guide](docs/UPGRADING.md) before upgrading an existing wiki. Changing the image version alone **does not upgrade the MediaWiki source tree mounted in `volumes/mediawiki`**, the extensions, or the database.

## Fresh development setup

1. Clone this repository and create a project-specific, untracked `.env`. Set strong, distinct values for `WG_SECRET_KEY`, `WG_UPGRADE_KEY`, `WG_DB_PASSWORD`, `MYSQL_PASSWORD`, and `MYSQL_ROOT_PASSWORD` (for example, generate values using `openssl rand -hex 32`).
2. Check out MediaWiki source corresponding to `MEDIAWIKI_VERSION` into `volumes/mediawiki`. For example:

   ```bash
   git clone --depth 1 --branch 1.46.2 --recurse-submodules \
     https://gerrit.wikimedia.org/r/mediawiki/core.git volumes/mediawiki
   ```

3. Place the chosen wiki's configuration into `volumes/src/mediawiki`. Both Mapa Mov Saúde and WikiFavelas use the canonical [FiocruzLivre/mediawiki-settings](https://github.com/FiocruzLivre/mediawiki-settings) repository (the older LibreCodeCoop/mapa-colaborativo URL redirects there). Existing installations may have divergent or uncommitted configurations: compare the specific wiki's settings, themes and extensions before deployment. Application settings are separate from this Docker setup. The entrypoint links overrides from `volumes/src/mediawiki`; review the settings and extensions before launching.
4. Build and start the development services:

   ```bash
   docker compose build mediawiki
   docker compose up -d
   docker compose exec mediawiki php maintenance/run.php update
   ```

Do not publish the database, MailHog, or development PHP process directly on the Internet. Use a reviewed production Compose override with a TLS reverse proxy, external networks, and production-only secrets; inspect the effective configuration using `docker compose config`.

## Development options

| Variable | Default | Purpose |
| --- | --- | --- |
| `MEDIAWIKI_VERSION` | `1.46.2` | MediaWiki base image version; must match source code |
| `MARIADB_VERSION` | `11.8.6` | Database image for a **new** development volume |
| `HTTP_BIND_IP` | `127.0.0.1` | Host interface for MediaWiki HTTP |
| `MYSQL_BIND_IP` | `127.0.0.1` | Host interface for database |
| `MAILHOG_BIND_IP` | `127.0.0.1` | Host interface for test SMTP UI |
| `ENABLE_XDEBUG` | `0` | Build Xdebug only when explicitly requested |
| `XDEBUG_MODE` | `off` | Set to `debug` to enable the optional extension |

To use debugging locally: set `ENABLE_XDEBUG=1` in your private `.env`, rebuild `mediawiki`, set `XDEBUG_MODE=debug`, and initiate a debugging session with the Xdebug trigger. Debugging is never activated automatically for public requests.

## Verification

Run `bats test/compose.bats` and `docker compose build mediawiki`. CI checks Compose defaults, debug opt-in, host bindings, supported PHP, and the required Memcached PHP extension. The application-level upgrade, extension compatibility, and migration remain environment-specific and must be validated separately.
