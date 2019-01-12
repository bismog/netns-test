#!/usr/bin/env bash

# This script came from http://plasmixs.github.io/network-namespaces-ovs.html
#
# +-------------------+                                            +--------------------+
# | ns1               |                                            | ns2                |
# | +----------+      |  +-------+    +------------+    +---+---+  |  +----------+      |
# | | vpeerns1 +------+--+  vns1 +----+    br0     +----+ vns2  +--+--+ vpeerns2 |      |
# | +--+-------+      |  +-------+    +------------+    +---+---+  |  +--+-------+      |
# |    |              |                 ovs bridge                 |     |              |
# | +--+-----------+  |                                            |  +--+-----------+  |
# | | vpeerns1.100 |  |                                            |  | vpeerns2.200 |  |
# | +--------------+  |                                            |  +--------------+  |
# | vlan100,2.2.2.1   |                                            |  vlan200,2.2.2.2   |
# +-------------------+                                            +--------------------+
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

# Setup interfaces up
ip link set vns1 up
ip link set vns2 up
ip netns exec ns1 ip link set vpeerns1 up
ip netns exec ns2 ip link set vpeerns2 up

# Enable ip forward
sysctl -w net.ipv4.ip_forward=1

# Set VLAN 100 for one namespace and 200 for the other namespace
ip netns exec ns1 ip link add link vpeerns1 name vpeerns1.100 type vlan id 100
ip netns exec ns2 ip link add link vpeerns2 name vpeerns2.200 type vlan id 200

# Assign new IP for the VLAN interfaces
ip netns exec ns1 ip addr add 2.2.2.1/24 dev vpeerns1.100
ip netns exec ns2 ip addr add 2.2.2.2/24 dev vpeerns2.200

# Set VLAN interfaces up
ip netns exec ns1 ip link set vpeerns1.100 up
ip netns exec ns2 ip link set vpeerns2.200 up

# Test ping
ip netns exec ns1 ping 2.2.2.2 -I 2.2.2.1 -c 1 -W 2
ip netns exec ns2 ping 2.2.2.1 -I 2.2.2.2 -c 1 -W 2

# Get in_port of vns1 and vns2
vns1_ofport=$(ovs-vsctl list interface vns1 | grep -w ofport | awk -F ":" '{print $2}' | xargs)
vns2_ofport=$(ovs-vsctl list interface vns2 | grep -w ofport | awk -F ":" '{print $2}' | xargs)

# Remove default flow rule
ovs-ofctl del-flows br0

# Add flow rules on ovs bridge
ovs-ofctl add-flow br0 "in_port=$vns1_ofport,dl_vlan=100,actions=mod_vlan_vid=200,output:$vns2_ofport"
ovs-ofctl add-flow br0 "in_port=$vns2_ofport,dl_vlan=200,actions=mod_vlan_vid=100,output:$vns1_ofport"

# Test ping
ip netns exec ns1 ping 2.2.2.2 -I 2.2.2.1 -c 1 -W 2
ip netns exec ns2 ping 2.2.2.1 -I 2.2.2.2 -c 1 -W 2

