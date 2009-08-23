#!/bin/sh

if [ -z $1 ] || [ -z $2 ] || [ -z $3 ] ; then
        echo "$0 <nat device> <output device> <network address>"
        exit
fi

iptables -t nat -N "$1"-NAT 2>/dev/null
iptables -t nat -F "$1"-NAT
iptables -t nat -D POSTROUTING -j "$1"-NAT 2>/dev/null
iptables -t nat -A POSTROUTING -j "$1"-NAT
iptables -t nat -D "$1"-NAT -j MASQUERADE 2>/dev/null
iptables -t nat -A "$1"-NAT -o "$2" -s "$3" -j MASQUERADE

# Testing : used for integration with nocat
iptables -N "$1"-FORWARD 2>/dev/null
iptables -F "$1"-FORWARD
iptables -D "$1"-FORWARD -j ACCEPT -s "$3" 2>/dev/null
iptables -A "$1"-FORWARD -j ACCEPT -s "$3"

iptables -D FORWARD -j "$1"-FORWARD -s "$3" 2>/dev/null
iptables -I FORWARD 1 -j "$1"-FORWARD -s "$3"

iptables -N "$1"-INBOUND 2>/dev/null
iptables -F "$1"-INBOUND
iptables -D "$1"-INBONUD -j ACCEPT -d "$3" 2>/dev/null
iptables -A "$1"-INBOUND -j ACCEPT -d "$3"

iptables -D FORWARD -j "$1"-INBOUND -d "$3" 2>/dev/null
iptables -I FORWARD 1 -j "$1"-INBOUND -d "$3"