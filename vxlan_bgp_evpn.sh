#!/bin/bash

# ./setup.sh --lo-ip 172.16.1.2 --peer-ip 172.16.2.2 --asn 65001 --vni 200 --wan-iface enp7s0 --host-iface enp8s0

set -e

# === PARSE ARGUMENTS ===
while [[ $# -gt 0 ]]; do
  case $1 in
    --lo-ip)       MY_LOOPBACK_IP="$2"; shift ;;
    --peer-ip)     PEER_LOOPBACK_IP="$2"; shift ;;
    --asn)         MY_ASN="$2"; shift ;;
    --vni)         VXLAN_VNI="$2"; shift ;;
    --wan-iface)   WAN_IFACE="$2"; shift ;;
    --host-iface)  HOST_IFACE="$2"; shift ;;
    *) echo "❌ Okänd parameter: $1"; exit 1 ;;
  esac
  shift
done

# === DEFAULTS ===
VXLAN_IFACE="vxlan${VXLAN_VNI}"
BRIDGE_NAME="br${VXLAN_VNI}"

echo "📦 Parametrar:"
echo "  Loopback:   $MY_LOOPBACK_IP"
echo "  Peer IP:    $PEER_LOOPBACK_IP"
echo "  ASN:        $MY_ASN"
echo "  VNI:        $VXLAN_VNI"
echo "  WAN iface:  $WAN_IFACE"
echo "  HOST iface: $HOST_IFACE"

echo "🔍 Kollar om FRR är installerat..."
if ! command -v vtysh >/dev/null 2>&1; then
    echo "📦 FRR saknas — installerar..."
    sudo apt update
    sudo apt install -y frr frr-pythontools
else
    echo "✅ FRR redan installerat"
fi

echo "🧪 Säkerställer att bgpd och ospfd är aktiverade i /etc/frr/daemons"
sudo sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sudo sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons

# === SETUP ===
echo "🔧 Sätter loopback IP..."
ip addr add ${MY_LOOPBACK_IP}/32 dev lo 2>/dev/null || echo "⏩ Redan satt"
ip link set lo up

echo "🔧 Skapar bridge: $BRIDGE_NAME"
ip link add ${BRIDGE_NAME} type bridge 2>/dev/null || echo "⏩ Finns redan"
ip link set ${BRIDGE_NAME} up

echo "🔧 Skapar VXLAN interface: $VXLAN_IFACE"
ip link add ${VXLAN_IFACE} type vxlan id ${VXLAN_VNI} dstport 4789 local ${MY_LOOPBACK_IP} nolearning 2>/dev/null || echo "⏩ Finns redan"
ip link set ${VXLAN_IFACE} master ${BRIDGE_NAME}
ip link set ${VXLAN_IFACE} up

echo "🔧 Kopplar ${HOST_IFACE} till ${BRIDGE_NAME}"
ip link set ${HOST_IFACE} up
ip link set ${HOST_IFACE} master ${BRIDGE_NAME}

echo "📝 Skriver FRR-konfiguration..."
sudo tee /etc/frr/frr.conf > /dev/null <<EOF
frr defaults traditional
hostname vtep
no ipv6 forwarding
log syslog informational
service integrated-vtysh-config
!
interface lo
 ip address ${MY_LOOPBACK_IP}/32
!
router ospf
 router-id ${MY_LOOPBACK_IP}
 network $(ip -4 addr show ${WAN_IFACE} | grep inet | awk '{print $2}') area 0
!
router bgp ${MY_ASN}
 bgp router-id ${MY_LOOPBACK_IP}
 neighbor ${PEER_LOOPBACK_IP} remote-as ${MY_ASN}
 neighbor ${PEER_LOOPBACK_IP} update-source lo
 !
 address-family l2vpn evpn
  neighbor ${PEER_LOOPBACK_IP} activate
  advertise-all-vni
 exit-address-family
!
EOF

sudo chown frr:frr /etc/frr/frr.conf
sudo chmod 640 /etc/frr/frr.conf

echo "🔁 Startar om FRR..."
sudo systemctl restart frr

echo "✅ Klar! VTEP är nu konfigurerad med OSPF, iBGP EVPN, VXLAN och bridge."
