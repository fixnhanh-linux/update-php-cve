# update-php-cve

[![PHP](https://img.shields.io/badge/PHP-8.3%20%7C%208.4-8892BF?logo=php&logoColor=white)](https://www.php.net/supported-versions.php)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](https://github.com/fixnhanh-linux/update-php-cve/pulls)
[![Vietnamese](https://img.shields.io/badge/ng%C3%B4n%20ng%E1%BB%AF-Ti%E1%BA%BFng%20Vi%E1%BB%87t-blue)](README.md)

Playbook thực chiến để làm hai việc liên quan đến **lỗ hổng PHP** mà không làm sập site:

1. **Vá bảo mật trong cùng nhánh** (8.3.x → 8.3.y) khi có CVE mới — rủi ro thấp, làm được ngay trong giờ hành chính.
2. **Nâng nhánh chính** (8.1/8.2 → 8.3) khi nhánh cũ đã EOL hoặc sắp hết hỗ trợ — rủi ro cao hơn, cần hai pool chạy song song và có đường rollback.

Repo có **chương khẩn cấp riêng cho PHP2Shell** (CVE-2026-109618 / CVE-2026-109619, CVSS 9.2, RCE không xác thực) — xem [chương 2](#2-khẩn-cấp-php2shell--cve-2026-109618-và-cve-2026-109619).

Viết cho **Nginx + PHP-FPM**, dùng được cho cả hai họ hệ điều hành:

- **Ubuntu / Debian**: `apt` + `ppa:ondrej/php`
- **RHEL / Rocky / Alma** (và CentOS Stream): `dnf` + repo Remi

Giả định: bạn có `sudo`, web app nằm ở `/var/www/<site>`, nginx trỏ tới PHP-FPM qua unix socket.

> [!CAUTION]
> **PHP2Shell — CVE-2026-109618 và CVE-2026-109619 — đang bị khai thác thực tế.**
> Bản vá: **8.2.35, 8.3.36, 8.4.27, 8.5.12** (phát hành 21/10/2026). Hãy vá ngay;
> mã ứng dụng sạch không bảo vệ được vì lỗi nằm trong core PHP. Chi tiết và cách
> kiểm tra dấu vết: [chương 2](#2-khẩn-cấp-php2shell--cve-2026-109618-và-cve-2026-109619).

> [!WARNING]
> **PHP 8.2 hết hỗ trợ bảo mật ngày 31/12/2026.** Nếu server còn chạy 8.2, hãy dùng
> playbook này để lên 8.3 (hoặc 8.4) trước mốc đó. PHP 8.1 trở xuống đã EOL —
> không còn bản vá nào, kể cả khi bạn thấy package vẫn cài được.

**English:** [one-page cheat sheet](docs/quick-reference-en.md)

## Mục lục

- [1. Vòng đời PHP: 8.1 đã EOL, 8.2 sắp hết hỗ trợ](#1-vòng-đời-php-81-đã-eol-82-sắp-hết-hỗ-trợ)
- [2. KHẨN CẤP: PHP2Shell — CVE-2026-109618 và CVE-2026-109619](#2-khẩn-cấp-php2shell--cve-2026-109618-và-cve-2026-109619)
- [3. TL;DR: vá bảo mật trong cùng nhánh mất 5 phút](#3-tldr-vá-bảo-mật-trong-cùng-nhánh-mất-5-phút)
- [4. Ubuntu/Debian: apt và ppa:ondrej/php](#4-ubuntudebian-apt-và-ppaondrejphp)
- [5. RHEL/Rocky/Alma: dnf và repo Remi](#5-rhelrockyalma-dnf-và-repo-remi)
- [6. Nâng nhánh 8.1/8.2 lên 8.3 theo kiểu blue-green](#6-nâng-nhánh-8182-lên-83-theo-kiểu-blue-green)
- [7. Kiểm tra mã nguồn trước khi nâng nhánh](#7-kiểm-tra-mã-nguồn-trước-khi-nâng-nhánh)
- [8. Lỗi hay gặp khi nâng 8.0/8.1 lên 8.3](#8-lỗi-hay-gặp-khi-nâng-8081-lên-83)
- [9. Rollback: bảng lệnh đầy đủ](#9-rollback-bảng-lệnh-đầy-đủ)
- [10. Tự động hoá cập nhật bảo mật](#10-tự-động-hoá-cập-nhật-bảo-mật)
- [11. Case study: WordPress 8.1 lên 8.3 trong 25 phút](#11-case-study-wordpress-81-lên-83-trong-25-phút)
- [12. FAQ](#12-faq)
- [13. Thuật ngữ](#13-thuật-ngữ)
- [14. Quy tắc vàng trước mỗi lần reload](#14-quy-tắc-vàng-trước-mỗi-lần-reload)
- [15. Cấu trúc repo, đóng góp và License](#15-cấu-trúc-repo-đóng-góp-và-license)

---

## 1. Vòng đời PHP: 8.1 đã EOL, 8.2 sắp hết hỗ trợ

Số liệu chụp tại thời điểm **tháng 10/2026**. Bảng chính thức luôn nằm ở
<https://www.php.net/supported-versions.php> — trước khi hành động, mở lại một lần.

| Nhánh | Trạng thái (10/2026) | Security fix đến | Bản vá mới nhất ghi nhận | Hành động |
|---|---|---|---|---|
| ≤ 8.1 (8.0, 7.x, 5.x) | **EOL** — không còn bản vá | đã hết | không có | Nâng bắt buộc, càng sớm càng tốt |
| 8.2 | Còn bảo mật nhưng **EOL rất gần** | 31/12/2026 | 8.2.35 | Lên 8.3 trong 1–2 tháng tới |
| 8.3 | Ổn định — nhận security fix | 31/12/2027 | 8.3.36 | **Khuyến nghị mặc định** |
| 8.4 | Đang active | 31/12/2028 | 8.4.27 | Khi code đã sạch deprecation |
| 8.5 | Đang active | 31/12/2029 | 8.5.12 | Khi toàn bộ tooling đã hỗ trợ |

Các bản trên đều đã bao gồm fix PHP2Shell (21/10/2026). Nếu server thấp hơn các mốc
`8.2.35` / `8.3.36` / `8.4.27` / `8.5.12`, coi như đang bị lỗ hổng RCE nghiêm trọng —
xử lý theo [chương 2](#2-khẩn-cấp-php2shell--cve-2026-109618-và-cve-2026-109619) trước.

Khuyến nghị:

- **Site bình thường nhắm 8.3** — đường nâng từ 8.1/8.2 lên 8.3 ít thay đổi nhất mà vẫn được bảo mật thêm một năm.
- **8.4** khi code đã qua kiểm tra deprecation và bạn muốn thêm một năm hỗ trợ.
- **8.5** chỉ dùng khi plugin/theme/thư viện bạn phụ thuộc đã công bố hỗ trợ.

Xem nhanh nhánh đang chạy:

```bash
php -v
```

Hoặc chạy script read-only kèm repo (exit code ghi trong header script):

```bash
bash scripts/php-eol-check.sh
```

Script chỉ **đọc** — không cài, không sửa file, không restart gì. Nó đối chiếu nhánh CLI, liệt kê pool FPM, kiểm tra opcache và so sánh module giữa các nhánh.

---

## 2. KHẨN CẤP: PHP2Shell — CVE-2026-109618 và CVE-2026-109619

> [!CAUTION]
> **Ngày 21/10/2026, PHP phát hành bản vá cho hai lỗ hổng RCE không cần xác thực,
> CVSS v4.0 9.2.** Đã ghi nhận khai thác thực tế trước và ngay sau ngày công bố.
> Nếu server phục vụ web bằng PHP, hãy **vá trước khi đọc tiếp**: `8.2.35`,
> `8.3.36`, `8.4.27`, `8.5.12`. Đây không phải lỗi ứng dụng — mã WordPress/Laravel
> sạch vẫn dính, vì lỗi nằm trong core và xảy ra **trước khi code ứng dụng chạy**.

### 2.1. Hai lỗ hổng, hai cơ chế

| CVE | Cơ chế | Hệ quả |
|---|---|---|
| **CVE-2026-109618** | Xử lý **hết bộ nhớ (OOM)** làm gián đoạn PHP khi dữ liệu request nội bộ mới khởi tạo một phần; bước dọn dẹp coi dữ liệu không hợp lệ là hợp lệ (GHSA-w8hw-w9fx-j79w) | RCE không xác thực; có thể lộ bộ nhớ worker (mật khẩu, token, API key) |
| **CVE-2026-109619** | **Trạng thái toàn cục cũ** sống sót sau khi vùng nhớ đã được giải phóng; request sau do cùng worker xử lý đọc phải trạng thái cũ trước khi quá trình khởi tạo bình thường ghi đè (GHSA-6wmf-4rv5-p3rp) | RCE không xác thực, use-after-free trên heap, lộ bộ nhớ |

- Mức độ: **CVSS v4.0 9.2** (critical) cho cả hai.
- Phạm vi: mọi cài đặt PHP **phục vụ request web** — PHP-FPM, Apache `mod_php` (rủi ro cao nhất, đã có exploit chứng minh), `php-cgi`, FrankenPHP, LiteSpeed.
- Nhánh bị ảnh hưởng: 5.4 → 8.5 (theo công bố); bản vá chỉ có cho các nhánh còn được hỗ trợ.
- Ứng dụng không thể tự phòng: lỗi xảy ra trong runtime trước khi application code chạy; auth của app không chặn được.

### 2.2. Kiểm tra phiên bản trong 10 giây

```bash
php -v
php-fpm8.3 -v 2>/dev/null || true

# quét mọi binary PHP có trên máy
for b in php php8.2 php8.3 php8.4 php8.5; do
  command -v "$b" >/dev/null 2>&1 && "$b" -r 'echo PHP_BINARY, " ", PHP_VERSION, PHP_EOL;'
done
```

| Nhánh | Bản vá tối thiểu | Nếu thấp hơn |
|---|---|---|
| 8.5 | **8.5.12** | Dính CVE-2026-109618 và CVE-2026-109619 |
| 8.4 | **8.4.27** | Dính |
| 8.3 | **8.3.36** | Dính |
| 8.2 | **8.2.35** | Dính |
| ≤ 8.1 | không có bản vá upstream | Chỉ còn backport của distro/LTS hoặc source-backport; tốt nhất nâng nhánh |

Bản `8.6.0 RC4` cũng đã có fix nhưng **không dùng cho production**.

### 2.3. Vá

Ubuntu/Debian (PPA ondrej/php hoặc repo của distro):

```bash
sudo apt update
apt policy php8.3-fpm | sed -n '1,6p'      # xác nhận ứng viên >= 8.3.36
sudo apt install --only-upgrade 'php8.3-*'
sudo systemctl restart php8.3-fpm
```

RHEL/Rocky/Alma (Remi):

```bash
sudo dnf update 'php*' -y
sudo systemctl restart php-fpm
```

Sau khi nâng, **restart toàn bộ worker**, không chỉ FPM:

- `systemctl restart php8.3-fpm` (hoặc `php-fpm` trên RHEL).
- Apache: restart `httpd`/`apache2` nếu dùng `mod_php`.
- FrankenPHP / LiteSpeed: restart service tương ứng.
- **Queue worker / daemon CLI** (Laravel Horizon, `queue:work`, cron chạy dài): restart để xóa trạng thái cũ trong tiến trình.
- Nếu chạy container: rollout lại toàn bộ replica, đừng chỉ `restart` một container.

> [!IMPORTANT]
> CVE-2026-109619 là lỗi **trạng thái tồn dư theo tiến trình**. Tiến trình cũ chưa được
> restart vẫn có thể mang trạng thái độc hại sau khi bạn đã cài bản vá. Vá package mà
> không restart worker = chưa vá.

Kiểm tra lại:

```bash
php -v | head -1
systemctl show php8.3-fpm -p ActiveEnterTimestamp
curl -sI https://example.com | head -1     # site vẫn phục vụ
```

### 2.4. Nếu chưa vá được ngay: giảm thiểu tạm thời

> [!WARNING]
> Không có biện pháp giảm thiểu nào thay thế bản vá. Các cấu hình dưới đây chỉ chặn
> **một số đường tấn công đã biết**, và phải được đặt ở tầng áp dụng **trước khi parse
> request** (`php.ini`, pool `php_admin_value`, config Apache) — `ini_set()` và
> `.user.ini` không đủ.

Theo CVE-2026-109618 (OOM):

| Biện pháp | Cách đặt | Ghi chú |
|---|---|---|
| Bỏ giới hạn bộ nhớ PHP | `php_admin_value[memory_limit] = -1` | Loại bỏ điểm kích hoạt OOM do ứng dụng điều khiển; **bắt buộc** có giới hạn cgroup/container để không sập máy |
| Hạ kích thước request | `post_max_size = 8M` (không upload) hoặc `32M` (có upload); `upload_max_filesize` < `post_max_size` | Giảm khả năng ép OOM từ request lớn |
| Giới hạn ở proxy | `client_max_body_size`, số field, số part multipart, số header, độ sâu nesting | Phải áp dụng cả với request không có `Content-Length` |
| Giới hạn bộ nhớ ngoài | cgroup/container memory limit, policy chỉ kill worker bị ảnh hưởng | **Không** dùng `RLIMIT_AS`/`RLIMIT_DATA` — có thể tạo đúng lỗi cấp phát cần tránh |

Theo CVE-2026-109619 (trạng thái cũ):

| Biện pháp | Cách đặt | Ghi chú |
|---|---|---|
| Tắt session upload progress | `session.upload_progress.enabled = 0` | Đặt trong `php.ini`/pool, **restart mọi worker** |
| Tắt fatal error backtrace (chỉ PHP 8.5) | `fatal_error_backtraces = 0` | Chặn đường backtrace đã biết |
| Bỏ setting deprecated theo request | Rà `ini_set()` trong bootstrap | Cảnh báo phát sinh trước khởi tạo là mầm lỗi |
| Sửa fatal error/timeout | Callback, upload, import, cleanup | Lỗi fatal do kẻ tấn công chạm tới là bề mặt khai thác |

Ví dụ đặt trong pool FPM (`/etc/php/8.3/fpm/pool.d/site.conf`), chỉ dùng tạm:

```ini
; TAM THOI - chi khi chua the va PHP2Shell. Xem README chuong 2.
php_admin_value[memory_limit] = -1
php_admin_value[post_max_size] = 32M
php_admin_value[upload_max_filesize] = 16M
php_admin_value[session.upload_progress.enabled] = 0
```

```bash
sudo php-fpm8.3 -t && sudo systemctl restart php8.3-fpm
```

Sau khi vá xong: **bỏ `memory_limit = -1`**, trả lại giới hạn bình thường (ví dụ 192M trong [`conf/php-fpm-83.pool`](conf/php-fpm-83.pool)), và bật lại upload progress nếu ứng dụng cần.

WAF (Cloudflare hoặc tương đương) có thể chặn một phần traffic khai thác đã biết, nhưng chỉ là biện pháp cầm máu — không được coi là đã an toàn.

### 2.5. Sau khi vá: kiểm tra và săn dấu vết

Vì đã có khai thác trước ngày vá, đừng dừng ở việc nâng version. Kiểm tra:

```bash
# 1) version thực tế của mọi binary
for b in php php8.2 php8.3 php8.4 php8.5; do
  command -v "$b" >/dev/null 2>&1 && "$b" -r 'echo PHP_BINARY," ",PHP_VERSION,PHP_EOL;'
done

# 2) worker có crash/OOM bất thường không
journalctl -u php8.3-fpm --since '14 days ago' --no-pager | grep -Ei 'segfault|oom|memory|corrupt|killed'
dmesg -T | grep -Ei 'php|oom|segfault' | tail -30

# 3) tiến trình con lạ do web server sinh ra
ps -eo pid,ppid,user,etime,cmd --sort=start_time | grep -E 'www-data|apache|nginx|php-fpm' | tail -30

# 4) file PHP mới xuất hiện trong webroot
find /var/www -type f -name '*.php' -mtime -14 -printf '%TY-%Tm-%Td %TH:%TM %p\n' | sort
```

Dấu hiệu đáng ngờ: worker chết hàng loạt không rõ nguyên nhân, `segfault` trong log FPM/Apache, tiến trình `sh`/`curl`/`wget` có parent là web server, file PHP lạ trong `uploads/` hoặc thư mục cache, kết nối ra ngoài bất thường.

Nếu nghi đã bị khai thác:

1. Cô lập máy khỏi Internet (chặn ở firewall/provider), **giữ nguyên ổ đĩa và log**.
2. Vá PHP trước khi cho máy trở lại mạng.
3. Coi toàn bộ secret trên máy là đã lộ: đổi mật khẩu DB, API key, `APP_KEY`, salt, token CI/CD.
4. Rà webshell, cron, `authorized_keys`, user mới, rule firewall mới.
5. Nếu không đủ nguồn lực điều tra: rebuild từ image sạch + restore dữ liệu đã kiểm tra.

### 2.6. Câu hỏi nhanh

**8.1 đã EOL, có bản vá không?**
Không từ upstream. Một số distro/LTS vendor có backport; nếu không có, phải nâng lên 8.3+ hoặc tự build từ nhánh source-backport `PHP-8.1-CVE-2026-109618-109619`. Đây là lý do EOL nguy hiểm: không có bản vá chính thức.

**Chỉ chạy CLI, không phục vụ web thì sao?**
Rủi ro thấp hơn vì không có request từ xa, nhưng vẫn nên vá — CLI/queue có thể xử lý dữ liệu do kẻ tấn công đưa vào. Restart cả worker CLI sau khi vá.

**Đã bật WAF thì có thể chờ vá không?**
Không. WAF chỉ chặn đường đã biết; đã có biến thể và traffic né WAF. Vá là giải pháp duy nhất đầy đủ.

**Vá 8.2.35 xong có cần lên 8.3?**
Có, càng sớm càng tốt: 8.2 hết hỗ trợ bảo mật 31/12/2026, sau đó không còn bản vá nào.

**Có liên quan CVE-2026-115560 không?**
Đó là advisory tiếp theo (23/10/2026) về session upload progress, mức độ thấp hơn và chỉ kích hoạt trong cấu hình hiếm. Khuyến nghị giữ `session.upload_progress.enabled=0` đến bản bugfix kế tiếp.

---

## 3. TL;DR: vá bảo mật trong cùng nhánh mất 5 phút

Khi có CVE mới và bạn đã ở đúng nhánh (ví dụ 8.3.x → 8.3.y): **không đổi socket, không sửa nginx**, chỉ một vòng lệnh.

Ubuntu/Debian:

```bash
sudo apt update
apt list --upgradable 2>/dev/null | grep -i '^php'    # xem đúng những gì sẽ nâng
sudo apt install --only-upgrade 'php*'
sudo php-fpm8.3 -t && sudo systemctl restart php8.3-fpm
sudo nginx -t && sudo systemctl reload nginx
```

RHEL/Rocky/Alma:

```bash
sudo dnf updateinfo list --updates security | grep -i '^php'
sudo dnf update 'php*' -y
sudo php-fpm -t && sudo systemctl restart php-fpm
sudo nginx -t && sudo systemctl reload nginx
```

Thay `8.3` trong tên service bằng nhánh đang chạy (xem nhanh bằng `scripts/php-eol-check.sh`).

Phân bổ 5 phút: nâng package ~2 phút, lint nhanh file vừa deploy ~1 phút, restart FPM + `nginx -t` + reload ~1 phút, mở site bấm một request thật ~1 phút.

> [!IMPORTANT]
> Đây là lối tắt **chỉ cho cùng nhánh**. Nâng 8.1 → 8.3 là thay đổi runtime, phải
> đi theo chương 6 và chương 7. Đừng dùng `--only-upgrade` rồi tưởng đã "lên 8.3".

---

## 4. Ubuntu/Debian: apt và ppa:ondrej/php

### 4.1. Soi hiện trạng trước khi gõ lệnh

```bash
php -v                                    # nhánh CLI đang chạy
ls /etc/php/                              # các nhánh đã cài (8.1, 8.2, 8.3, ...)
systemctl list-units 'php*-fpm*'          # service FPM đang chạy
ls -l /run/php/                           # socket FPM đang mở
grep -rn 'fastcgi_pass' /etc/nginx/       # nginx đang trỏ socket nào
```

Ghi lại 3 thứ này vào sổ trước khi làm bất cứ điều gì: **nhánh đang chạy**, **socket đang dùng**, **đường dẫn vhost**.

### 4.2. Thêm ppa:ondrej/php

PPA của Ondřej Surý phát hành đầy đủ các nhánh PHP 8.x cho Ubuntu, bám CVE rất sát:

```bash
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
```

> [!NOTE]
> Debian dùng repo chính thức hoặc `deb.sury.org` thay cho PPA (PPA chỉ dành cho
> Ubuntu). Cách làm pool/socket bên dưới giống nhau.

### 4.3. Cài nhánh mới cùng bộ module chuẩn

```bash
sudo apt install -y php8.3-fpm php8.3-cli \
  php8.3-mysql php8.3-curl php8.3-mbstring php8.3-xml php8.3-gd \
  php8.3-zip php8.3-bcmath php8.3-intl php8.3-opcache
```

Gói sinh sẵn pool `www` với socket `/run/php/php8.3-fpm.sock`. Nếu mỗi site có pool riêng, copy pool cũ sang nhánh mới rồi đổi socket:

```bash
sudo cp -a /etc/php/8.1/fpm/pool.d/site.conf /etc/php/8.3/fpm/pool.d/site.conf
sudo sed -i 's#/run/php/php8.1-fpm#/run/php/php8.3-fpm#g' /etc/php/8.3/fpm/pool.d/site.conf
sudo php-fpm8.3 -t
sudo systemctl enable --now php8.3-fpm
```

Mẫu pool đầy đủ (user, `pm`, opcache, slowlog): [`conf/php-fpm-83.pool`](conf/php-fpm-83.pool).

### 4.4. Trỏ nginx sang socket mới

Sửa đúng một dòng trong vhost:

```nginx
fastcgi_pass unix:/run/php/php8.3-fpm.sock;
```

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Chỉ **reload** — nginx giữ worker cũ cho tới khi worker mới sẵn sàng, kết nối đang mở không bị cắt.

### 4.5. So lệch module giữa hai nhánh

Mỗi nhánh là một bộ package riêng. Site chạy được ở 8.1 nhưng thiếu module ở 8.3 là lỗi kinh điển:

```bash
diff <(php8.1 -m | sort -u) <(php8.3 -m | sort -u)
```

Dòng chỉ có ở nhánh cũ = module bị thiếu:

```bash
sudo apt install php8.3-<module>
```

`mcrypt` và `mhash` không còn trong PHP 8.x — chuyển sang `openssl` hoặc `sodium` (chương 8).

---

## 5. RHEL/Rocky/Alma: dnf và repo Remi

### 5.1. Xem stream đang bật

```bash
sudo dnf module list php
php -v
sudo systemctl status php-fpm
```

Trên RHEL, service tên là `php-fpm` (một service cho cả server), pool nằm ở `/etc/php-fpm.d/`, socket mặc định `/run/php-fpm/www.sock`.

### 5.2. Cài repo Remi

```bash
# RHEL/Rocky/Alma 9
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
# RHEL/Rocky/Alma 8
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
```

Rocky/Alma cần EPEL (`dnf install epel-release`); RHEL cần subscription cho các dependency base.

### 5.3. Chọn stream PHP

```bash
sudo dnf module reset php -y          # gỡ stream đang bật trước khi đổi
sudo dnf module enable php:remi-8.3 -y
sudo dnf update 'php*' -y             # hoặc dnf install php nếu máy chưa có PHP
sudo php-fpm -t && sudo systemctl enable --now php-fpm
sudo nginx -t && sudo systemctl reload nginx
```

Muốn runway dài hơn thì đổi `remi-8.3` thành `remi-8.4` (bảo mật đến 31/12/2028). Nguyên tắc vẫn là **8.3 trước, 8.4 khi code đã sạch**.

Nếu chỉ cần **vá trong cùng stream** thì bỏ bước `module reset/enable`, chỉ chạy:

```bash
sudo dnf update 'php*' -y
```

> [!NOTE]
> Trên RHEL, stream module chỉ cho phép **một nhánh PHP chạy tại một thời điểm**.
> Blue-green kiểu hai pool song song vì thế cần gói SCL của Remi (mục 6.4) hoặc
> chấp nhận một cửa sổ downtime ngắn.

---

## 6. Nâng nhánh 8.1/8.2 lên 8.3 theo kiểu blue-green

Mục tiêu: gần như zero downtime, rollback tức thì bằng một dòng nginx, chỉ gỡ nhánh cũ sau khi đã chứng minh ổn định. Đơn vị cốt lõi là **hai pool PHP-FPM cài song song, mỗi pool một socket**.

### 6.1. Chiến lược

- **Blue (cũ)**: `php8.1-fpm`, socket `/run/php/php8.1-fpm.sock`, đang phục vụ traffic.
- **Green (mới)**: `php8.3-fpm`, socket `/run/php/php8.3-fpm.sock`, đã cài và chạy nhưng chưa nhận traffic.
- Chuyển traffic = sửa **một dòng** `fastcgi_pass` rồi reload. Quay lui = sửa ngược lại dòng đó.

### 6.2. Các bước

1. **Cài nhánh mới, không đụng nginx** — site không downtime:

    ```bash
    sudo apt install -y php8.3-fpm php8.3-cli php8.3-mysql php8.3-curl \
      php8.3-mbstring php8.3-xml php8.3-gd php8.3-zip php8.3-bcmath \
      php8.3-intl php8.3-opcache
    ```

2. **Copy pool, giảm `pm.max_children` tạm thời** (ví dụ 12 → 8) để hai pool không bóp RAM. Theo dõi bằng `free -m` và `ps -o rss= -C php-fpm8.3 | awk '{s+=$1} END {print s/1024 " MB"}'`.

3. **Kiểm cú pháp và khởi động pool mới**:

    ```bash
    sudo php-fpm8.3 -t
    sudo systemctl enable --now php8.3-fpm
    systemctl --no-pager --lines=0 status php8.3-fpm
    ```

4. **Đổi `fastcgi_pass`**, giữ dòng cũ làm chú thích để rollback một phím:

    ```nginx
    fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    # fastcgi_pass unix:/run/php/php8.1-fpm.sock;   # rollback: bỏ comment dòng này
    ```

5. **Reload nginx**:

    ```bash
    sudo nginx -t && sudo systemctl reload nginx
    ```

6. **Chạy song song ít nhất 24 giờ** (một vòng ngày đủ để gặp cron/backup/traffic đêm). Theo dõi:
   - `tail -f /var/log/nginx/error.log`
   - `error_log` của pool mới
   - `pm.status_path` (worker có bị đói không)
   - RSS thực tế của từng pool.

   Pool cũ **giữ nguyên config**, không sửa gì.

7. **Rollback khi lỗi**: bỏ comment dòng cũ, comment dòng mới, `nginx -t`, `reload` — khoảng 30 giây, không cần gỡ gì.

8. **Kết thúc** sau 24–48 giờ ổn định: gỡ nhánh cũ và mở lại `pm.max_children` chuẩn.

    ```bash
    sudo systemctl disable --now php8.1-fpm
    sudo apt remove 'php8.1-*' && sudo apt autoremove
    ```

> [!CAUTION]
> Đừng gỡ pool cũ trước khi hết cửa sổ theo dõi. Không có pool cũ thì "rollback"
> biến thành "cài lại từ đầu", và đó là lúc sự cố kéo dài.

### 6.3. RAM và giới hạn khi chạy hai pool

- Tổng RAM xấu nhất ≈ `pm.max_children × RSS/worker` của **cả hai** pool. Đo RSS thật, đừng đoán.
- RAM mỏng: hạ `pm.max_children` cả hai pool, dùng `pm = dynamic` để pool idle không giữ worker.
- Chặn `memory_limit` trong pool config (xem [`conf/php-fpm-83.pool`](conf/php-fpm-83.pool)), đừng để `-1`.
- Bật `pm.status_path` cho cả hai pool để so sánh số worker bận và hàng đợi.

### 6.4. Riêng RHEL: hai nhánh song song bằng gói SCL của Remi

Nếu bắt buộc phải blue-green trên RHEL (không được downtime), dùng bộ package SCL của Remi — cài song song với PHP hệ thống, không ghi đè:

```bash
sudo dnf --enablerepo=remi-safe install -y php83-php-fpm php83-php-cli \
  php83-php-mysqlnd php83-php-opcache php83-php-mbstring php83-php-xml
systemctl list-units 'php83*'          # xác nhận tên unit thực tế
sudo systemctl enable --now php83-php-fpm
```

Đường dẫn thường gặp: config `/etc/opt/remi/php83/php-fpm.d/`, socket `/var/opt/remi/php83/run/php-fpm/www.sock`, service `php83-php-fpm`. Kiểm tra lại bằng `rpm -ql php83-php-fpm | grep -E 'fpm.d|www.sock'` trước khi trỏ nginx — tên gói/đường dẫn có thể khác theo phiên bản Remi.

---

## 7. Kiểm tra mã nguồn trước khi nâng nhánh

Thứ tự nên làm: tĩnh (phpcs/rector) → cú pháp (`php -l`) → framework (Laravel/WordPress) → staging.

### 7.1. PHPCompatibility

Quét code theo target 8.3 để liệt kê deprecation và breaking change:

```bash
composer require --dev phpcompatibility/php-compatibility \
  dealerdirect/phpcodesniffer-composer-installer
vendor/bin/phpcs -p \
  --standard=PHPCompatibility \
  --runtime-set testVersion 8.3 \
  --extensions=php /var/www/site
```

Còn `ERROR` thì **chưa** lên nhánh mới — sửa từng lỗi trước. `WARNING` là deprecation, nên xử lý trong cùng đợt.

### 7.2. Rector dry-run

Xem Rector có thể tự sửa những gì:

```bash
composer require --dev rector/rector
vendor/bin/rector process --dry-run --set php83 /var/www/site
```

Chỉ chạy thật (bỏ `--dry-run`) khi đã commit hoặc backup sạch.

### 7.3. Lint toàn bộ bằng đúng binary sắp chạy

```bash
find /var/www/site -name '*.php' -print0 \
  | xargs -0 -n1 -P4 php8.3 -l 2>&1 \
  | grep -E 'Parse error|Errors parsing' || echo 'LINT OK'
```

`LINT OK` nghĩa là không file nào lỗi cú pháp. Nếu có dòng lỗi, sửa trước khi reload.

### 7.4. Laravel

```bash
composer install --no-dev --optimize-autoloader   # trên staging/production
php artisan migrate --pretend                     # chỉ in SQL, không chạy
php artisan test                                  # so với kết quả trên nhánh cũ
```

Điều kiện phiên bản: Laravel 9 cần PHP ≥ 8.0, Laravel 10 cần ≥ 8.1, Laravel 11/12 cần ≥ 8.2 — kiểm trong `composer.json` (`"php": "^8.x"`).

### 7.5. WordPress (WP-CLI)

```bash
wp core check-update
wp core verify-checksums
wp plugin list --update=available --fields=name,version,update
wp theme list --update=available --fields=name,version,update
```

Trình tự đúng: **backup (DB + `wp-content`) → nâng core → nâng plugin/theme → thử PHP mới trên staging → production**. Các bản WordPress 6.6 trở lên đã được kiểm thử với PHP 8.3; nếu còn 6.5 trở xuống, nâng core trước.

---

## 8. Lỗi hay gặp khi nâng 8.0/8.1 lên 8.3

| Thông báo | Xuất hiện từ | Cách sửa | Hay gặp ở |
|---|---|---|---|
| `Creation of dynamic property ... is deprecated` | 8.2 | Khai báo property rõ ràng; tạm thời gắn `#[\AllowDynamicProperties]` | Plugin/theme WP cũ, helper class |
| `Passing null to parameter #1 ... deprecated` | 8.1 | Chặn null: `strtolower($x ?? '')` | WP core mở rộng, plugin cũ |
| `utf8_encode()` / `utf8_decode()` deprecated | 8.2 | `mb_convert_encoding()` hoặc ICU | Plugin WP, thư viện cũ |
| `Implicit conversion from float to int loses precision` | 8.1 | Ép tường minh `(int)` sau `round()` | Code tính tiền, thống kê |
| `Cannot modify $GLOBALS` | 8.1 | Dùng biến toàn cục tường minh hoặc truyền tham số | Code kiểu PHP 5 |
| `strftime()`, `gmstrftime()` deprecated | 8.1 | `DateTimeImmutable::format()` / `IntlDateFormatter` | Code base trước 2019 |
| `${var}` trong chuỗi deprecated | 8.2 | `{$var}`, hoặc nối chuỗi | Template cũ |
| `Call to undefined function mcrypt_*` | từ 7.2 (bị gỡ) | `openssl_encrypt` / `sodium_crypto_secretbox` | Site nâng từ 5.x/7.x |
| Constructor kiểu `Class()` không còn chạy | 8.0 | Đổi thành `__construct()` | Theme 2008–2014 |
| `Declaration of ... must be compatible` | 8.0+ | Đồng bộ signature theo class cha | Framework cũ |

Bảng map nhanh framework:

| Thành phần | PHP tối thiểu | Ghi chú khi lên 8.3 |
|---|---|---|
| Laravel 9 | 8.0 | Nên lên 10/11 nếu còn thời gian |
| Laravel 10 | 8.1 | Ổn với 8.3 |
| Laravel 11/12 | 8.2 | Hỗ trợ 8.3 tốt |
| WordPress 6.6+ | 7.2 (khuyến nghị 8.1+) | Đã test với 8.3 |
| WordPress ≤ 6.5 | 7.0 | Nâng core trước |

> [!TIP]
> Chạy `php -d error_reporting=E_ALL -d display_errors=1` trên **staging** và duyệt
> các trang nặng nhất. Deprecation chỉ hiện khi code path đó thực sự chạy — lint
> không bắt được.

---

## 9. Rollback: bảng lệnh đầy đủ

| Mục tiêu | Ubuntu/Debian (apt) | RHEL/Rocky/Alma (dnf) |
|---|---|---|
| Trả nginx về pool cũ | Sửa `fastcgi_pass` về socket cũ, `nginx -t`, `systemctl reload nginx` | Trỏ về socket pool cũ, reload |
| Khóa package không cho tự nâng | `sudo apt-mark hold 'php8.*'` (gỡ: `apt-mark unhold`) | Thêm `exclude=php*` vào `/etc/dnf/dnf.conf` |
| Chặn hẳn nhánh mới bằng apt pin | `/etc/apt/preferences.d/php-hold`: `Package: php8.4* php8.5*`, `Pin: release *`, `Pin-Priority: -1` | `sudo dnf module disable php:remi-8.4 php:remi-8.5` |
| Gỡ pool mới chạy song song | `sudo apt remove 'php8.3-*' && sudo apt autoremove` | `sudo dnf module reset php -y` rồi bật stream cũ |
| Quay về stream cũ | (không áp dụng) | `sudo dnf module reset php -y && sudo dnf module enable php:remi-8.2 -y && sudo dnf distro-sync 'php*'` |
| Hạ về version cụ thể | `apt list -a php8.3-fpm` rồi `sudo apt install php8.3-fpm=<version>` | `sudo dnf downgrade 'php*'` |
| Chặn cron tự nâng nhánh mới | Giữ blacklist trong `unattended-upgrades` (chương 10) | Giữ `exclude=` trong `dnf.conf` |

Nguyên tắc: **rollback không gỡ pool cũ**. Cứ để pool cũ sống tới khi bạn chính thức "kết thúc" (chương 6.2 bước 8).

---

## 10. Tự động hoá cập nhật bảo mật

Nguyên tắc: hệ thống chỉ được **tự vá trong cùng nhánh** (8.3.x → 8.3.y). Nhánh mới (8.4/8.5) luôn nâng bằng tay vì nó là thay đổi runtime, phải qua chương 6–7.

### 10.1. Ubuntu/Debian: unattended-upgrades

```ini
// /etc/apt/apt.conf.d/52php-security
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "LP-PPA-ondrej-php:${distro_codename}";
};
Unattended-Upgrade::Package-Blacklist {
    "php8.4-";
    "php8.5-";
};
Unattended-Upgrade::Automatic-Reboot "false";
```

Kiểm tra cấu hình đã hiểu đúng:

```bash
sudo unattended-upgrade --dry-run --debug 2>&1 | grep -i php
```

Kết hợp `apt-mark hold` hoặc apt pin (chương 9) để chắc chắn không ai vô tình cài nhánh mới.

### 10.2. RHEL: dnf-automatic

```ini
# /etc/dnf/automatic.conf
[commands]
upgrade_type = security
apply_updates = yes
```

```ini
# /etc/dnf/dnf.conf
[main]
exclude=php8.4*,php8.5*
```

```bash
sudo systemctl enable --now dnf-automatic.timer
```

### 10.3. Cron theo dõi CVE hằng tuần

```bash
#!/usr/bin/env bash
set -euo pipefail

if command -v apt >/dev/null 2>&1; then
  out="$(apt list --upgradable 2>/dev/null | grep -i '^php' || true)"
elif command -v dnf >/dev/null 2>&1; then
  out="$(dnf -q updateinfo list --updates security 2>/dev/null | grep -i '^php' || true)"
else
  out=""
fi

if [ -n "$out" ]; then
  printf '%s\n' "$out"
  # gửi mail/hook: thay bằng lệnh alert của bạn
  exit 1
fi
echo "khong co ban va PHP nao dang cho"
```

Đặt ở `/etc/cron.weekly/php-cve-watch` (nhớ `chmod +x`). Exit code `1` tiện để cron gửi cảnh báo.

---

## 11. Case study: WordPress 8.1 lên 8.3 trong 25 phút

Bối cảnh: site WordPress công ty, Ubuntu 22.04 + nginx + `ppa:ondrej/php`, đang chạy **PHP 8.1 (EOL)**, 2 vCPU / 4 GB RAM, một pool FPM.

| Phút | Việc làm |
|---|---|
| 0 | `php -v` = 8.1.x (EOL); `apt update`; copy vhost + pool config ra `/root/backup-$(date +%F)` |
| 2 | Cài `php8.3-fpm` + module (chương 4.3) — site vẫn chạy qua pool 8.1, **không downtime** |
| 5 | Copy pool config, hạ `pm.max_children` 12 → 8; `php-fpm8.3 -t` pass; `enable --now php8.3-fpm` |
| 7 | Đổi `fastcgi_pass` sang socket 8.3; `nginx -t` pass; `reload` |
| 9 | Homepage và một post ok |
| 11 | `tail -f /var/log/nginx/error.log` báo `Class "NumberFormatter" not found` — nhánh 8.3 thiếu `php8.3-intl` (đúng như `php -m` diff ở chương 4.5 đã cảnh báo) |
| 11–13 | **ROLLBACK**: `fastcgi_pass` về socket 8.1, `nginx -t`, `reload`. Site sống lại 100% |
| 14 | `apt install php8.3-intl`; chạy lại bộ kiểm chương 7 trên bản clone staging |
| 18 | Deploy thử lại, duyệt các trang nặng |
| 22 | Cắt traffic lần hai sang 8.3; theo dõi error log + `pm.status` |
| 25 | Chốt: lên lịch gỡ pool 8.1 sau 48 giờ, mở lại `pm.max_children` chuẩn |

Bài học:

1. **Rollback 2 phút** chỉ khả thi vì pool cũ còn sống — đừng gỡ sớm.
2. **Lệch module** là lỗi phổ biến nhất khi nâng nhánh; `diff <(php8.1 -m) <(php8.3 -m)` ngay sau khi cài sẽ bắt được từ đầu.
3. **Nâng core/plugin trước, PHP sau** — thứ tự ngược lại thường đổ lỗi sai chỗ.

---

## 12. FAQ

**1. Sao không nâng thẳng lên 8.5?**

Vì 8.3 là điểm cân bằng: đủ mới, được bảo mật đến 31/12/2027, và gần như mọi plugin/theme phổ biến đã hỗ trợ. 8.4/8.5 chỉ nên nhắm khi code đã sạch deprecation và tooling đã theo kịp.

**2. Nâng PHP có mất dữ liệu hay opcache không?**

Không mất dữ liệu. Restart FPM chỉ xóa opcode cache — PHP tự build lại khi có request. DB không bị đụng tới. Trong blue-green, pool cũ vẫn phục vụ request trong khi pool mới làm nóng cache.

**3. Site tĩnh không chạy PHP thì sao?**

Vẫn phải kiểm: cron, composer, wp-cli, script backup có thể dùng PHP CLI. CLI cũng cần nhánh được hỗ trợ bảo mật.

**4. Chọn 8.3 hay 8.4?**

8.3 nếu site còn theme/plugin cũ — đường an toàn nhất từ 8.1/8.2. 8.4 nếu code đã qua PHPCompatibility sạch và bạn muốn hỗ trợ đến 31/12/2028.

**5. Vì sao phải chạy hai pool song song?**

Vì đó là cách duy nhất có rollback tức thì mà không cài lại: nginx trỏ về pool cũ ngay khi phát hiện lỗi, downtime gần bằng 0 (chương 6).

**6. Composer chạy PHP CLI 8.1 trong khi FPM đã 8.3 thì sao?**

Cài `php8.3-cli` và gọi đúng binary (`php8.3 /usr/local/bin/composer install`) để dependency được resolve theo đúng runtime. Nếu CLI lệch nhánh, autoload/extension có thể lệch lúc deploy.

**7. Có cần restart nginx không?**

Không. `reload` đủ và an toàn hơn. Chỉ restart khi nginx đã ở trạng thái lỗi không reload được.

---

## 13. Thuật ngữ

| Thuật ngữ | Nghĩa |
|---|---|
| **PHP-FPM pool** | Tập worker PHP-FPM có config riêng (user, `pm`, giới hạn tài nguyên); mỗi pool nghe một socket riêng |
| **Socket** | Unix domain socket (vd `/run/php/php8.3-fpm.sock`) để nginx gửi request PHP tới pool |
| **EOL** | End of Life — nhà phát hành không còn phát bản vá cho nhánh đó |
| **CVE** | Mã định danh lỗ hổng bảo mật (Common Vulnerabilities and Exposures) |
| **ondrej/php** | PPA của Ondřej Surý trên Ubuntu — kho PHP 8.x đầy đủ, vá nhanh, mỗi nhánh một bộ package |
| **Remi** | Repo của Remi Collet cho RHEL/Rocky/Alma; quản nhánh qua dnf module (`php:remi-8.3`) |
| **opcache** | Opcode cache — biên dịch PHP ra bytecode giữ ở RAM để request sau dùng lại |
| **blue-green** | Đổi phiên bản bằng hai môi trường song song, chuyển traffic bằng một điểm duy nhất (nginx route) |
| **fastcgi_pass** | Chỉ thị nginx trỏ request PHP tới socket/TCP của PHP-FPM |
| **`pm.max_children`** | Số worker tối đa của một pool; đặt sai là nguyên nhân phổ biến của 502/timeout |

---

## 14. Quy tắc vàng trước mỗi lần reload

**Mọi thao tác chỉ thực hiện sau khi đã test. Tuyệt đối không vội reload.** Ba lệnh sau phải pass hết:

```bash
# 1) Cú pháp pool PHP-FPM sắp chạy
sudo php-fpm8.3 -t

# 2) Cú pháp nginx (sửa file nào cũng phải test)
sudo nginx -t

# 3) Lint toàn bộ ứng dụng bằng đúng nhánh sắp chạy
find /var/www/site -name '*.php' -print0 | xargs -0 -n1 php8.3 -l
```

Quy tắc:

- Một trong ba lệnh báo lỗi ⇒ **dừng, sửa, test lại** — không reload.
- Backup config trước mỗi đợt: `sudo cp -a /etc/php /root/backup-php-$(date +%F)` và `sudo cp -a /etc/nginx /root/backup-nginx-$(date +%F)`.
- Chỉ reload nginx; restart FPM vào giờ thấp điểm.
- Test trên staging cùng nhánh mới trước; production chỉ là bước xác nhận sau health check.
- Lỗi bất thường sau reload: **rollback trước, chẩn đoán sau**.

> [!CAUTION]
> `systemctl restart php8.3-fpm` làm rơi toàn bộ request đang xử lý. Với site có
> thanh toán/upload, hãy chọn giờ thấp điểm hoặc dùng blue-green để tránh rơi request.

---

## 15. Cấu trúc repo, đóng góp và License

```
update-php-cve/
├── README.md                 # playbook này (tiếng Việt)
├── LICENSE                   # MIT
├── .gitignore
├── conf/
│   └── php-fpm-83.pool       # pool config mẫu PHP-FPM 8.3
├── docs/
│   └── quick-reference-en.md # cheat sheet 1 trang tiếng Anh
└── scripts/
    └── php-eol-check.sh      # kiểm EOL / pool / opcache / module diff (read-only)
```

Cách dùng script:

```bash
bash scripts/php-eol-check.sh            # in báo cáo ra màn hình
bash scripts/php-eol-check.sh > /tmp/php-eol.txt
```

Exit code: `0` không có cảnh báo (hoặc không tìm thấy PHP), `1` có cảnh báo, `2` không truy vấn được PHP.

Đóng góp: PR luôn được chào đón — đặc biệt là case study thực tế, bản dịch tiếng Anh đầy đủ, và chỉnh sửa số liệu vòng đời PHP. Giữ cấu trúc heading `## N.` và không thêm emoji để anchor ổn định.

License: [MIT](LICENSE) — copyright 2026 fixnhanh-linux.
