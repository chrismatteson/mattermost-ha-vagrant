#!/bin/bash
export ENV=`hostname | sed 's/\([a-z]*\)-\([0-9]*\)-\(.*\)/\1\2/'`

/vagrant/scripts/$ENV-haproxy.sh
