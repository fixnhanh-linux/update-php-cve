# update-php-cve

Hướng dẫn vá lỗ hổng & nâng cấp PHP cho web server (nginx + php-fpm), cho
Ubuntu/Debian và RHEL/Rocky/Alma.

**Trạng thái: đang hoàn thiện nội dung — playbook đầy đủ sẽ được cập nhật trong
ít phút.**

## Vì sao cần cập nhật PHP

- PHP 8.1 và các nhánh cũ hơn: **EOL**, không còn bản vá CVE.
- PHP 8.2: chỉ nhận bản vá bảo mật đến **31/12/2026**.
- PHP 8.3: bản vá bảo mật đến **31/12/2027**.
- PHP 8.4/8.5: đang được hỗ trợ đầy đủ.

Nguồn chính thức: <https://www.php.net/supported-versions.php>

## Nội dung sẽ có

1. TL;DR: chạy bản vá trong cùng nhánh (5 phút, không downtime)
2. Ubuntu/Debian: apt + `ppa:ondrej/php`
3. RHEL/Rocky/Alma: dnf + repo Remi
4. Nâng nhánh chính 8.1 → 8.3 theo chiến lược blue–green (2 pool php-fpm)
5. Kiểm thử ứng dụng trước khi chuyển
6. Các lỗi hay gặp khi nâng nhánh
7. Rollback an toàn
8. Tự động hoá cập nhật bảo mật

## License

MIT
