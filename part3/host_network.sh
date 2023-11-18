#!/bin/sh
sudo ip link add br0 type bridge
sudo ip addr add 192.168.100.50/24 brd 192.168.100.255 dev br0
sudo ip tuntap add mode tap user $(whoami)
sudo ip link set tap0 master br0
sudo ip link set dev br0 up
sudo ip link set dev tap0 up
