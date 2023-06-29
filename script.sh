#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
    echo "You must be root to run this script"
    exit 1
fi


BR_ADDR="10.10.0.1"
BR_DEV="br0"

NS1="ns1"
VETH1="veth1"
VPEER1="vpeer1"
VPEER_ADDR1="10.10.0.10"

NS2="ns2"
VETH2="veth2"
VPEER2="vpeer2"
VPEER_ADDR2="10.10.0.20"


# remove namespace if it exists.
ip netns del $NS1 &>/dev/null
ip netns del $NS2 &>/dev/null


# create namespace
ip netns add $NS1
ip netns add $NS2

# create veth link
ip link add ${VETH1} type veth peer name ${VPEER1}
ip link add ${VETH2} type veth peer name ${VPEER2}

# setup veth link
ip link set ${VETH1} up
ip link set ${VETH2} up

# add peers to ns
ip link set ${VPEER1} netns ${NS1}
ip link set ${VPEER2} netns ${NS2}

# setup loopback interface
ip netns exec ${NS1} ip link set lo up
ip netns exec ${NS2} ip link set lo up

# setup peer ns interface
ip netns exec ${NS1} ip link set ${VPEER1} up
ip netns exec ${NS2} ip link set ${VPEER2} up

# assign ip address to ns interfaces
ip netns exec ${NS1} ip addr add ${VPEER_ADDR1}/16 dev ${VPEER1}
ip netns exec ${NS2} ip addr add ${VPEER_ADDR2}/16 dev ${VPEER2}


# setup bridge
ip link add ${BR_DEV} type bridge
ip link set ${BR_DEV} up

# assign veth pairs to bridge
ip link set ${VETH1} master ${BR_DEV}
ip link set ${VETH2} master ${BR_DEV}

# this is for routing traffic outside the host otherwise we do not need to set an ip for bridge if and no default routes in namespaces are needed

# setup bridge ip
ip addr add ${BR_ADDR}/16 dev ${BR_DEV}

# add default routes for ns
ip netns exec ${NS1} ip route add default via ${BR_ADDR}
ip netns exec ${NS2} ip route add default via ${BR_ADDR}



# enable ip forwarding
bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'

# Flush nat rules.
iptables -t nat -F

iptables -t nat -A POSTROUTING -s ${BR_ADDR}/16 ! -o ${BR_DEV} -j MASQUERADE


# install python to run a webserver
apt -y update &&  apt -y install python 

# running a webserver inside ns1 namespace and trying to reach it from outside
ip netns exec ${NS1} python3 -m http.server 80 &

# add DNAT rule to PREROUTING chain so we can access the webserver from outside the host
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.10.0.10:80

# access the web server from the host (root net namespace)
iptables -t nat -A OUTPUT -p tcp --dport 8080 -j DNAT --to-destination 10.10.0.10:80 

iptables -t nat -A POSTROUTING -m addrtype --src-type LOCAL -o ${BR_DEV} -j MASQUERADE

sysctl -w net.ipv4.conf.${BR_DEV}.route_localnet=1

# add a dns server fo net namespaces
sh -c "mkdir -p /etc/netns/$NS1"
sh -c "mkdir -p /etc/netns/$NS2"
sh -c "echo 'nameserver 8.8.8.8' >> /etc/netns/${NS1}/resolv.conf;"
sh -c "echo 'nameserver 8.8.8.8' >> /etc/netns/${NS2}/resolv.conf;"



# to solve the problem of no response (request from NS2) when executing ip netns exec $NS2 curl 10.10.0.1:8080 , the problem is that dist of request is not the src of response so the response and request are not put in same tcp connection we have two options: 
# 1. activate hairpin NAT or 2. activate net.bridge.bridge-nf-call-iptables
# we will use second so iptables rules will be applied to packets going through virtual bridges. In this way, the reply packet will also go through the reverse operation of DNAT, and its source address will be corrected to match the destination of the request.
modprobe br_netfilter
sysctl -w net.bridge.bridge-nf-call-iptables=1



# to solve request from same namespace access (NS1) (ip netns exec  ns1 curl 10.10.0.1:8080)
# we have to activate Hairpin NAT mode since the option net.bridge.bridge-nf-call-iptables does not work for access from the same namespace since the reply does not even go through the bridge, 
iptables -t nat -A POSTROUTING -s 10.10.0.10 -d 10.10.0.10 -p tcp --dport 80 -j MASQUERADE

# when we try again still no response .When we connect to port 8080 on the host from ns1, the packets arrive br0 through interface veth1 and get routed back through the same interface by our DNAT rule. The bridge will reject such “going back” routing if veth1’s hairpin mode is not turned on. To turn it on:
ip link set veth1 type bridge_slave hairpin on







 