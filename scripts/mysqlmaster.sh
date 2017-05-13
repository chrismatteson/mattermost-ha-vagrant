#!/bin/bash
sudo sed -i '/^#server-id/c\server-id               = 1' /etc/mysql/my.cnf
sudo sed -i '/^#log_bin/c\log_bin                 = /var/log/mysql/mysql-bin.log' /etc/mysql/my.cnf
sudo sed -i '/^binlog_do_db/c\binlog_do_db            = newdatabase' /etc/mysql/my.cnf
sudo service mysql restart
mysql -u root -p"Password42!" <<MYSQL_INPUT
GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
MYSQL_INPUT
