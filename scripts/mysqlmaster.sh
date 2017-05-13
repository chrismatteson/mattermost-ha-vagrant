#!/bin/bash
sudo sed -i '/"DataSourceReplicas":/c\        "DataSourceReplicas": ["mmuser:Password42!@tcp(ubuntu-1604-mm-ha-2:3306)/mattermost?charset=utf8mb4,utf8&readTimeout=30s&writeTimeout=30s"],' /opt/mattermost/config/config.json
sudo sed -i '/^#server-id/c\server-id               = 1' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/^#log_bin/c\log_bin                 = /var/log/mysql/mysql-bin.log' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/^binlog_do_db/c\binlog_do_db            = newdatabase' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart
mysql -u root -p"Password42!" <<MYSQL_INPUT
GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
MYSQL_INPUT
sudo service mattermost restart
