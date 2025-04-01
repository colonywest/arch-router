#!/bin/bash

# Sanity check...

lan=$(nmcli con show LAN)
wan=$(nmcli con show WAN)

abort_early=0
if [ -z "$lan" ]; then
    abort_early=1
fi

if [ -z "$wan" ]; then
    abort_early=1
fi

if [ $abort_early == 1 ]; then
    echo
    echo Aborting...
    exit
fi

# Set the IP address to match the subnet you intend to use, or
# stick with what I've chosen here.

nmcli con mod LAN ipv4.addresses "192.168.1.1/24"
nmcli con mod LAN ipv4.method manual
nmcli con mod LAN connection.autoconnect yes

# Set the firewall zones

nmcli con mod LAN connection.zone LAN
nmcli con mod WAN connection.zone WAN

