#!/usr/bin/env bash


# 
# 
# +------+    +---------+                                        +---------+    +------+
# | tap0 +----+ tap0_br +----+                              +----+ tap2_br +----+ tap2 |
# +------+    +---------+    |                              |    +---------+    +------+
#                            |                              |
#                        +---+---+    +------------+    +---+---+
#                        | bond0 +----+  vswitch0  +----+ bond1 |
#                        +---+---+    +------------+    +---+---+
#                            |                              |
# +------+    +---------+    |                              |    +---------+    +------+
# | tap1 +----+ tap1_br +----+                              +----+ tap3_br +----+ tap3 |
# +------+    +---------+                                        +---------+    +------+
# 

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
ip link add tap2 type veth peer name tap2_br
ip link add tap3 type veth peer name tap3_br

# Set netns of veth interfaces
ip link set dev tap0 netns ns0
ip link set dev tap1 netns ns0
ip link set dev tap2 netns ns1
ip link set dev tap3 netns ns1

# Create ovs bonding
ovs-vsctl add-bond vswitch0 bond0 tap0_br tap1_br lacp=active other_config:lacp-time=fast
ovs-vsctl add-bond vswitch0 bond1 tap2_br tap3_br lacp=active other_config:lacp-time=fast

# Configure IP address
ip netns exec ns0 ip addr add 192.168.1.100/24 dev tap0
ip netns exec ns0 ip addr add 192.168.1.101/24 dev tap1
ip netns exec ns1 ip addr add 192.168.1.102/24 dev tap2
ip netns exec ns1 ip addr add 192.168.1.103/24 dev tap3
# ip addr add 192.168.1.200/24 dev bond0
# ip addr add 192.168.1.201/24 dev bond1

echo <<EOF > /etc/sysconfig/network-scripts/ifcfg-bond0
DEVICE=bond0
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=vswitch0
BOOTPROTO=none
NM_CONTROLLED=yes
IPV6INIT=no
PEERDNS=no
ONBOOT=yes
IPADDR=192.168.1.200
NETMASK=255.255.255.0
EOF

echo <<EOF > /etc/sysconfig/network-scripts/ifcfg-bond1
DEVICE=bond1
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=vswitch0
BOOTPROTO=none
NM_CONTROLLED=yes
IPV6INIT=no
PEERDNS=no
ONBOOT=yes
IPADDR=192.168.1.201
NETMASK=255.255.255.0
EOF

# Setup interfaces up
ip netns exec ns0 ip link set tap0 up
ip netns exec ns0 ip link set tap1 up
ip netns exec ns1 ip link set tap2 up
ip netns exec ns1 ip link set tap3 up

# ip link set bond0 up
# ip link set bond1 up
systemctl disable NetworkManager.service
systemctl stop NetworkManager.service
systemctl start network.service



