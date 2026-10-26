ARG MEDIAWIKI_VERSION
FROM mediawiki:${MEDIAWIKI_VERSION}

ARG MEDIAWIKI_VERSION
ARG ENABLE_XDEBUG=0
ENV MEDIAWIKI_IMAGE_VERSION=${MEDIAWIKI_VERSION}

COPY --from=ghcr.io/mlocati/php-extension-installer:2.12.3 /usr/bin/install-php-extensions /usr/local/bin/

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends rsync; \
    rm -rf /var/lib/apt/lists/*; \
    install-php-extensions @composer gd memcached; \
    if [ "$ENABLE_XDEBUG" = "1" ]; then install-php-extensions xdebug; fi; \
    rm -f /usr/local/bin/install-php-extensions; \
    sed -i 's#DocumentRoot /var/www/html#DocumentRoot /var/www/mediawiki#' /etc/apache2/sites-available/000-default.conf

COPY scripts/ /usr/local/bin/
COPY config/php/ /usr/local/etc/php/conf.d/

WORKDIR /var/www/mediawiki
ENTRYPOINT ["/usr/local/bin/mediawiki-entrypoint"]
