#!/bin/bash

# Copy the unbound.conf file and create the unbound.conf.d directory

cp unbound.conf /etc/unbound
mkdir /etc/unbound/unbound.conf.d/

# Grab the latest DNSSEC keys

unbound-anchor
cp /etc/trusted-key.key /etc/unbound/


# Grab the latest list of root DNS servers

./update_hints.sh

# Setup unbound-control and start the service

unbound-control-setup
systemctl enable --now unbound
