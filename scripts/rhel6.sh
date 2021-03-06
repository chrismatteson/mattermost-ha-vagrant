#!/bin/bash

#prereq
sudo yum update -y
sudo yum upgrade -y

#Install mysql
wget http://dev.mysql.com/get/mysql57-community-release-el6-9.noarch.rpm
sudo yum localinstall mysql57-community-release-el6-9.noarch.rpm -y
sudo yum install mysql-community-server -y
sudo service mysqld start
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
sudo sed -i '/"DataSource":/c\        "DataSource": "mmuser:Password42!@tcp(rhel-6-mm-ha-1:3306)/mattermost?charset=utf8mb4,utf8&readTimeout=30s&writeTimeout=30s",' /opt/mattermost/config/config.json
#sudo sed -i '/"DataSourceReplicas":/c\        "DataSourceReplicas": ["mmuser:Password42!@tcp(rhel-6-mm-ha-2:3306)/mattermost?charset=utf8mb4,utf8&readTimeout=30s&writeTimeout=30s"],' /opt/mattermost/config/config.json
sudo sed -i '/"SqlSettings"/{n;s/postgres/mysql/g}' /opt/mattermost/config/config.json
sudo sed -i '/"ClusterSettings"/{n;s/false/true/g}' /opt/mattermost/config/config.json
sudo sed -i '/"InterNodeUrls"/c\        "InterNodeUrls": ["http://rhel-6-mm-ha-1","http://rhel-6-mm-ha-2"]' /opt/mattermost/config/config.json
sudo chown -R mattermost:mattermost /opt/mattermost
sudo chmod -R g+w /opt/mattermost
sudo cat <<EOF > /etc/init/mattermost.conf
start on runlevel [2345]
stop on runlevel [016]
respawn
limit nofile 50000 50000
chdir /opt/mattermost
exec bin/platform
EOF
sudo chkconfig mattermost on
sudo iptables -A INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 8065 -j ACCEPT
sudo iptables -A INPUT -p tcp -m tcp --dport 8075 -j ACCEPT
iptables-save | sudo tee /etc/sysconfig/iptables
sudo start mattermost
(cd /opt/mattermost/bin/ && ./platform license upload /vagrant/license.mattermost-license)
sudo stop mattermost
sudo start mattermost

#Install NGINX
sudo cat <<EOF > /etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/rhel/6/\$basearch/
gpgcheck=0
enabled=1
EOF
sudo yum install nginx.x86_64 -y
sudo service nginx start
sudo chkconfig nginx on

#Configure NGINX
#sudo cat <<EOF > /etc/nginx/sites-available/mattermost
sudo cat <<EOF > /etc/nginx/conf.d/mattermost.conf
upstream backend {
   server rhel-6-mm-ha-1:8065;
   server rhel-6-mm-ha-2:8065;
}

proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=mattermost_cache:10m max_size=3g inactive=120m use_temp_path=off;

server {
   listen 80;

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
sudo iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
iptables-save | sudo tee /etc/sysconfig/iptables
sudo service nginx restart

