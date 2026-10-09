#!/bin/bash
set -e

# Write database parameters
cat << 'EOF' > /var/www/html/app/config/parameters.php
<?php return array (
  'parameters' => 
  array (
    'database_host' => 'switchback.proxy.rlwy.net:52550',
    'database_port' => '',
    'database_name' => 'railway',
    'database_user' => 'root',
    'database_password' => 'rvVFnMlGzMFoVFPMlAWvuoUjwqFOEQum',
    'database_prefix' => 'ps_',
    'database_engine' => 'InnoDB',
    'cookie_key' => 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    'cookie_iv' => '12345678',
    'ps_caching' => 'CacheMemcache',
    'ps_cache_enable' => false,
    'ps_creation_date' => '2026-10-08',
    'locale' => 'en-US',
    'use_debug_mode' => false,
  ),
);
EOF

# Ensure PHP recognizes Render's SSL termination
echo '<?php if (isset($_SERVER["HTTP_X_FORWARDED_PROTO"]) && $_SERVER["HTTP_X_FORWARDED_PROTO"] === "https") { $_SERVER["HTTPS"] = "on"; $_SERVER["SERVER_PORT"] = 443; }' > /var/www/html/config/defines_custom.inc.php

# Clear any cached routes and redirects
rm -rf /var/www/html/var/cache/prod/* /var/www/html/var/cache/dev/*

chown -R www-data:www-data /var/www/html/app/config/parameters.php /var/www/html/config/defines_custom.inc.php

exec apache2-foreground
