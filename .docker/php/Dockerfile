FROM php:8.3-fpm-alpine

ARG UID=1000
ARG GID=1000
ENV UID=${UID}
ENV GID=${GID}

# Устанавливаем системные зависимости
RUN apk add --no-cache \
    git \
    curl \
    openssl \
    wget \
    unzip \
    zip \
    bash \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    libwebp-dev \
    freetype-dev \
    libxml2-dev \
    icu-dev \
    gmp-dev \
    oniguruma-dev \
    libmemcached-dev \
    imagemagick \
    imagemagick-libs \
    imagemagick-dev \
    zlib-dev \
    libevent-dev \
    shadow

# Устанавливаем инструменты сборки
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    build-base \
    pkgconfig \
    libtool \
    linux-headers

# Устанавливаем расширения PHP через docker-php-ext-install
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install \
    mysqli \
    gd \
    gmp \
    xml \
    intl \
    mbstring \
    bcmath \
    opcache \
    zip \
    calendar \
    bz2 \
    ftp

# Устанавливаем PECL расширения по одному
# RUN pecl install redis && docker-php-ext-enable redis

#RUN pecl install memcached && docker-php-ext-enable memcached

RUN pecl install imagick && docker-php-ext-enable imagick
# Устанавливаем Xdebug с явным указанием версии для совместимости
RUN pecl install xdebug-3.4.1 && docker-php-ext-enable xdebug

# Удаляем инструменты сборки после установки
RUN apk del .build-deps && \
    rm -rf /tmp/pear && \
    rm -rf /var/cache/apk/*

# Создаем директории и настраиваем права
RUN mkdir -p /var/www/src /var/log/php /tmp/php

# Устанавливаем Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Копируем конфигурационные файлы PHP-FPM
COPY conf/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY conf/www.conf /usr/local/etc/php-fpm.d/www.conf
COPY conf/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY conf/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Настраиваем рабочую директорию
WORKDIR /var/www/src

# Изменяем UID/GID пользователя www-data (теперь команды доступны)
RUN usermod -u $UID www-data && groupmod -g $GID www-data

# Health check для PHP-FPM
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD php -r "if (fsockopen('127.0.0.1', 9000)) exit(0); exit(1);"

EXPOSE 9000

# Запускаем PHP-FPM
CMD ["php-fpm", "-F", "-R"]
