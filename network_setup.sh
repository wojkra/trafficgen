#!/bin/bash

# Upewnij się, że skrypt jest uruchamiany z uprawnieniami root
if [ "$EUID" -ne 0 ]; then
  echo "Proszę uruchomić skrypt jako root (sudo)."
  exit 1
fi

# Konfiguracja interfejsów sieciowych
echo "Konfiguracja interfejsów sieciowych..."

# Konfiguracja ens37
ip addr flush dev ens37
ip addr add 192.168.81.1/24 dev ens37
ip link set ens37 up

# Konfiguracja ens38
ip addr flush dev ens38
ip addr add 192.168.2.1/24 dev ens38
ip link set ens38 up

# Włączenie przekazywania IP
echo "Włączanie przekazywania IP..."
sysctl -w net.ipv4.ip_forward=1

# Upewnienie się, że przekazywanie IP jest włączone przy starcie systemu
if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

# Dodanie tras routingu (nie jest konieczne w tym przypadku, ponieważ interfejsy są bezpośrednio podłączone)

# Dodanie reguł iptables do przekazywania pakietów między interfejsami
echo "Konfiguracja iptables..."

# Usunięcie istniejących reguł
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

# Ustawienie polityki akceptacji dla łańcuchów INPUT, FORWARD i OUTPUT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Włączenie przekierowania pakietów między interfejsami
iptables -A FORWARD -i ens37 -o ens38 -j ACCEPT
iptables -A FORWARD -i ens38 -o ens37 -j ACCEPT

# Maskarada (jeśli potrzebna)
# Jeśli chcesz użyć NAT, odkomentuj poniższą linię
# iptables -t nat -A POSTROUTING -o ens38 -j MASQUERADE

echo "Konfiguracja zakończona."
