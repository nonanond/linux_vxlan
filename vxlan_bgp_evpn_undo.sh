#!/bin/bash

#./teardown.sh --lo-ip 172.16.1.2 --vni 200 --host-iface enp8s0

set -e

# === PARSE ARGUMENTS ===
while [[ $# -gt 0 ]]; do
  case $1 in
    --lo-ip)     LO_IP="$2"; shift ;;
    --vni)       VXLAN_VNI="$2"; shift ;;
    --host-iface) HOST_IFACE="$2"; shift ;;
    *) echo "❌ Okänd parameter: $1"; exit 1 ;;
  esac
  shift
done

VXLAN_IFACE="vxlan${VXLAN_VNI}"
BRIDGE_NAME="br${VXLAN_VNI}"

echo "🧹 Börjar rensa..."

ip link set ${HOST_IFACE} nomaster 2>/dev/null || true
ip link set ${VXLAN_IFACE} nomaster 2>/dev/null || true

if ip link show "$VXLAN_IFACE" &>/dev/null; then
    echo "➖ Tar bort $VXLAN_IFACE"
    ip link set ${VXLAN_IFACE} down
    ip link del ${VXLAN_IFACE}
fi

if ip link show "$BRIDGE_NAME" &>/dev/null; then
    echo "➖ Tar bort $BRIDGE_NAME"
    ip link set ${BRIDGE_NAME} down
    ip link del ${BRIDGE_NAME}
fi

if ip addr show lo | grep -q "${LO_IP}"; then
    echo "➖ Tar bort loopback IP ${LO_IP}"
    ip addr del ${LO_IP}/32 dev lo
fi

echo "🧽 Rensar FRR-konfig..."
sudo tee /etc/frr/frr.conf > /dev/null <<EOF
frr defaults traditional
hostname vtep
no ipv6 forwarding
log syslog informational
service integrated-vtysh-config
EOF

sudo chown frr:frr /etc/frr/frr.conf
sudo chmod 640 /etc/frr/frr.conf

echo "🔁 Startar om FRR..."
sudo systemctl restart frr

echo "✅ Systemet är rent!"
