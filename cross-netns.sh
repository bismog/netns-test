#!/usr/bin/env bash

# This script came from https://segmentfault.com/a/1190000004059167

#                   +--------------+
#                   | nstest       |
#   +--------+      |  +--------+  |
#   | veth-a +------+--+ veth-b |  |
#   +--------+      |  +--------+  |
#   10.0.0.1        |  10.0.0.2    |
#                   +--------------+


# Create a network namespace
ip netns add nstest

# Set interface lo up
ip netns exec nstest ip link set dev lo up
ip netns exec nstest ip link

# Create a pair of veth interfaces
ip link add veth-a type veth peer name veth-b

# Add one into namespace
ip link set veth-b netns nstest

# Set interfaces up
ip addr add 10.0.0.1/24 dev veth-a
ip link set dev veth-a up
ip netns exec nstest ip addr add 10.0.0.2/24 dev veth-b
ip netns exec nstest ip link set dev veth-b up

# Test ping
ping 10.0.0.2 -c 3
ip netns exec nstest ping 10.0.0.1 -c 3


