#!/bin/sh
INTIF="enp0s20f0u5u3u1"

EXTIF="enp0s31f6"

/sbin/depmod -a

/sbin/modprobe ip_tables

/sbin/modprobe ip_conntrack

/sbin/modprobe ip_conntrack_ftp

/sbin/modprobe ip_conntrack_irc

/sbin/modprobe iptable_nat

/sbin/modprobe ip_nat_ftp

iptables -P INPUT ACCEPT

iptables -F INPUT

iptables -P OUTPUT ACCEPT

iptables -F OUTPUT

iptables -P FORWARD DROP

iptables -F FORWARD

iptables -t nat -F

iptables -A FORWARD -i $EXTIF -o $INTIF -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -i $INTIF -o $EXTIF -j ACCEPT

iptables -t nat -A POSTROUTING -o $EXTIF -j MASQUERADE

