#!/bin/bash

cp kea-dhcp4.conf /etc/kea/
systemctl enable --now kea-dhcp4
