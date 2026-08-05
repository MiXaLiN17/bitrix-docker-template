ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-fpm-alpine

ARG UID=1000
ARG GID=1000
ENV UID=${UID}
ENV GID=${GID}

# Устанавливаем зависимости, расширения PHP и очищаем за собой в одном слое.
# Первым блоком — то, что нужно в рантайме, вторым — заголовки для сборки расширений:
# они попадают во временный пакет .build-deps и удаляются сразу после компиляции,
# иначе десяток -dev пакетов остаётся в готовом образе мёртвым грузом.
RUN apk update \
    && apk add \
        git curl openssl wget unzip zip bash shadow \
        imagemagick imagemagick-libs \
        libzip libpng libjpeg-turbo libwebp freetype \
        libxml2 icu-libs gmp oniguruma libbz2 \
        libmemcached-libs libsasl \
    && apk add --virtual .build-deps \
        autoconf build-base pkgconfig libtool linux-headers openssl-dev \
        libzip-dev libpng-dev libjpeg-turbo-dev libwebp-dev freetype-dev \
        libxml2-dev icu-dev gmp-dev oniguruma-dev bzip2-dev \
        imagemagick-dev zlib-dev libmemcached-dev cyrus-sasl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install \
        mysqli gd gmp xml intl mbstring bcmath opcache zip calendar bz2 ftp \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    # Движок кеша Битрикс берёт из 'type' в bitrix/.settings.php: CacheEngineMemcache
    # требует расширение memcache, CacheEngineMemcached — memcached. Это разные расширения,
    # ставим оба, чтобы настройки, переехавшие с прода, заводились без правок: без нужного
    # расширения ядро падает с NotSupportedException ещё до подключения к серверу кеша.
    && pecl install memcache-8.2 \
    && docker-php-ext-enable memcache \
    # У memcached интерактивный configure (libmemcached, sasl, igbinary, json, msgpack) —
    # пустые строки принимают значения по умолчанию
    && printf '\n\n\n\n\n\n' | pecl install memcached-3.4.0 \
    && docker-php-ext-enable memcached \
    && pecl install xdebug-3.4.1 \
    && docker-php-ext-enable xdebug \
    && apk del .build-deps \
    && rm -rf /tmp/pear /var/cache/apk/* \
    && mkdir -p /var/www/src /var/log/php /tmp/php

# Устанавливаем Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Копируем конфигурационные файлы PHP-FPM
COPY conf/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY conf/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY conf/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY conf/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Настраиваем рабочую директорию
WORKDIR /var/www/src

# Изменяем UID/GID пользователя www-data
RUN usermod -u $UID www-data && groupmod -g $GID www-data

# Health check для PHP-FPM
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php -r "if (fsockopen('127.0.0.1', 9000)) exit(0); exit(1);"

EXPOSE 9000

# Запускаем PHP-FPM
CMD ["php-fpm", "-F", "-R"]
