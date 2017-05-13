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
sudo cat <<EOF > /etc/firewalld/services/haproxy-http.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
<short>HAProxy-HTTP</short>
<description>HAProxy load-balancer</description>
<port protocol="tcp" port="80"/>
</service>
EOF
sudo restorecon /etc/firewalld/services/haproxy-http.xml
sudo chmod 640 /etc/firewalld/services/haproxy-http.xml

sudo cat <<EOF > /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Example configuration for a possible web application.  See the
# full configuration options online.
#
#   http://haproxy.1wt.eu/download/1.4/doc/configuration.txt
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    #
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    #
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

#---------------------------------------------------------------------
# main frontend which proxys to the backends
#---------------------------------------------------------------------
frontend  main *:5000
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    default_backend             app

#---------------------------------------------------------------------
# static backend for serving up images, stylesheets and such
#---------------------------------------------------------------------
backend static
    balance     roundrobin
    server      static 127.0.0.1:4331 check

#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend app
    balance     roundrobin
    server  app1 127.0.0.1:5001 check
    server  app2 127.0.0.1:5002 check
    server  app3 127.0.0.1:5003 check
    server  app4 127.0.0.1:5004 check

frontend http_web *:80
    mode http
    default_backend mattermost

backend mattermost
    balance roundrobin
    mode http
    server  mm-ha-1 $MMHA1IP:80 check
    server  mm-ha-2 $MMHA2IP:80 check
EOF
sudo sed -i '/ENABLED/c\ENABLED=1' /etc/default/haproxy
sudo service haproxy start
sudo iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
sudo apt-get install iptables-persistent -y
iptables-save | sudo tee /etc/iptables/rules.v4
