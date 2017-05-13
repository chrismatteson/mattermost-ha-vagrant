# mattermost-ha-vagrant
Vagrant environment to build Mattermost in HA configuration

## Prereqs
This environment has been tested on Vagrant 1.9.0 and VirtualBox 5.1.14 on OSX 10.11.6. This environment utilizes the vagrant oscar plugin which can be installed with:

vagrant plugin install oscar

## Instructions
This repository can be used by:

1) Install virtualbox
2) Install vagrant
3) Install vagrant plugin oscar
 - vagrant plugin install oscar
4) Clone repository
 - git clone https://github.com/chrismatteson/mattermost-ha-vagrant
5) Place a mattermost license file in root of the repository named "license.mattermost-license"
6) Vagrant up a collection of VMs:
 - vagrant up /rhel-7/
 - vagrant up /rhel-6/
 - vagrant up /ubuntu-1404/
 - vagrant up /ubuntu-1604/
7) Login to ip address of haproxy server

## Configuration
Each set of three VMs is configured with:
1) HA Proxy which loadbalances between nginx on each mattermost node
2) Nginx on each node configured to proxy mattermost servers on both nodes
3) Mattermost installed on each node and configured with a trial license and utilizing HA
4) Mysql loaded on each node with only the first node being utilized

## Known Issues
1. In order to preserve the ability to dynamically assign ip addresses from vagrant, the nginx config includes dns entries for upstream instead of ip addresses. This potentially can result in nginx failing if both servers aren't up. Restarting nginx after the second server is up should resolve this issue.
2. In order to allow testing of all the components, firewall rules and access limitations are not locked down for any component. This would need to be resolved before placing these machines in production or on a public connection. Likewise SSL is not configured, but would need to be in production.
