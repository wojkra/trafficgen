#!/bin/bash

# Upewnij się, że skrypt jest uruchamiany z uprawnieniami root
if [ "$EUID" -ne 0 ]; then
  echo "Proszę uruchomić skrypt jako root (sudo)."
  exit 1
fi

echo "Konfiguracja przestrzeni nazw sieciowych i interfejsów..."

# 1. Stworzenie dwóch przestrzeni nazw sieciowych
ip netns add ns1
ip netns add ns2

# 2. Utworzenie pary interfejsów veth
ip link add veth0 type veth peer name veth1

# 3. Przeniesienie interfejsów veth do przestrzeni nazw
ip link set veth0 netns ns1
ip link set veth1 netns ns2

# 4. Konfiguracja interfejsu w przestrzeni nazw ns1
ip netns exec ns1 ip addr add 192.168.81.1/24 dev veth0
ip netns exec ns1 ip link set veth0 up
ip netns exec ns1 ip link set lo up

# 5. Konfiguracja interfejsu w przestrzeni nazw ns2
ip netns exec ns2 ip addr add 192.168.2.1/24 dev veth1
ip netns exec ns2 ip link set veth1 up
ip netns exec ns2 ip link set lo up

# 6. Sprawdzenie stanu interfejsów
echo "Interfejsy w ns1:"
ip netns exec ns1 ip addr show veth0
echo ""
echo "Interfejsy w ns2:"
ip netns exec ns2 ip addr show veth1
echo ""

# 7. Informacje dla użytkownika
echo "Konfiguracja zakończona."
echo ""
echo "Aby przetestować połączenie, użyj następujących poleceń:"
echo "Ping z ns1 do ns2:"
echo "sudo ip netns exec ns1 ping 192.168.2.1"
echo ""
echo "Ping z ns2 do ns1:"
echo "sudo ip netns exec ns2 ping 192.168.81.1"
echo ""
echo "Aby uruchomić serwer Modbus w ns2, użyj:"
echo "sudo ip netns exec ns2 python3 modbus_server.py"
echo ""
echo "Aby uruchomić klienta Modbus w ns1, użyj:"
echo "sudo ip netns exec ns1 python3 modbus_client.py"
