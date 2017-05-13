#!/bin/bash
export ENV=`hostname | sed 's/\([a-z]*\)-\([0-9.]*\)-\(.*\)/\1-\2/'`
export MMHA1IP=`getent hosts $ENV-mm-ha-1 | awk '{ print $1 }'`
export MMHA2IP=`getent hosts $ENV-mm-ha-2 | awk '{ print $1 }'`

#prereq
sudo apt-get update -y
sudo apt-get upgrade -y

#Install haproxy
sudo apt-get install haproxy -y

#Configure haproxy
sudo cat <<EOF > /etc/haproxy/haproxy.cfg
global
	log /dev/log	local0
	log /dev/log	local1 notice
	chroot /var/lib/haproxy
	stats socket /run/haproxy/admin.sock mode 660 level admin
	stats timeout 30s
	user haproxy
	group haproxy
	daemon

	# Default SSL material locations
	ca-base /etc/ssl/certs
	crt-base /etc/ssl/private

	# Default ciphers to use on SSL-enabled listening sockets.
	# For more information, see ciphers(1SSL). This list is from:
	#  https://hynek.me/articles/hardening-your-web-servers-ssl-ciphers/
	ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS
	ssl-default-bind-options no-sslv3

defaults
	log	global
	mode	http
	option	httplog
	option	dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
	errorfile 400 /etc/haproxy/errors/400.http
	errorfile 403 /etc/haproxy/errors/403.http
	errorfile 408 /etc/haproxy/errors/408.http
	errorfile 500 /etc/haproxy/errors/500.http
	errorfile 502 /etc/haproxy/errors/502.http
	errorfile 503 /etc/haproxy/errors/503.http
	errorfile 504 /etc/haproxy/errors/504.http

frontend http_web
    bind *:80
    option forwardfor
    default_backend mattermost

backend mattermost
    balance roundrobin
    option httpchk
    server  mm-ha-1 $MMHA1IP:80 check
    server  mm-ha-2 $MMHA2IP:80 check
EOF
sudo systemctl enable haproxy
sudo systemctl start haproxy
sudo iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
sudo apt-get install iptables-persistent -y
iptables-save | sudo tee /etc/iptables/rules.v4
