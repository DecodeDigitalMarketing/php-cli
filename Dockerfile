FROM php:7.3-stretch

ARG TIMEZONE=UTC
ARG PHP_INI_DIR=/usr/local/etc/php/conf.d

ENV PATH="/app/vendor/bin:${PATH}"

# Install runtime packages
RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
    openssh-client \
    unzip \
    zip \
		libnss-wrapper \
		mariadb-client \
	;

# install the PHP extensions we need
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libzip-dev \
		libbz2-dev \
		libjpeg-dev \
		libpng-dev \
		libicu-dev \
    libzip-dev \
	; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-install gd pdo pdo_mysql opcache zip bz2 intl; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# Set timezone
RUN ln -snf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && echo ${TIMEZONE} > /etc/timezone \
  && printf '[PHP]\ndate.timezone = "%s"\n', ${TIMEZONE} > ${PHP_INI_DIR}/drush-timezone.ini \
	&& printf 'memory_limit=-1\n\' > ${PHP_INI_DIR}/drush-general.ini \
	&& "date"

COPY run_as_user /usr/local/bin/
COPY ssh /usr/local/sbin/

RUN chmod a+x /usr/local/bin/run_as_user; \
	chmod a+x /usr/local/sbin/ssh

WORKDIR /app

