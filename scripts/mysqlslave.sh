#!/bin/bash
export ENV=`hostname | sed 's/\([a-z]*\)-\([0-9.]*\)-\(.*\)/\1-\2/'`

sudo sed -i "/DataSourceReplicas/c\        \"DataSourceReplicas\": [\"mmuser:Password42!@tcp(${ENV}-mm-ha-2:3306)/mattermost?charset=utf8mb4,utf8&readTimeout=30s&writeTimeout=30s\"]," /opt/mattermost/config/config.json
mysql -u root -p"Password42!" mattermost < /vagrant/scripts/mattermost.sql
sudo sed -i '/^#server-id/c\server-id               = 2' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/^#relay-log/c\relay-log               = /var/log/mysql/mysql-relay-bin.log' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/^#log_bin/c\log_bin                 = /var/log/mysql/mysql-bin.log' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i '/^binlog_do_db/c\binlog_do_db            = newdatabase' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart
mysql -u root -p"Password42!" <<MYSQL_INPUT
CHANGE MASTER TO MASTER_HOST='ubuntu-1604-mm-ha-1',MASTER_USER='slave_user', MASTER_PASSWORD='password', MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=  1;
START SLAVE;
SHOW SLAVE STATUS\G
MYSQL_INPUT
sudo service mattermost restart
