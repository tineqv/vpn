cat > /tmp/install.sh << 'EOF'
#!/bin/bash
apt update && apt install -y wireguard iptables
sysctl -w net.ipv4.ip_forward=1
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
cd /etc/wireguard
umask 077
SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo $SERVER_PRIV | wg pubkey)
cat > wg0.conf << INNEREOF
[Interface]
Address = 10.0.0.1/24
PrivateKey = $SERVER_PRIV
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
INNEREOF
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
echo "========================================="
echo "✅ Публичный ключ сервера: $SERVER_PUB"
echo "🌐 IP сервера: $(curl -s ifconfig.me)"
echo "🔌 Порт: 51820"
echo "========================================="
EOF

chmod +x /tmp/install.sh
/tmp/install.sh
