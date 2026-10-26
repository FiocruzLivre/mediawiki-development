ARG MEDIAWIKI_VERSION=1.46.2
FROM mediawiki:${MEDIAWIKI_VERSION}

ARG ENABLE_XDEBUG=0

# Use a versioned installer instead of downloading a mutable "latest" script.
COPY --from=ghcr.io/mlocati/php-extension-installer:2.12.3 /usr/bin/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends rsync; \
    rm -rf /var/lib/apt/lists/*; \
    install-php-extensions @composer gd memcached; \
    if [ "$ENABLE_XDEBUG" = "1" ]; then install-php-extensions xdebug; fi; \
    rm -f /usr/local/bin/install-php-extensions

COPY scripts/ /var/www/scripts/
COPY config/php/ /usr/local/etc/php/conf.d/

WORKDIR /var/www/mediawiki
ENTRYPOINT ["bash", "/var/www/scripts/entrypoint.sh"]
