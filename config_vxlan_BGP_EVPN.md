# Sniffa VXLAN-trafik
sudo tcpdump -i enp7s0 udp port 4789

# Sniffa BGP-trafik
sudo tcpdump -i enp7s0 port 179 -nn -v

# Verify OSPF is up
sudo vtysh -c "show ip ospf neighbor"

# Verify BGP sessions
sudo vtysh -c "show bgp l2vpn evpn summary"

# Check EVPN routes
sudo vtysh -c "show bgp l2vpn evpn"

# Check VXLAN bridge and FDB
bridge fdb show | grep vxlan

# Ping between hosts
ping 192.168.1.12

# Use tcpdump to watch VXLAN traffic
sudo tcpdump -i enp7s0 udp port 4789




# Installera FRRouting
sudo apt install frr

# Aktivera OSPF och BGP
sudo sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sudo sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons

# Aktivera IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Sätt WAN interface
sudo ip addr add 172.16.1.2/24 dev enp7s0
sudo ip link set dev enp7s0 up

# Sätt loopback IP
sudo ip addr add 172.16.1.2/32 dev lo

# Skapa bridge
sudo ip addr add br200 type bridge
sudo ip link set br200 up

# Skapa VXLAN
sudo ip link add vxlan200 type vxlan id 200 dstport 4789 local 172.16.1.2 nolearning
sudo ip link set vxlan200 up

# Koppla host-interface och vxlan-interface till bridgen
sudo ip link set vxlan200 master br200
sudo ip link set enp8s0 master br200

# Konfigurera OSPF och BGP EVPN
sudo vtysh
conf t

interface lo
 ip address 172.16.1.2/32
exit
!
router bgp 65001
 bgp router-id 172.16.1.2
 neighbor 172.16.2.2 remote-as 65001
 neighbor 172.16.2.2 update-source lo
 neighbor 172.16.3.2 remote-as 65001
 neighbor 172.16.3.2 update-source lo
 !
 address-family l2vpn evpn
  neighbor 172.16.2.2 activate
  neighbor 172.16.3.2 activate
  advertise-all-vni
 exit-address-family
exit
!
router ospf
 ospf router-id 172.16.1.2
 network 172.16.1.0/24 area 0

# Starta om FRR
sudo systemctl restart frr
