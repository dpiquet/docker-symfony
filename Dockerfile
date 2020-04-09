FROM node:13.8 as node

FROM php:7.4-apache

# Copy nodejs from node image
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /opt /opt
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/bin /usr/local/bin

# Custom Vhost
ADD 000-default.conf /etc/apache2/sites-available/000-default.conf

RUN set -xe \
    #
    # Install PHP dependencies
    #
    && apt-get update \
    && apt-get install -y git subversion openssh-client coreutils unzip libpq-dev nano \
    && apt-get install -y autoconf build-essential libpq-dev binutils-gold libgcc1 linux-headers-amd64 make python libpng-dev libjpeg-dev libc-dev libfreetype6-dev libmcrypt-dev libicu-dev sqlite3-pcre libxml2-dev libonig-dev libzip-dev imagemagick libtool libmagickwand-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    #
    # Install Xdebug and Imagick
    #
    && pecl install xdebug \
    && pecl list-files xdebug |grep src |cut -d ' ' -f 3 > /usr/local/etc/php/conf.d/xdebug.ini \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    #
    # PHP Configuration
    #
    && docker-php-ext-install -j$(nproc) iconv mbstring intl pdo_pgsql pdo_mysql gd zip bcmath soap sockets opcache \
    # Disable opcache by default
    && sed -r 's/^(.{1,})/#\1/' < /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini > /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini.new \
    && mv /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini.new /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini \
    # Cleanup
    && docker-php-source delete \
    && echo "Installing composer" \
    #
    # Install composer
    #
    && php -r "readfile('https://getcomposer.org/installer');" | php -- --install-dir=/usr/local/bin --filename=composer \
    && chmod +x /usr/local/bin/composer \
    #
    # Install webpack-encore
    #
    && npm install -g @symfony/webpack-encore \
    #
    # Enable httpd mod_rewrite, mod_headers, mod_expires
    #
    && a2enmod rewrite headers expires\
    #
    # Build dependencies cleanup
    #
    && apt-get remove -y autoconf gcc g++ libpq-dev linux-headers-amd64 make libmcrypt-dev libicu-dev libpq-dev libxml2-dev build-essential \
    && apt-get clean

EXPOSE 80

# Labelling strategy on child containers build
ONBUILD ARG FORLABS_IMAGE_CONTEXT='production'
ONBUILD LABEL fr.forlabs.image_context="${FORLABS_IMAGE_CONTEXT}"
