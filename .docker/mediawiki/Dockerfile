ARG MEDIAWIKI_VERSION
ARG PHP_RUNTIME_VERSION
FROM mediawiki:${MEDIAWIKI_VERSION} AS mediawiki-source

FROM php:${PHP_RUNTIME_VERSION}

ARG MEDIAWIKI_VERSION
ARG ENABLE_XDEBUG=0
ENV MEDIAWIKI_IMAGE_VERSION=${MEDIAWIKI_VERSION}

COPY --from=mediawiki-source --chown=root:root /var/www/html/ /var/www/html/
COPY --from=ghcr.io/mlocati/php-extension-installer:2.12.3 /usr/bin/install-php-extensions /usr/local/bin/
COPY --from=composer:2.10.3 /usr/bin/composer /usr/local/bin/composer
COPY composer-security.json /tmp/mediawiki-composer-security.json

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
        rsync \
        unzip; \
    rm -rf /var/lib/apt/lists/*; \
    install-php-extensions \
        apcu \
        calendar \
        gd \
        intl \
        mysqli \
        luasandbox \
        memcached; \
    if [ "$ENABLE_XDEBUG" = "1" ]; then \
        install-php-extensions xdebug; \
    fi; \
    rm -f /usr/local/bin/install-php-extensions; \
    sed -i 's#DocumentRoot /var/www/html#DocumentRoot /var/www/mediawiki#' \
        /etc/apache2/sites-available/000-default.conf

# Overrides temporários estão no manifesto Composer e passam pela auditoria.
RUN set -eux; \
    cd /var/www/html; \
    requirement="$(php -r '$r=json_decode(file_get_contents("/tmp/mediawiki-composer-security.json"),true,512,JSON_THROW_ON_ERROR);foreach ($r["require"] as $name=>$range) echo "$name:$range";')"; \
    COMPOSER_ALLOW_SUPERUSER=1 composer require "$requirement" \
        --no-update --no-plugins --no-scripts --no-interaction; \
    COMPOSER_ALLOW_SUPERUSER=1 composer update \
        --no-dev --no-plugins --no-scripts --no-interaction --no-progress; \
    COMPOSER_ALLOW_SUPERUSER=1 composer audit --locked --no-dev

COPY scripts/ /usr/local/bin/
COPY config/php/ /usr/local/etc/php/conf.d/

WORKDIR /var/www/mediawiki
ENTRYPOINT ["/usr/local/bin/mediawiki-entrypoint"]
