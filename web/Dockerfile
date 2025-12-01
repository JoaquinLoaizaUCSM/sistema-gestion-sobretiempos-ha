# Minimal PHP + Apache with MySQL extensions
FROM php:8.2-apache

# Install curl for healthcheck and MySQL extensions (pdo_mysql, mysqli)
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo_mysql mysqli \
    && a2enmod rewrite

# Copy app
COPY src/ /var/www/html/

# Healthcheck (optional): just check Apache responds
HEALTHCHECK --interval=10s --timeout=3s --retries=10 CMD curl -fsS http://localhost/ || exit 1
