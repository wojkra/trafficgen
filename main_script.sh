#!/bin/bash

# Sprawdzenie uprawnień
if [ "$EUID" -ne 0 ]; then
  echo "Uruchom ten skrypt z uprawnieniami administratora (sudo)."
  exit
fi

# Zmienne
SERVER_NS="ns_server"
CLIENT_NS="ns_client"
SERVER_IP="192.168.81.1"
CLIENT_IP="192.168.80.1"
SERVER_GW="192.168.81.254"  # IP interfejsu ens37
CLIENT_GW="192.168.80.133"  # IP interfejsu ens36
MODBUS_PORT=5020

# Funkcja czyszcząca
cleanup() {
  echo "Czyszczenie konfiguracji..."
  ip netns del $SERVER_NS 2>/dev/null
  ip netns del $CLIENT_NS 2>/dev/null
}

# Pułapka na zakończenie skryptu
trap cleanup EXIT

cleanup

echo "Konfiguracja przestrzeni nazw sieciowych..."

# Tworzenie przestrzeni nazw
ip netns add $SERVER_NS
ip netns add $CLIENT_NS

# Przypisywanie interfejsów fizycznych do przestrzeni nazw
ip link set ens37 netns $SERVER_NS
ip link set ens36 netns $CLIENT_NS

# Konfiguracja interfejsu w przestrzeni nazw serwera
ip netns exec $SERVER_NS ip addr flush dev ens37
ip netns exec $SERVER_NS ip addr add $SERVER_IP/24 dev ens37
ip netns exec $SERVER_NS ip link set ens37 up
ip netns exec $SERVER_NS ip route add default via $SERVER_GW

# Konfiguracja interfejsu w przestrzeni nazw klienta
ip netns exec $CLIENT_NS ip addr flush dev ens36
ip netns exec $CLIENT_NS ip addr add $CLIENT_IP/24 dev ens36
ip netns exec $CLIENT_NS ip link set ens36 up
ip netns exec $CLIENT_NS ip route add default via $CLIENT_GW

# Włączenie przekazywania IP na hoście
sysctl -w net.ipv4.ip_forward=1

# Ustawienie reguł iptables dla przekazywania ruchu
iptables -t nat -A POSTROUTING -o ens37 -j MASQUERADE
iptables -t nat -A POSTROUTING -o ens36 -j MASQUERADE
iptables -A FORWARD -i ens36 -o ens37 -j ACCEPT
iptables -A FORWARD -i ens37 -o ens36 -j ACCEPT

echo "Uruchamianie serwera Modbus w przestrzeni nazw $SERVER_NS..."
ip netns exec $SERVER_NS python3 modbus_server.py &

echo "Uruchamianie klienta Modbus w przestrzeni nazw $CLIENT_NS..."
ip netns exec $CLIENT_NS python3 modbus_client.py &

echo "Wszystko gotowe. Naciśnij Ctrl+C, aby zakończyć."

wait
