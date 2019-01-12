#!/usr/bin/env bash


# This scripts came from http://tinkering-is-fun.blogspot.com/2016/01/building-ethernet-tap-with-linux.html


#  +--------------+  +-------------------------------------+  +--------------+
#  | eth_a        |  | eth_tap                             |  | eth_b        |
#  |  +--------+  |  |  +------------+     +------------+  |  |  +--------+  |
#  |  | veth_a +--+--+--+ veth_a_tap +--+--+ veth_b_tap +--+--+--+ s-veth |  |
#  |  +--------+  |  |  +------------+  |  +------------+  |  |  +--------+  |
#  |  88:...:00   |  |                  |                  |  |  88:...:01   |
#  +--------------+  |           +------+-------+          |  +--------------+
#                    |           | veth_tap_tap |          |
#                    |           +------+-------+          |
#                    |                  |                  |
#                    +------------------+------------------+
#                                       |
#                                +------+-------+
#                                |   veth_tap   |
#                                +--------------+
#

# Create the network namespaces
ip netns add eth_a
ip netns add eth_b
ip netns add eth_tap


# Add the virtual ethernet devices
ip link add veth_a type veth peer name veth_a_tap
ip link add veth_b type veth peer name veth_b_tap
ip link add veth_tap type veth peer name veth_tap_tap

# Set MAC addresses to make later packet capture easy
ip link set dev veth_a addr 88:00:00:00:00:00
ip link set dev veth_b addr 88:00:00:00:00:01

# Move the virtual ethernet interfaces into the appropriate namespaces
ip link set veth_a netns eth_a
ip link set veth_b netns eth_b
ip link set veth_a_tap netns eth_tap
ip link set veth_b_tap netns eth_tap
ip link set veth_tap_tap netns eth_tap

# Set interface UP
ip netns exec eth_a ip link set dev veth_a up
ip netns exec eth_b ip link set dev veth_b up
ip netns exec eth_tap ip link set dev veth_a_tap up
ip netns exec eth_tap ip link set dev veth_b_tap up
ip netns exec eth_tap ip link set dev veth_tap_tap up
ip link set dev veth_tap up

# Now we can prepare packet sniffer on veth_a, veth_b, veth_tap, or as your
# will veth_a_tap, veth_b_tap, veth_tap_tap
# For example, spawn more windows or panes via tmux or screen utils, and 
# setup packet capture in each window or pane, like:
# ip netns exec eth_a tcpdump -i veth_a
# or 
# ip netns exec eth_a wireshark -i veth_a
# And you can do more the same on veth_b, veth_tap, and so on.
# Run a shot as follow on veth_a and wait...
# > ip netns exec eth_a ether-wake -i veth_a 88:00:00:00:00:01
# As you will find, no packet can be captured on any interface other than 
# veth_a yet so far.
# Continue ...

# Now configure the tap node to do the actual port mirroring.
# Direction from the node A to the node B:

ip netns exec eth_tap tc qdisc add dev veth_a_tap ingress
ip netns exec eth_tap tc filter add \
    dev veth_a_tap \
    parent ffff: \
    protocol all \
    u32 match u8 0 0 \
    action mirred egress mirror dev veth_b_tap \
    action mirred egress mirror dev veth_tap_tap

# Run a shot and wait:
ip netns exec eth_a ether-wake -i veth_a 88:00:00:00:00:01

# You will find packet captured on veth_tap and veth_b as wished
# Run another shot and wait:
ip netns exec eth_b ether-wake -i veth_b 88:00:00:00:00:00

# Ooh, still no luck, for we have not setup port mirroring in eth_tap
# Then setup them...
# Direction from B to A:

ip netns exec eth_tap tc qdisc add dev veth_b_tap ingress
ip netns exec eth_tap tc filter add \
    dev veth_b_tap \
    parent ffff: \
    protocol all \
    u32 match u8 0 0 \
    action mirred egress mirror dev veth_a_tap \
    action mirred egress mirror dev veth_tap_tap

# Run a shot again:
ip netns exec eth_a ether-wake -i veth_a 88:00:00:00:00:01

# Run another shot again:
ip netns exec eth_b ether-wake -i veth_b 88:00:00:00:00:00

# Do you find the packets captured? Wish you good luck!


