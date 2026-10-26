# PHP Patch & Upgrade — Quick Reference

One-page cheat sheet for **nginx + PHP-FPM** servers. Full Vietnamese playbook: [../README.md](../README.md).

## PHP support (snapshot: Oct 2026)

Always re-check the official page: <https://www.php.net/supported-versions.php>

| Branch | Status | Security fixes until | Latest release noted |
|---|---|---|---|
| ≤ 8.1 | **EOL** | past | no more patches |
| 8.2 | active, nearing EOL | 2026-12-31 | security fixes only |
| 8.3 | supported (recommended default) | 2027-12-31 | ~8.3.33 |
| 8.4 | supported, active | 2028-12-31 | ~8.4.25 |
| 8.5 | supported, active | 2029-12-31 | ~8.5.10 |

Rule of thumb: target **8.3** for a normal site (lowest-risk path from 8.1/8.2); pick **8.4** when the codebase is clean and you want a longer runway.

Check what the server runs:

```bash
php -v
bash ../scripts/php-eol-check.sh   # read-only; exit 0 ok / 1 warnings / 2 error
```

## Same-branch security patch (~5 min, no nginx edits)

Ubuntu/Debian:

```bash
sudo apt update && sudo apt install --only-upgrade 'php*'
sudo php-fpm8.3 -t && sudo systemctl restart php8.3-fpm
sudo nginx -t && sudo systemctl reload nginx
```

RHEL/Rocky/Alma:

```bash
sudo dnf update 'php*' -y
sudo php-fpm -t && sudo systemctl restart php-fpm
sudo nginx -t && sudo systemctl reload nginx
```

Cross-branch upgrades do NOT use this shortcut — use the blue-green flow below.

## Installing a new branch

Ubuntu/Debian (ondrej/php):

```bash
sudo add-apt-repository ppa:ondrej/php -y && sudo apt update
sudo apt install php8.3-fpm php8.3-cli php8.3-mysql php8.3-curl \
  php8.3-mbstring php8.3-xml php8.3-gd php8.3-zip php8.3-bcmath \
  php8.3-intl php8.3-opcache
sudo php-fpm8.3 -t && sudo systemctl enable --now php8.3-fpm
```

RHEL/Rocky/Alma (Remi):

```bash
sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-9.rpm
sudo dnf module reset php -y
sudo dnf module enable php:remi-8.3 -y
sudo dnf update 'php*' -y
sudo php-fpm -t && sudo systemctl enable --now php-fpm
```

## Blue-green branch upgrade (8.1/8.2 → 8.3)

1. Install the new branch — do NOT touch nginx yet (zero downtime).
2. Copy the pool config to the new branch; temporarily lower `pm.max_children` (two pools share RAM).
3. `php-fpm8.3 -t` then `systemctl enable --now php8.3-fpm`.
4. Point `fastcgi_pass` to the new socket, keep the old line commented as instant rollback.
5. `nginx -t` then `systemctl reload nginx` (reload, never restart).
6. Run both pools in parallel for 24–48 h; watch nginx error log, PHP error log, `pm.status`.
7. Rollback on failure: switch `fastcgi_pass` back, reload — ~30 seconds.
8. After a stable window: remove the old branch (`apt remove 'php8.1-*'` / dnf module reset) and restore `pm.max_children`.

## Module drift check (per branch)

```bash
diff <(php8.1 -m | sort -u) <(php8.3 -m | sort -u)
```

Install missing siblings (`apt install php8.3-<module>`); `mcrypt`/`mhash` have no 8.x replacement — migrate to `openssl`/`sodium`.

## Pre-upgrade code checks

```bash
vendor/bin/phpcs -p --standard=PHPCompatibility \
  --runtime-set testVersion 8.3 --extensions=php /var/www/site
find /var/www/site -name '*.php' -print0 | xargs -0 -n1 php8.3 -l
wp core check-update && wp core verify-checksums
```

Laravel: `composer install`, `php artisan migrate --pretend`, `php artisan test`.

## Common 8.0/8.1 → 8.3 breakages

| Symptom | Since | Fix |
|---|---|---|
| `Creation of dynamic property ... is deprecated` | 8.2 | declare properties; or `#[\AllowDynamicProperties]` |
| `Passing null to parameter ... deprecated` | 8.1 | guard with `$x ?? ''` |
| `utf8_encode()` / `utf8_decode()` deprecated | 8.2 | `mb_convert_encoding()` |
| float → int implicit conversion warning | 8.1 | explicit `(int)` after `round()` |
| read-only `$GLOBALS` write failure | 8.1 | `global $x; $x = ...;` |
| `Call to undefined function mcrypt_*` | all 8.x | use `openssl_encrypt` / sodium |

## Rollback cheat list

| Goal | Debian/Ubuntu | RHEL/Rocky/Alma |
|---|---|---|
| Point nginx back to the old pool | edit `fastcgi_pass` → old socket, `nginx -t`, reload | point to old pool socket, reload |
| Freeze auto-installs | `apt-mark hold 'php8.*'` | `exclude=php*` in `/etc/dnf/dnf.conf` |
| Block new branches via pin | `/etc/apt/preferences.d/php-hold` with `Pin-Priority: -1` | `dnf module disable php:remi-8.4 php:remi-8.5` |
| Remove the parallel new pool | `apt remove 'php8.3-*' && apt autoremove` | `dnf module reset php -y` |
| Move back to the old stream | n/a | `dnf module reset php && dnf module enable php:remi-8.2 && dnf distro-sync 'php*'` |
| Downgrade a package version | `apt install php8.3-fpm=<version>` | `dnf downgrade 'php*'` |

## Automated updates (patch in-branch only, never auto-add a branch)

`unattended-upgrades`: allow the running branch's origin, blacklist `php8.4-`/`php8.5-`.

`dnf-automatic`: `apply_updates = yes` plus `exclude=php8.4*,php8.5*` in `/etc/dnf/dnf.conf`.

Weekly CVE watcher: `apt list --upgradable | grep -i '^php'` or `dnf updateinfo list available security | grep -i php`, pipe into your alerting channel.

## Golden rule

**Test before every reload — never rush.** All three must pass or you do NOT reload:

```bash
sudo php-fpm8.3 -t        # pool syntax
sudo nginx -t             # nginx config syntax
find /var/www/site -name '*.php' -print0 | xargs -0 -n1 php8.3 -l   # full lint
```

Also: backup `/etc/php` and `/etc/nginx` before each upgrade round; reload instead of restart; test on staging first; on failure, roll back first and diagnose second.
