# MediaWiki development environment

A reusable Docker Compose environment for developing and testing MediaWiki.

## Quick start

```bash
git clone https://github.com/FiocruzLivre/mediawiki-development.git
cd mediawiki-development
docker compose up -d
```

Open [MediaWiki](http://localhost:8080) and complete its installation wizard on the first run. The database and required services start automatically. Test emails appear at [Mailpit](http://localhost:8025).

To customize the local address, database credentials or debugging, put overrides in an untracked `.env`. The available variables, defaults and their purposes are documented next to the corresponding settings in [docker-compose.yml](docker-compose.yml). The default credentials and loopback-only port bindings are intended **only for local development**, not public deployments.

Application source code, data and uploads persist under `volumes/`. To work with existing source code, put it under `volumes/mediawiki` **before** starting the stack. Optional project-specific files can be supplied under `volumes/src/mediawiki`.

## Useful commands

```bash
docker compose logs -f mediawiki
docker compose exec mediawiki php maintenance/run.php update
docker compose down
```

The update command is for an **explicitly planned schema migration**, not for a fresh installation. See [upgrading an existing installation](docs/UPGRADING.md) before changing the application version. The container checks the existing source version and refuses mismatches rather than modifying it automatically.

For local Xdebug, explicitly set `ENABLE_XDEBUG=1` and `XDEBUG_MODE=debug` in `.env`, rebuild the image and use an Xdebug trigger when debugging a request.
