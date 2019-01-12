#!/usr/bin/env bash

# Note: Don't configure IP address on peer veth interface

#
#
# +---------------+                                                  +---------------+
# | ns0           |                                                  | ns1           |
# | +----------+  |  +----------+    +------------+    +---+------+  |  +----------+ |
# | |   tap0   +--+--+  tap0_br +----+  vswitch0  +----+ tap1_br  +--+--+   tap1   | |
# | +----------+  |  +----------+    +------------+    +---+------+  |  +----------+ |
# | 192.168.1.100 |                    ovs bridge                    | 192.168.1.101 |
# |               |                                                  |               |
# +---------------+                                                  +---------------+


# Remove legacy resources
ip netns del ns0
ip netns del ns1
ovs-vsctl del-br vswitch0

# Create two network namespaces
ip netns add ns0
ip netns add ns1

# Create ovs bridge
ovs-vsctl add-br vswitch0

# Create veth interfaces
ip link add tap0 type veth peer name tap0_br
ip link add tap1 type veth peer name tap1_br

# Set netns of veth interfaces
ip link set dev tap0 netns ns0
ip link set dev tap1 netns ns1

# Add port to ovs bridge
ovs-vsctl add-port vswitch0 tap0_br
# ovs-vsctl set interface tap0_br type=internal
ovs-vsctl add-port vswitch0 tap1_br
# ovs-vsctl set interface tap1_br type=internal

# Configure IP address
ip netns exec ns0 ip addr add 192.168.1.100/24 dev tap0
ip netns exec ns1 ip addr add 192.168.1.101/24 dev tap1
# ip addr add 192.168.1.200/24 dev tap0_br
# ip addr add 192.168.1.201/24 dev tap1_br

# Setup interfaces up
ip netns exec ns0 ip link set tap0 up
ip netns exec ns1 ip link set tap1 up
ip link set tap0_br up
ip link set tap1_br up

# Test ping
ip netns exec ns0 ping 192.168.1.101 -c 1
ip netns exec ns1 ping 192.168.1.100 -c 1
