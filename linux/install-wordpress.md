### Install and config wordpress on ubuntu server
**Step 0:** Update and upgrade os
```bash
sudo apt-get update
sudo apt-get upgrade
```

**Step 1:** Install NGINX
```
sudo apt-get install nginx

# start nginx service
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl status nginx
```

**Step 2:** Install MariaDB
```bash
sudo apt-get install mariadb-server

# start and enable mariadb service
sudo systemctl enable mariadb.service
sudo systemctl restart mariadb.service
sudo systemctl status mariadb.service

# run secure script and harden mariadb
mysql_secure_installation
```

**Step 3:** Install PHP
```bash
sudo apt-get install php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-opcache php8.1-mbstring php8.1-xml php8.1-gd php8.1-curl
```

**Step 4:** Create WordPress Database
```bash
mysql -u root -p

    CREATE DATABASE wordpress_db;
    GRANT ALL ON wordpress_db.* TO 'wpuser'@'localhost' IDENTIFIED BY 'nfG5RrSov16#' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
    exit
```

**Step 5:** Configure NGINX for WordPress
```bash
mkdir -p /var/www/html/wordpress/public_html

vim wordpress.conf
server {
    listen 80;
    root /var/www/html/wordpress/public_html;
    index index.php index.html;
    server_name wp.linux.mecan.ir;

	access_log /var/log/nginx/linux.mecan.access.log;
    error_log /var/log/nginx/linux.mecan.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }
}

# check nginx config
nginx -t

# remove default nginx config file
rm /etc/nginx/sites-enabled/default

# restart and enable nginx service
systemctl enable nginx
systemctl restart nginx
systemctl status nginx
```

**Step 6:** Download and Configure WordPress
```bash
cd /var/www/html/wordpress/public_html
wget https://wordpress.org/latest.tar.gz
tar -zxvf latest.tar.gz
mv wordpress/* .
rm -rf wordpress
chown -R www-data:www-data *
chmod -R 755 *

# configuration database connection
cd /var/www/html/wordpress/public_html
mv wp-config-sample.php wp-config.php

vim wp-config.php
 ...
 ...
 define('DB_NAME', 'wordpress_db');
 define('DB_USER', 'wpuser');
 define('DB_PASSWORD', 'nfG5RrSov16#');
 ...
 ...
```
**Step 7:** Install WordPress
**Step 8:** Create mysql backup
```bash
mysqldump -u root -pnfG5RrSov16# --all-databases --single-transaction --quick  > full-backup-$(date +%Y-%m-%d_%H-%M-%S).sql
```

**Step 8:** Create cronjob for mysql backup
```bash
# Create `/opt/db-backup` if not existing
[ -d /opt/db-backup ] || mkdir /opt/db-backup

# Create Mysql backup script
cat <<EOF > /opt/db-backup/backup.sh
mysqldump -u root -pnfG5RrSov16# --all-databases --single-transaction --quick  > full-backup-$(date +%Y-%m-%d_%H-%M-%S).sql
EOF

# Create crontab file
cat <<EOT > /etc/cron.d/backup-cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
# create and move backups on 03:39 Tehran
39 3 * * * root bash /opt/db-backup/backup.sh > /dev/null 2>&1
EOT

# check crontab file
cat /etc/cron.d/backup-cron
```