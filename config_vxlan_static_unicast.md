# 0. Konfigurera Underlay (WAN-gränssnittet)
sudo ip addr add 172.16.1.2/24 dev enp7s0  		# Sätt Underlay-IP på WAN-gränssnittet
sudo ip link set enp7s0 up                 		# Aktivera WAN-gränssnittet
sudo ip route add default via 172.16.1.1 dev enp7s0  	# Sätt default gateway (ersätt 172.16.1.1 med din router-IP)

# 1. Skapa VXLAN-gränssnitt
sudo ip link add vxlan100 type vxlan \
    id 100 \                  # VNI (VXLAN Network Identifier)
    dstport 4789 \            # Standardport för VXLAN
    local 172.16.1.2 \        # Underlay-IP (VTEP1:s WAN-adress)
    nolearning \              # Inaktivera MAC-inlärning (använd statiska peers)
    dev enp7s0                # Fysiskt WAN-gränssnitt

# 2. Lägg till VTEP2 (underlay-IP 172.16.2.2) som statisk peer 
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan100 dst 172.16.2.2

# 3. Lägg till VTEP3 (underlay-IP 172.16.3.2) som statisk peer 
sudo bridge fdb append 00:00:00:00:00:00 dev vxlan100 dst 172.16.3.2

# 4. Skapa en bridge för overlay-nätverket
sudo ip link add br100 type bridge

# 5. Koppla VXLAN och LAN-gränssnitt till bridgen
sudo ip link set vxlan100 master br100    # VXLAN-tunnel → bridge
sudo ip link set enp8s0 master br100     # Lokalt LAN → bridge

# 6. Rensa alla IP-adresser från enp8s0 (för att undvika konflikter med br100)
sudo ip addr flush dev enp8s0 2>/dev/null || true

# 7. Sätt overlay-IP på bridgen (virtuellt nätverk)
sudo ip addr add 192.168.1.1/24 dev br100

# 8. Aktivera alla gränssnitt
sudo ip link set vxlan100 up
sudo ip link set enp8s0 up
sudo ip link set br100 up

# 9. Aktivera IP-forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward