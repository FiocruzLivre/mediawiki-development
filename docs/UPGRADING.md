# Upgrading an existing MediaWiki installation

This guide applies to any deployment using this shared Docker development setup. A changed image tag alone does **not** upgrade an existing MediaWiki code volume.

## Prepare and isolate

1. Record the effective Compose configuration, application version, PHP runtime and enabled skins/extensions. Review custom code modifications and configuration separately.
2. Make complete backups of the persistent database, application files and uploaded content. Verify that a backup can be read and at least one file can be restored. Capture a consistent database snapshot for rollback.
3. Create a dedicated staging environment with its **own** volumes, database, project name and host ports. Never run a test migration against the production database.

## Update the application in staging

1. Change the base image version in the Compose configuration and use a **matching** MediaWiki source checkout in the staging application volume.
2. Update and validate every installed extension and skin against the target MediaWiki core. Check Composer security advisories; do not bypass known vulnerabilities to make an outdated dependency resolve.
3. Rebuild the image and start the isolated stack:
   ```bash
   docker compose build mediawiki
   docker compose up -d
   ```
4. After confirming source and extensions are compatible, explicitly run the schema update:
   ```bash
   docker compose exec mediawiki php maintenance/run.php update
   ```
5. Exercise login, permissions, edits, previews, uploads, special pages, jobs, search, any installed extensions, and email delivery. Review service logs and health checks.

## Production change and rollback

Schedule a maintenance window, freeze writes, create a final verified backup, and only then deploy the tested configuration/source and migrate its database. Verify functionality before restoring normal traffic.

A database schema upgrade may not be reversible by restoring the old container. The rollback plan must include restoring the **matching database snapshot, application files and configuration**.

Never place production credentials, backups, or instance-specific configuration in this general-purpose repository.
