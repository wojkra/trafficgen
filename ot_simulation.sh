#!/bin/bash

# Upewnij się, że skrypt jest uruchamiany z uprawnieniami root
if [ "$EUID" -ne 0 ]; then
  echo "Proszę uruchomić skrypt jako root (sudo)."
  exit 1
fi

echo "Konfiguracja przestrzeni nazw sieciowych i interfejsów..."

# Lista protokołów i odpowiadających im portów
declare -A protocols
protocols=(
  ["modbus"]=502
  ["iec104"]=2404
  ["s7"]=102
  ["ntp"]=123
  ["vnc"]=5901
)

# Lista węzłów (przestrzeni nazw) i przypisanych protokołów
declare -A nodes
nodes=(
  ["ns_modbus"]="modbus"
  ["ns_iec104"]="iec104"
  ["ns_s7"]="s7"
  ["ns_ntp"]="ntp"
  ["ns_vnc"]="vnc"
)

# Początkowy adres IP
base_ip="192.168.81."

# Numer IP zaczyna się od 2 (zakładamy, ż
