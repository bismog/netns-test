#!/usr/bin/env bash

# This script came from http://plasmixs.github.io/network-namespaces-ovs.html
#
# +---------------+                                            +---------------+
# | ns1           |                                            | ns2           |
# | +----------+  |  +-------+    +------------+    +---+---+  |  +----------+ |
# | | vnspeer1 +--+--+  vns1 +----+    br0     +----+ vns2  +--+--+ vnspeer2 | |
# | +----------+  |  +-------+    +------------+    +---+---+  |  +----------+ |
# | 192.168.1.100 |                 ovs bridge                 | 192.168.1.200 |
# |               |                                            |               |
# +---------------+                                            +---------------+
#

# Remove legacy resources
ip netns del ns1
ip netns del ns2
ovs-vsctl del-br br0

# Create two network namespaces
ip netns add ns1
ip netns add ns2

# Create ovs bridge
ovs-vsctl add-br br0

# Create veth interfaces
ip link add vns1 type veth peer name vpeerns1
ip link add vns2 type veth peer name vpeerns2

# Set netns of veth interfaces
ip link set dev vpeerns1 netns ns1
ip link set dev vpeerns2 netns ns2

# Add port to ovs bridge
ovs-vsctl add-port br0 vns1
ovs-vsctl add-port br0 vns2

# Configure IP address
ip netns exec ns1 ip addr add 192.168.1.100/24 dev vpeerns1
ip netns exec ns2 ip addr add 192.168.1.200/24 dev vpeerns2

# Setup interfaces up
ip link set vns1 up
ip link set vns2 up
ip netns exec ns1 ip link set vpeerns1 up
ip netns exec ns2 ip link set vpeerns2 up

# Enable ip forward
sysctl -w net.ipv4.ip_forward=1

# Test ping
ip netns exec ns1 ping 192.168.1.200 -c 1
ip netns exec ns2 ping 192.168.1.100 -c 1

