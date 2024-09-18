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

# 2. Przeniesienie interfejsów fizycznych do odpowiednich przestrzeni nazw
ip link set ens37 netns ns1
ip link set ens38 netns ns2

# 3. Konfiguracja interfejsu w przestrzeni nazw ns1 (ens37)
ip netns exec ns1 ip addr flush dev ens37
ip netns exec ns1 ip addr add 192.168.81.1/24 dev ens37
ip netns exec ns1 ip link set ens37 up
ip netns exec ns1 ip link set lo up

# 4. Konfiguracja interfejsu w przestrzeni nazw ns2 (ens38)
ip netns exec ns2 ip addr flush dev ens38
ip netns exec ns2 ip addr add 192.168.2.1/24 dev ens38
ip netns exec ns2 ip link set ens38 up
ip netns exec ns2 ip link set lo up

# 5. Umożliwienie komunikacji między przestrzeniami nazw (opcjonalnie)
# Możemy utworzyć mostek sieciowy lub użyć pary interfejsów veth, ale ponieważ używamy fizycznych interfejsów,
# ruch między nimi powinien przechodzić przez fizyczną sieć (vSwitch na ESXi)

# 6. Sprawdzenie stanu interfejsów w przestrzeniach nazw
echo "Interfejsy w ns1:"
ip netns exec ns1 ip addr show ens37
echo ""
echo "Interfejsy w ns2:"
ip netns exec ns2 ip addr show ens38
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
