#!/bin/bash

#prereq
sudo yum update -y
sudo yum upgrade -y

#Install mysql
wget http://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
sudo yum localinstall mysql57-community-release-el7-9.noarch.rpm -y
sudo yum install mysql-community-server -y
sudo systemctl start mysqld.service
mysql -u root -p"`sudo grep 'temporary password' /var/log/mysqld.log | grep -oE '[^ ]+$'`" --connect-expired-password <<MYSQL_INPUT
ALTER USER 'root'@'localhost' IDENTIFIED BY 'Password42!';
create user 'mmuser'@'%' identified by 'Password42!';
create database mattermost;
grant all privileges on mattermost.* to 'mmuser'@'%';
MYSQL_INPUT

#Install mattermost
wget https://releases.mattermost.com/3.8.2/mattermost-3.8.2-linux-amd64.tar.gz
tar -xvzf mattermost-*.tar.gz
sudo mv mattermost /opt
#sudo mkdir /opt/mattermost/data
sudo ln -s /vagrant/data/rhel7 /opt/mattermost/data
sudo useradd --system --user-group mattermost
sudo sed -i '/"DataSource":/c\        "DataSource": "mmuser:Password42!@tcp(rhel-7-mm-ha-1:3306)/mattermost?charset=utf8mb4,utf8&readTimeout=30s&writeTimeout=30s",' /opt/mattermost/config/config.json
#sudo sed -i '/"DataSourceReplicas":/c\        "DataSourceReplicas": ["mmuser:Password42!@tcp(rhel-7-mm-ha-2:3306)/mattermost?charset=utf8mb4,utf8&readTimeout=30s&writeTimeout=30s"],' /opt/mattermost/config/config.json
sudo sed -i '/"SqlSettings"/{n;s/postgres/mysql/g}' /opt/mattermost/config/config.json
sudo sed -i '/"ClusterSettings"/{n;s/false/true/g}' /opt/mattermost/config/config.json
sudo sed -i '/"InterNodeUrls"/c\        "InterNodeUrls": ["http://rhel-7-mm-ha-1","http://rhel-7-mm-ha-2"]' /opt/mattermost/config/config.json
sudo chown -R mattermost:mattermost /opt/mattermost
sudo chmod -R g+w /opt/mattermost
sudo cat <<EOF > /etc/systemd/system/mattermost.service
[Unit]
Description=Mattermost
After=syslog.target network.target postgresql-9.4.service

[Service]
Type=simple
WorkingDirectory=/opt/mattermost/bin
User=mattermost
ExecStart=/opt/mattermost/bin/platform
PIDFile=/var/spool/mattermost/pid/master.pid
LimitNOFILE=49152

[Install]
WantedBy=multi-user.target
EOF
sudo chmod 664 /etc/systemd/system/mattermost.service
sudo systemctl daemon-reload
sudo chkconfig mattermost on
sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
sudo firewall-cmd --zone=public --add-port=8065/tcp --permanent
sudo firewall-cmd --zone=public --add-port=8075/tcp --permanent
sudo systemctl restart firewalld
sudo systemctl enable mattermost
sudo systemctl start mattermost
(cd /opt/mattermost/bin/  && ./platform license upload /vagrant/license.mattermost-license)
sudo systemctl restart mattermost

#Install NGINX
sudo cat <<EOF > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/7/\$basearch/
gpgcheck=0
enabled=1
EOF
sudo yum install nginx.x86_64 -y
sudo systemctl start nginx
sudo systemctl enable nginx

#Configure NGINX
#sudo cat <<EOF > /etc/nginx/sites-available/mattermost
sudo cat <<EOF > /etc/nginx/conf.d/mattermost.conf
upstream backend {
   server rhel-7-mm-ha-1:8065;
   server rhel-7-mm-ha-2:8065;
}

proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=mattermost_cache:10m max_size=3g inactive=120m use_temp_path=off;

server {
   listen 80;
#   server_name    rhel-7-ha-proxy;

   location ~ /api/v[0-9]+/(users/)?websocket$ {
       proxy_set_header Upgrade \$http_upgrade;
       proxy_set_header Connection "upgrade";
       client_max_body_size 50M;
       proxy_set_header Host \$http_host;
       proxy_set_header X-Real-IP \$remote_addr;
       proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto \$scheme;
       proxy_set_header X-Frame-Options SAMEORIGIN;
       proxy_buffers 256 16k;
       proxy_buffer_size 16k;
       proxy_read_timeout 600s;
       proxy_pass http://backend;
   }

   location / {
       client_max_body_size 50M;
       proxy_set_header Connection "";
       proxy_set_header Host \$http_host;
       proxy_set_header X-Real-IP \$remote_addr;
       proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto \$scheme;
       proxy_set_header X-Frame-Options SAMEORIGIN;
       proxy_buffers 256 16k;
       proxy_buffer_size 16k;
       proxy_read_timeout 600s;
       proxy_cache mattermost_cache;
       proxy_cache_revalidate on;
       proxy_cache_min_uses 2;
       proxy_cache_use_stale timeout;
       proxy_cache_lock on;
       proxy_pass http://backend;
   }
}
EOF
#sudo rm /etc/nginx/sites-enabled/default
sudo rm /etc/nginx/conf.d/default.conf
#sudo ln -s /etc/nginx/sites-available/mattermost /etc/nginx/sites-enabled/mattermost
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo systemctl restart firewalld
sudo systemctl restart nginx

