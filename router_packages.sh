#!/bin/bash

# Modify this list to include any other packages you feel you require.

pacman -Sy --noconfirm \
firewalld \
unbound \
expat \
kea \
networkmanager 

# Copy the zone configs over

cd zones
cp WAN.xml /etc/firewalld/zones/
cp LAN.xml /etc/firewalld/zones/
cd ..

# Enable IPv4 forwarding

echo "net.ipv4.ip_forward=1" | tee /etc/sysctl.d/ip_forward.conf

# Enable the services - reboot required

systemctl enable firewalld
systemctl enable NetworkManager

