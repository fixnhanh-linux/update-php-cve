#!/usr/bin/env bash
# php-eol-check.sh - Kiem tra nhanh trang thai PHP & PHP-FPM.
#
# Tinh chat: CHI DOC (read-only). Khong download, khong cai dat, khong sua file nao.
# Muc dich: giup may chu nhanh biet nhan PHP dang chay co EOL khong, minh mo
#           bao nhieu pool FPM, opcache co load khong, va module CLI giua cac
#           nhan co lech khong, de chuan bi theo playbook README.md.
#
# Cach chay:   bash scripts/php-eol-check.sh    (hoac ./scripts/php-eol-check.sh)
# Exit code:   0 = khong phat hien van de (hoac khong co php trong PATH de kiem tra)
#              1 = co canh bao (nhan EOL/EOL-gan, thieu opcache, module lech...)
#              2 = php ton tai nhung truy van that bai (loi khong xac dinh)
#
# So lieu vong doi ghi nhan thang 10/2026 - LUON kiem chung lai tai:
#   https://www.php.net/supported-versions.php

set -euo pipefail
export LC_ALL=C

readonly PHP_SUPPORTED_URL="https://www.php.net/supported-versions.php"
readonly LEGACY_EXT_RE='^(mcrypt|mhash)$'

warnings=0

bump() { warnings=$((warnings + 1)); }

hr() { printf '%s\n' '------------------------------------------------------------'; }

# Doi ten nhan (dang "8.3") ra trang thai vong doi bang chu khong dau
branch_status() {
  local branch="$1"
  case "$branch" in
    8.0 | 8.1 | 5.* | 7.*) printf 'EOL - khong con ban va, phai nang ngay\n' ;;
    8.2)                   printf 'EOL-GAN - chi con security fix den 31/12/2026\n' ;;
    8.3)                   printf 'dung duoc - security fix den 31/12/2027\n' ;;
    8.4)                   printf 'dung duoc - security fix den 31/12/2028\n' ;;
    8.5)                   printf 'dung duoc - security fix den 31/12/2029\n' ;;
    *)                     printf 'khong ro - tu kiem chung tai %s\n' "$PHP_SUPPORTED_URL" ;;
  esac
}

# Tra ve 0 khi trang thai nhan la ly do bat canh bao
status_needs_warn() {
  local st="$1"
  case "$st" in
    EOL* | "khong ro"*) return 0 ;;
    *) return 1 ;;
  esac
}

show_php_version() {
  hr
  printf '== PHP tren may (CLI) ==\n'
  if ! command -v php >/dev/null 2>&1; then
    printf '[i] khong tim thay php trong PATH - khong co gi de kiem tra, thoat.\n'
    printf '[i] neu day la may chu web nghi ngo da chay PHP-FPM, hay cai php roi chay lai.\n'
    exit 0
  fi
  local line
  line="$(php -v 2>/dev/null | sed -n '1p' || true)"
  if [ -z "$line" ]; then
    printf '[x] lenh "php -v" khong cho ket qua - kiem tra cai dat php CLI roi chay lai.\n'
    exit 2
  fi
  printf 'php CLI dang dung: %s\n' "$line"
  local branch st
  branch="$(printf '%s\n' "$line" | sed -n 's/^PHP \([0-9]*\.[0-9]*\).*/\1/p' || true)"
  if [ -z "$branch" ]; then
    printf '[x] khong doan duoc nhan phien ban tu "php -v" - thoat de tranh sai lech so lieu.\n'
    exit 2
  fi
  st="$(branch_status "$branch")"
  printf 'Nhan: %s - %s\n' "$branch" "$st"
  if status_needs_warn "$st"; then
    bump
  fi
}

list_fpm_pools() {
  hr
  printf '== Cac pool PHP-FPM tren may ==\n'
  local conf branch pname listen st found=0
  for conf in /etc/php/*/fpm/pool.d/*.conf /etc/php-fpm.d/*.conf; do
    [ -e "$conf" ] || continue
    found=1
    branch="$(printf '%s\n' "$conf" | sed -n 's#^/etc/php/\([0-9]*\.[0-9]*\)/.*#\1#p' || true)"
    pname="$(grep -E '^[[:space:]]*\[[^]]+\]' "$conf" 2>/dev/null | head -n 1 | sed 's/[[:space:]]*$//' || true)"
    listen="$(grep -E '^[[:space:]]*listen[[:space:]]*=' "$conf" 2>/dev/null | head -n 1 | sed 's/^[^=]*=[[:space:]]*//;s/[[:space:]]*$//' || true)"
    if [ -n "$branch" ]; then
      printf 'Ubuntu/Debian pool: %s (nhan %s)\n' "$conf" "$branch"
      st="$(branch_status "$branch")"
      if status_needs_warn "$st"; then
        printf '[!] pool nay dang chay tren nhan %s: %s\n' "$branch" "$st"
        bump
      fi
    else
      printf 'RHEL-style pool   : %s\n' "$conf"
    fi
    printf '  pool name : %s\n' "${pname:-?}"
    printf '  listen    : %s\n' "${listen:-?}"
  done
  if [ "$found" -eq 0 ]; then
    printf '(khong thay file pool .conf nao trong /etc/php/*/fpm/pool.d hay /etc/php-fpm.d)\n'
  fi
}

check_opcache() {
  hr
  printf '== OPcache theo tung php CLI ==\n'
  local seen="" cand name mods
  for cand in /usr/bin/php /usr/bin/php[0-9]*; do
    [ -x "$cand" ] || continue
    cand="$(readlink -f "$cand")"
    case " $seen " in
      *" $cand "*) continue ;;
    esac
    seen="$seen $cand"
    name="$(printf '%s\n' "$cand" | sed 's#.*/##')"
    mods="$("$cand" -m 2>/dev/null || true)"
    if printf '%s\n' "$mods" | grep -q 'Zend OPcache'; then
      printf '%s: opcache DAT BAT (module Zend OPcache da load). Chu y: opcache.enable_cli=0 la mac dinh, khong tinh la loi.\n' "$name"
    else
      printf '[!] %s: opcache KHONG CO - khong thay module Zend OPcache trong "php -m". Runtime web se cham that nhieu, can cai goi opcache cho nhan nay.\n' "$name"
      bump
    fi
  done
  if [ -z "$seen" ]; then
    printf '(khong thay binary php CLI nao trong /usr/bin)\n'
  fi
}

# So module cua 1 nhan voi danh sach module goc; canh bao module di san da bi loai
report_modules() {
  local name="$1" mods="$2"
  local missing legacy
  missing="$(comm -23 \
    <(printf '%s\n' "$MODULES_BASE" | LC_ALL=C sort -u) \
    <(printf '%s\n' "$mods"         | LC_ALL=C sort -u) || true)"
  if [ -n "$missing" ]; then
    printf '[!] %s THIEU module so voi php CLI chinh (site chay nhan nay co ra loi "undefined function"):\n' "$name"
    printf '%s\n' "$missing" | sed 's/^/    - /'
    bump
  else
    printf '%s: day du module so voi php CLI chinh.\n' "$name"
  fi
  legacy="$(printf '%s\n' "$mods" | grep -Ei "$LEGACY_EXT_RE" || true)"
  if [ -n "$legacy" ]; then
    printf '[!] %s co module di san: %s - mcrypt/mhash da bi loai boi PHP core tu 7.2, PHP 8.x khong ban va cho chung (dich sang openssl/sodium).\n' "$name" "$legacy"
    bump
  fi
}

compare_modules() {
  hr
  printf '== So sanh module CLI giua cac nhan php ==\n'
  MODULES_BASE="$(php -m 2>/dev/null || true)"
  if [ -z "$MODULES_BASE" ]; then
    printf '(khong doc duoc danh sach module cua php CLI chinh - bo qua buoc so sanh)\n'
    return 0
  fi
  local any=0 p name mods
  for p in /usr/bin/php[0-9]*; do
    [ -x "$p" ] || continue
    name="$(printf '%s\n' "$p" | sed 's#.*/##')"
    mods="$("$p" -m 2>/dev/null || true)"
    if [ -z "$mods" ]; then
      printf '(bo qua %s - khong tra duoc danh sach module)\n' "$name"
      continue
    fi
    any=1
    report_modules "$name" "$mods"
  done
  local legacy_main
  legacy_main="$(printf '%s\n' "$MODULES_BASE" | grep -Ei "$LEGACY_EXT_RE" || true)"
  if [ -n "$legacy_main" ]; then
    printf '[!] php CLI chinh dang co module di san: %s - cac nhan PHP 8.x khong ban va cho chung.\n' "$legacy_main"
    bump
  fi
  if [ "$any" -eq 0 ]; then
    printf '(tren may chi co 1 nhan php CLI - khong co nhan nao khac de so sanh)\n'
  fi
}

summary() {
  hr
  printf '== Tong ket ==\n'
  if [ "$warnings" -gt 0 ]; then
    printf '[!] Co %s canh bao - doc lai cac dong [!] o tren.\n' "$warnings"
    printf '[i] So lieu vong doi ghi nhan thang 10/2026 - xac minh lai tai: %s\n' "$PHP_SUPPORTED_URL"
    exit 1
  fi
  printf 'OK - khong phat hien canh bao nao.\n'
  printf '[i] So lieu vong doi ghi nhan thang 10/2026 - xac minh lai tai: %s\n' "$PHP_SUPPORTED_URL"
  exit 0
}

show_php_version
list_fpm_pools
check_opcache
compare_modules
summary
