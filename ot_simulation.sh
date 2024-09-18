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

# Numer IP zaczyna się od 2 (zakładamy, że 1 jest zajęte przez klienta)
ip_counter=2

# 1. Tworzenie przestrzeni nazw i konfiguracja interfejsów
for ns in "${!nodes[@]}"; do
  # Tworzenie przestrzeni nazw
  ip netns add "$ns"

  # Tworzenie pary interfejsów veth
  veth_host="veth_host_$ns"
  veth_ns="veth_ns_$ns"
  ip link add "$veth_host" type veth peer name "$veth_ns"

  # Przeniesienie jednego końca veth do przestrzeni nazw
  ip link set "$veth_ns" netns "$ns"

  # Konfiguracja interfejsu w przestrzeni nazw
  ip netns exec "$ns" ip addr add "${base_ip}${ip_counter}/24" dev "$veth_ns"
  ip netns exec "$ns" ip link set "$veth_ns" up
  ip netns exec "$ns" ip link set lo up

  # Konfiguracja interfejsu po stronie hosta
  ip link set "$veth_host" up

  # Dodanie trasy routingu w przestrzeni nazw
  ip netns exec "$ns" ip route add default via "${base_ip}1"

  # Zwiększenie licznika IP
  ((ip_counter++))
done

# Konfiguracja interfejsu po stronie hosta (klient)
host_if="ens37"
ip addr flush dev "$host_if"
ip addr add "${base_ip}1/24" dev "$host_if"
ip link set "$host_if" up

# Włączenie przekazywania IP
echo "Włączanie przekazywania IP..."
sysctl -w net.ipv4.ip_forward=1

# Konfiguracja iptables do przekazywania ruchu (opcjonalnie)
iptables -P FORWARD ACCEPT

# 2. Tworzenie skryptów serwerów dla protokołów
for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  port=${protocols[$protocol]}
  veth_ns="veth_ns_$ns"
  ip_ns=$(ip netns exec "$ns" ip -4 addr show "$veth_ns" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  echo "Tworzenie serwera dla protokołu $protocol w $ns..."

  case $protocol in
    "modbus")
      # Tworzenie skryptu serwera Modbus (bez zmian)
      # ...
      ;;
    "iec104")
      # Tworzenie skryptu serwera IEC104 (bez zmian)
      # ...
      ;;
    "s7")
      # Tworzenie skryptu serwera S7 (bez zmian)
      # ...
      ;;
    "ntp")
      # Konfiguracja serwera NTP (bez zmian)
      # ...
      ;;
    "vnc")
      # Instalacja i konfiguracja serwera VNC w przestrzeni nazw
      ip netns exec "$ns" bash -c "
      apt-get update
      apt-get install -y xfce4 xfce4-goodies tightvncserver

      # Ustawienie hasła VNC (domyślnie 'vncpassword', możesz zmienić)
      mkdir -p /root/.vnc
      echo 'vncpassword' | vncpasswd -f > /root/.vnc/passwd
      chmod 600 /root/.vnc/passwd

      # Tworzenie pliku startup dla VNC
      cat > /root/.vnc/xstartup << EOF
#!/bin/sh
xrdb \$HOME/.Xresources
startxfce4 &
EOF
      chmod +x /root/.vnc/xstartup

      # Uruchomienie serwera VNC
      vncserver :1 -geometry 1024x768 -depth 16
      "
      ;;
    *)
      echo "Nieznany protokół: $protocol"
      ;;
  esac
done

# 3. Tworzenie skryptów klienta na hoście
echo "Tworzenie klientów na hoście..."

for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  port=${protocols[$protocol]}
  veth_ns="veth_ns_$ns"
  ip_ns=$(ip netns exec "$ns" ip -4 addr show "$veth_ns" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  echo "Tworzenie klienta dla protokołu $protocol..."

  case $protocol in
    "modbus")
      # Tworzenie skryptu klienta Modbus (bez zmian)
      # ...
      ;;
    "iec104")
      # Tworzenie skryptu klienta IEC104 (bez zmian)
      # ...
      ;;
    "s7")
      # Tworzenie skryptu klienta S7 (bez zmian)
      # ...
      ;;
    "ntp")
      # Tworzenie skryptu klienta NTP (bez zmian)
      # ...
      ;;
    "vnc")
      # Skrypt do uruchomienia klienta VNC (vncviewer)
      echo "#!/bin/bash
vncviewer $ip_ns:1 -passwd <(echo 'vncpassword')
" > client_$protocol.sh
      chmod +x client_$protocol.sh
      ;;
    *)
      echo "Nieznany protokół: $protocol"
      ;;
  esac
done

# 4. Instalacja zależności w przestrzeniach nazw
echo "Instalacja zależności w przestrzeniach nazw..."
for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  case $protocol in
    "modbus")
      ip netns exec "$ns" pip3 install pymodbus
      ;;
    "iec104")
      # Zależności IEC104 (bez zmian)
      # ...
      ;;
    "s7")
      # Zależności S7 (bez zmian)
      # ...
      ;;
    "ntp")
      # NTP jest usługą systemową
      ;;
    "vnc")
      # Zależności zostały zainstalowane podczas konfiguracji serwera VNC
      ;;
  esac
done

# 5. Instalacja zależności na hoście
echo "Instalacja zależności na hoście..."
for protocol in "${nodes[@]}"; do
  case $protocol in
    "modbus")
      pip3 install pymodbus
      ;;
    "iec104")
      # Zależności IEC104 (bez zmian)
      # ...
      ;;
    "s7")
      # Zależności S7 (bez zmian)
      # ...
      ;;
    "ntp")
      # NTP klient jest wbudowany w system
      ;;
    "vnc")
      # Instalacja klienta VNC
      apt-get install -y tigervnc-viewer
      ;;
  esac
done

# 6. Uruchomienie serwerów w przestrzeniach nazw
echo "Uruchamianie serwerów w przestrzeniach nazw..."
for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  case $protocol in
    "ntp")
      # NTP serwer jest usługą systemową i już działa
      ;;
    "vnc")
      # Serwer VNC został uruchomiony podczas konfiguracji
      ;;
    *)
      ip netns exec "$ns" bash -c "python3 server_$protocol.py &"
      ;;
  esac
done

# 7. Uruchomienie klientów na hoście
echo "Uruchamianie klientów na hoście..."
for protocol in "${nodes[@]}"; do
  case $protocol in
    "ntp")
      bash -c "./client_$protocol.sh &"
      ;;
    "vnc")
      bash -c "./client_$protocol.sh &"
      ;;
    *)
      bash -c "python3 client_$protocol.py &"
      ;;
  esac
done

echo "Symulacja protokołów OT jest uruchomiona."
echo "Aby zatrzymać symulację, użyj polecenia 'pkill -f client_' i 'pkill -f server_'"

# 8. Opcjonalne: Monitorowanie ruchu
echo ""
echo "Aby monitorować ruch, użyj polecenia 'tcpdump' na interfejsach veth lub $host_if."
