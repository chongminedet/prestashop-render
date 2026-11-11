# PrestaShop Cloud Deployment

A decoupled, **100% free-tier** PrestaShop 8 deployment: the web tier runs on
Render (Free plan) and the MySQL-compatible database runs on a separate,
independently hosted server.

## Architecture

```
Browser ──HTTPS──▶ Render edge (TLS termination)
                      │
                      ▼
            PrestaShop 8 (Apache + PHP 8.2)      ← prestashop/prestashop:8-apache
            Docker image built from /Docker
                      │  plain TCP :3306
                      ▼
            MariaDB (managed, separate host)     ← never runs on the web instance
```

| Tier    | Provider    | Plan | Notes                                        |
|---------|-------------|------|----------------------------------------------|
| Web     | Render      | Free | 0.1 vCPU / 512 MB, spins down after 15 min idle, **ephemeral disk** |
| Database| alwaysdata  | Free | MariaDB, 1 GB SSD, ports open to the internet, daily backups |

Because Render's free plan **wipes the disk on every redeploy, restart and
idle spin-down**, all configuration is regenerated at boot from environment
variables (`run-app.sh` → `gen-parameters.php`).

## Repository layout

| File                | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| `Docker`            | Dockerfile (Render's Dockerfile path is set to this file)      |
| `run-app.sh`        | Boot script: writes config, manages installer lock, starts Apache |
| `gen-parameters.php`| Writes `app/config/parameters.php` from `DATABASE_*` env vars  |
| `landing.html`      | Companion static page hosted on the database provider's free hosting |

## Environment variables (Render → Environment)

| Variable            | Required | Default | Description                                   |
|---------------------|----------|---------|-----------------------------------------------|
| `DATABASE_HOST`     | yes      | —       | e.g. `mysql-<account>.alwaysdata.net`         |
| `DATABASE_PORT`     | no       | `3306`  |                                               |
| `DATABASE_NAME`     | yes      | —       |                                               |
| `DATABASE_USER`     | yes      | —       |                                               |
| `DATABASE_PASSWORD` | yes      | —       |                                               |
| `DATABASE_PREFIX`   | no       | `ps_`   |                                               |
| `PS_INSTALL_MODE`   | during setup | `0` | `1` = keep `/install` unlocked until the shop has an admin account in the database; set back to `0` afterwards |
| `PS_ADMIN_RESET_PASSWORD` | recovery only | *(unset)* | While set, every boot resets the first Back Office employee's password to this value (no mail server exists for the "forgot password" e-mail). **Log in, then delete it.** |

Cryptographic keys (`cookie_key`, `secret`, …) are deterministic by default
so that sessions and password hashes stay valid across the disk wipes that
the free plan performs. They can be overridden with `PS_COOKIE_KEY`,
`PS_COOKIE_IV`, `PS_NEW_COOKIE_KEY`, `PS_SECRET`.

## First-time installation

1. Provision the external database (see runbook) and fill in the `DATABASE_*`
   variables in Render's Environment tab; set `PS_INSTALL_MODE=1`.
2. Open `https://prestashop-render.onrender.com/install/` and complete the
   web installer (the database form is pre-filled from the environment).
3. After installation succeeds, set `PS_INSTALL_MODE=0` — the installer
   lock is additionally enforced automatically once an admin account exists
   in the database.

## Security notes

- No credentials are baked into the image; they come from Render env vars.
- `/install` returns HTTP 409 once the shop is installed (PrestaShop's own
  installation-state check + the `var/.install.prestashop` lock).
- The Back Office lives at `/admin-panel` (not the default `/admin`).
