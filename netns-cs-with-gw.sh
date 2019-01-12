#!/usr/bin/env bash

# This script came from https://segmentfault.com/a/1190000004059167

#  +--------------+  +----------------------------------+  +----------------+
#  | client       |  | gateway                          |  | server         |
#  |  +--------+  |  |  +---------+    +---------+      |  |  +--------+    |
#  |  | c-veth +--+--+--+ cg-veth +----+ sg-veth +------+--+--+ s-veth |    |
#  |  +--------+  |  |  +---------+    +---------+      |  |  +--------+    |
#  |  10.0.100.1  |  |  10.0.100.254   192.168.100.254  |  |  192.168.100.1 |
#  +--------------+  +----------------------------------+  +----------------+
#

# Remove legacy resources
ip netns del client
ip netns del gateway
ip netns del server

# Create network namespaces
ip netns add client
ip netns add gateway
ip netns add server

# Make sure ip forward is on
ip netns exec gateway sysctl net.ipv4.ip_forward=1

# Create two pairs of veth interfaces
ip link add s-veth type veth peer name sg-veth
ip link add c-veth type veth peer name cg-veth

# Setup namespace of interfaces
ip link set s-veth netns server
ip link set sg-veth netns gateway
ip link set c-veth netns client
ip link set cg-veth netns gateway

# Configure IP addresses
ip netns exec server ip addr add 192.168.100.1/24 dev s-veth
ip netns exec server ip link set dev s-veth up
ip netns exec gateway ip addr add 192.168.100.254/24 dev sg-veth
ip netns exec gateway ip link set dev sg-veth up
ip netns exec gateway ip addr add 10.0.100.254/24 dev cg-veth
ip netns exec gateway ip link set dev cg-veth up
ip netns exec client ip addr add 10.0.100.1/24 dev c-veth
ip netns exec client ip link set dev c-veth up

# Test ping from netns gateway
ip netns exec gateway ping 192.168.100.1 -I 192.168.100.254 -c 3
ip netns exec gateway ping 10.0.100.1 -I 10.0.100.254 -c 3

# Test ping from client to gateway or server
ip netns exec client ping 192.168.100.254 -I 10.0.100.1 -c 1  
ip netns exec client ping 192.168.100.1 -I 10.0.100.1 -c 1  

# Test ping from server to gateway or client
ip netns exec server ping 10.0.100.254 -I 192.168.100.1 -c 1
ip netns exec server ping 10.0.100.1 -I 192.168.100.1 -c 1

# Add default router in client
ip netns exec client ip route add default via 10.0.100.254

# Retry
ip netns exec client ping 192.168.100.254 -I 10.0.100.1 -c 1  
ip netns exec client ping 192.168.100.1 -I 10.0.100.1 -c 1  

# Retry
ip netns exec server ping 10.0.100.254 -I 192.168.100.1 -c 1
ip netns exec server ping 10.0.100.1 -I 192.168.100.1 -c 1

# Add default router in server
ip netns exec server ip route add default via 192.168.100.254

# Final retry
ip netns exec client ping 192.168.100.254 -I 10.0.100.1 -c 1  
ip netns exec client ping 192.168.100.1 -I 10.0.100.1 -c 1  

# Final retry
ip netns exec server ping 10.0.100.254 -I 192.168.100.1 -c 1
ip netns exec server ping 10.0.100.1 -I 192.168.100.1 -c 1

