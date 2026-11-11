#!/bin/bash
# PrestaShop boot script for Render Free (ephemeral filesystem).
# Everything that must survive a spin-down is regenerated here from
# environment variables, because Render wipes the disk on every
# redeploy, restart and idle spin-down.
set -e

# ---------------------------------------------------------------------------
# 1. Force HTTPS detection behind Render's TLS-terminating proxy
# ---------------------------------------------------------------------------
cat > /var/www/html/config/defines_custom.inc.php <<'EOF'
<?php
$_SERVER["HTTPS"] = "on";
$_SERVER["SERVER_PORT"] = 443;
define("_PS_MODE_DEV_", false);
EOF

# ---------------------------------------------------------------------------
# 2. (Re)generate app/config/parameters.php from the DATABASE_* env vars
# ---------------------------------------------------------------------------
if [ -n "${DATABASE_HOST:-}" ]; then
    php /usr/local/bin/gen-parameters.php /var/www/html/app/config/parameters.php
fi

# ---------------------------------------------------------------------------
# 3. Install state detection + Back Office security gate
#
#    Two PrestaShop mechanisms matter here:
#
#    a) The Back Office login page refuses entry while the /install folder
#       exists on disk (security gate: "deleted the /install folder").
#    b) The installer itself refuses to start (HTTP 409 "already installed")
#       when app/config/parameters.php exists but the lock file
#       var/.install.prestashop does NOT exist.
#
#    The database is the source of truth: an employee row means "installed".
#    - installed                        -> DELETE /install (and the leftover
#                                          original /admin copy, keeping only
#                                          /admin-panel) so the BO unlocks
#    - not installed, PS_INSTALL_MODE=1 -> keep /install, remove its lock
#    - not installed, PS_INSTALL_MODE=0 -> keep /install locked
#
#    Deletion happens only at runtime, so a future re-install always remains
#    possible: the folders come back from the image on the next deploy as
#    long as the database has no employee row.
# ---------------------------------------------------------------------------
SHOP_INSTALLED=0
if [ -n "${DATABASE_HOST:-}" ] && MYSQL_PWD="${DATABASE_PASSWORD:-}" mysql --connect-timeout=5 \
    -h "$DATABASE_HOST" -P "${DATABASE_PORT:-3306}" \
    -u "${DATABASE_USER:-root}" "${DATABASE_NAME}" -N \
    -e "SELECT 1 FROM ${DATABASE_PREFIX:-ps_}employee LIMIT 1" >/dev/null 2>&1
then
    SHOP_INSTALLED=1
fi

mkdir -p /var/www/html/var

if [ "$SHOP_INSTALLED" = "1" ]; then
    echo "[run-app] shop installed -> removing /install and original /admin (BO security gate)"
    rm -rf /var/www/html/install /var/www/html/install-dev \
        /var/www/html/admin /var/www/html/admin-dev
    rm -f /var/www/html/var/.install.prestashop
elif [ "${PS_INSTALL_MODE:-0}" = "1" ]; then
    echo "[run-app] shop not installed yet -> unlocking /install"
    touch /var/www/html/var/.install.prestashop
else
    echo "[run-app] shop not installed and PS_INSTALL_MODE=0 -> /install stays locked"
    rm -f /var/www/html/var/.install.prestashop
fi

# ---------------------------------------------------------------------------
# 4. Fresh cache/logs on every boot, correct ownership
# ---------------------------------------------------------------------------
rm -rf /var/www/html/var/cache/* /var/www/html/var/logs/* 2>/dev/null || true
mkdir -p /var/www/html/var/cache /var/www/html/var/logs
chown -R www-data:www-data \
    /var/www/html/var \
    /var/www/html/app/config \
    /var/www/html/config \
    /var/www/html/admin-panel
chmod -R 777 /var/www/html/var/cache /var/www/html/var/logs

exec apache2-foreground
