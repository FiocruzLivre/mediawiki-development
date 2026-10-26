# Upgrade an existing MediaWiki deployment

This is an operator checklist for both Mapa Mov Saúde and WikiFavelas. The shared Docker setup cannot safely upgrade an existing wiki by changing the container tag alone. **Shared configuration repository:** [FiocruzLivre/mediawiki-settings](https://github.com/FiocruzLivre/mediawiki-settings) covers Mapa Mov Saúde and WikiFavelas; the historical LibreCodeCoop/mapa-colaborativo URL redirects to it. Their local revisions, enabled extensions and uncommitted settings can differ: compare each environment against the intended configuration before rollout.

## 1. Capture inventory and a recoverable baseline

Record the effective Docker Compose configuration, MediaWiki core version, actual PHP runtime, enabled skins/extensions, and all uncommitted modifications to the MediaWiki core. Keep application configuration (`LocalSettings.php`), uploads, and database credentials outside Git.

Create **independent** backups of the application directory (including uploads and custom extensions) and the database. Check a backup's size and completion markers, and restore at least one file into an isolated directory. Database rollback requires a pre-migration snapshot; reverting containers alone cannot reverse schema changes.

## 2. Prepare isolated staging

Create a separate working directory and database; **do not** point staging at the production database or production volume. Copy only the necessary sanitized configuration and a consistent database snapshot. Make sure staging cannot send real user emails or tracking events.

Check out MediaWiki `1.46.2` and a matching set of maintained extensions and skins. For Wikimedia-maintained extensions, prefer the `REL1_46` branch or a matching release. Audit third-party and custom extensions individually; disable only with a recorded compatibility decision. Preserve application customizations in separate version-controlled configuration or extensions, rather than reapplying edits to MediaWiki core.

MediaWiki 1.46 requires PHP 8.3+; the official `mediawiki:1.46.2` image was checked with PHP 8.3.36. Database schema compatibility and extension compatibility must be checked independently.

## 3. Verify the container before upgrading data

```bash
docker compose config
docker compose build mediawiki
docker compose run --rm --no-deps --entrypoint php mediawiki -v
```

Never rely on a successfully built image as proof that the existing wiki's data, extensions, or skins work.

## 4. Perform and test the staging migration

After upgrading source and all compatible extensions/skins, run:

```bash
docker compose exec mediawiki php maintenance/run.php update
```

Review the command output and test login, permissions, edits, preview, uploads, VisualEditor, PageForms, semantic and geospatial features (when enabled), special pages, jobs, search, and any custom themes. Verify Nginx/proxy HTTP responses, logs, backups, and cache behavior.

Compare all wiki-specific functionality before and after upgrading. If an extension has no compatible release, treat that as a migration blocker rather than silently omitting it.

## 5. Production cutover and rollback

Schedule a maintenance window, stop writes, take a final consistent database and file backup, deploy the tested image/source/configuration, run the production migration, and validate basic functions and service monitoring before restoring traffic.

Keep the former application artifacts and complete database snapshot until all tests pass. Rollback after a database migration means restoring the matching **database snapshot and source tree**, not only switching Docker images. Avoid mixing production database versions or multiple MediaWiki core versions against one database.

For published deployments, remove debugging, bind administrative ports privately, use secure credentials, and keep a reliable backup and external monitoring procedure. Upgrading the database engine should be evaluated independently of the MediaWiki application migration.
