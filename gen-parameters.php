<?php
/**
 * Writes PrestaShop's app/config/parameters.php from environment variables.
 *
 * Uses the exact same format as PrestaShop's own installer
 * (sprintf('...return %s;', var_export(...))) so any character in the
 * credentials is safely escaped.
 *
 * Usage: php gen-parameters.php /var/www/html/app/config/parameters.php
 */

$out = $argv[1] ?? '/var/www/html/app/config/parameters.php';

$env = static function (string $name, ?string $default = null): ?string {
    $value = getenv($name);

    return ($value === false || $value === '') ? $default : $value;
};

$parameters = [
    'database_host' => $env('DATABASE_HOST', ''),
    'database_port' => $env('DATABASE_PORT', '3306'),
    'database_name' => $env('DATABASE_NAME', ''),
    'database_user' => $env('DATABASE_USER', ''),
    'database_password' => $env('DATABASE_PASSWORD', ''),
    'database_prefix' => $env('DATABASE_PREFIX', 'ps_'),
    'database_engine' => 'InnoDB',

    // Fixed cryptographic keys. Render Free wipes the disk on every
    // spin-down, so these values must be deterministic or all sessions
    // (and legacy password salts) would change on each restart.
    // They can be overridden with the PS_* environment variables below.
    'cookie_key' => $env('PS_COOKIE_KEY', 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),
    'cookie_iv' => $env('PS_COOKIE_IV', '12345678'),
    'new_cookie_key' => $env('PS_NEW_COOKIE_KEY', 'def00000b84c5c2f9a38805b977fbca600b399299f7e4093c7d183eafc2b4f1292fd46835f079f1e280d603a8a6c14adbe1dad8b8165ad8026dc18485e77e0bea04324de'),
    'secret' => $env('PS_SECRET', 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),

    'ps_caching' => 'CacheMemcache',
    'ps_cache_enable' => false,
    'ps_creation_date' => '2026-10-08',
    'locale' => 'en-US',
    'use_debug_mode' => false,
    'mailer_transport' => 'smtp',
    'mailer_host' => '127.0.0.1',
    'mailer_user' => null,
    'mailer_password' => null,
    'api_public_key' => null,
    'api_private_key' => null,
];

$content = sprintf('<?php return %s;', var_export(['parameters' => $parameters], true));

if (file_put_contents($out, $content) === false) {
    fwrite(STDERR, "[gen-parameters] cannot write {$out}\n");
    exit(1);
}

echo "[gen-parameters] wrote {$out}\n";
