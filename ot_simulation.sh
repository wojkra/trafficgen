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
  ["vnc"]=5900
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

# Czyszczenie istniejących przestrzeni nazw i interfejsów
for ns in "${!nodes[@]}"; do
  ip netns delete "$ns" 2>/dev/null
  protocol=${nodes[$ns]}
  veth_host="veth_host_$protocol"
  ip link delete "$veth_host" 2>/dev/null
done

# 1. Tworzenie przestrzeni nazw i konfiguracja interfejsów
for ns in "${!nodes[@]}"; do
  # Pobranie nazwy protokołu
  protocol=${nodes[$ns]}
  
  # Tworzenie pary interfejsów veth z nazwami opartymi na protokole
  veth_host="veth_host_$protocol"
  veth_ns="veth_ns_$protocol"
  
  # Tworzenie przestrzeni nazw
  ip netns add "$ns"
  
  # Tworzenie pary interfejsów veth
  ip link add "$veth_host" type veth peer name "$veth_ns"
  
  # Przeniesienie jednego końca veth do przestrzeni nazw
  ip link set "$veth_ns" netns "$ns"
  
  # Konfiguracja interfejsu w przestrzeni nazw
  ip netns exec "$ns" ip addr add "${base_ip}${ip_counter}/24" dev "$veth_ns"
  ip netns exec "$ns" ip link set "$veth_ns" up
  ip netns exec "$ns" ip link set lo up
  
  # Konfiguracja interfejsu po stronie hosta
  ip link set "$veth_host" up
  
  # Dodanie trasy domyślnej w przestrzeni nazw
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
  veth_ns="veth_ns_$protocol"
  ip_ns=$(ip netns exec "$ns" ip -4 addr show "$veth_ns" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  
  echo "Tworzenie serwera dla protokołu $protocol w $ns..."

  # Tworzenie skryptu serwera w przestrzeni nazw
  case $protocol in
    "modbus")
      # Skrypt serwera Modbus
      ip netns exec "$ns" bash -c "cat > server_$protocol.py << EOF
#!/usr/bin/env python3

from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
from pymodbus.datastore import ModbusSequentialDataBlock
import logging
import sys

def run_server():
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [17]*100),
        co=ModbusSequentialDataBlock(0, [17]*100),
        hr=ModbusSequentialDataBlock(0, [17]*100),
        ir=ModbusSequentialDataBlock(0, [17]*100))
    context = ModbusServerContext(slaves=store, single=True)

    StartTcpServer(context, address=('$ip_ns', $port))

if __name__ == '__main__':
    run_server()
EOF"
      ;;
    "iec104"|"s7"|"ntp"|"vnc")
      # Symulacja serwera - generowanie sztucznego ruchu
      ip netns exec "$ns" bash -c "cat > server_$protocol.py << EOF
#!/usr/bin/env python3

import socket
import time

def simulate_server():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('$ip_ns', $port))
    s.listen(1)
    print('Symulacja serwera $protocol uruchomiona na $ip_ns:$port')
    conn, addr = s.accept()
    with conn:
        print('Połączenie od', addr)
        while True:
            data = conn.recv(1024)
            if not data:
                break
            # Symulujemy odpowiedź
            conn.sendall(data)
    s.close()

if __name__ == '__main__':
    simulate_server()
EOF"
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
  veth_ns="veth_ns_$protocol"
  ip_ns=$(ip netns exec "$ns" ip -4 addr show "$veth_ns" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  
  echo "Tworzenie klienta dla protokołu $protocol..."

  case $protocol in
    "modbus")
      # Skrypt klienta Modbus
      cat > client_$protocol.py << EOF
#!/usr/bin/env python3

from pymodbus.client.sync import ModbusTcpClient
import random
import time
import logging
import sys

def run_client():
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    client = ModbusTcpClient("$ip_ns", port=$port)
    client.connect()

    while True:
        coil_addr = random.randint(1, 10)
        coil_value = random.randint(0, 1)
        reg_addr = random.randint(1, 10)
        register_value = random.randint(0, 100)

        client.write_coil(coil_addr, coil_value)
        log.info(f"Written coil at {coil_addr}: {coil_value}")

        client.write_register(reg_addr, register_value)
        log.info(f"Written register at {reg_addr}: {register_value}")

        time.sleep(1)

    client.close()

if __name__ == "__main__":
    run_client()
EOF
      ;;
    "iec104"|"s7"|"ntp"|"vnc")
      # Symulacja klienta - generowanie sztucznego ruchu
      cat > client_$protocol.py << EOF
#!/usr/bin/env python3

import socket
import time

def simulate_client():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(('$ip_ns', $port))
    print('Połączono z symulowanym serwerem $protocol na $ip_ns:$port')
    try:
        while True:
            # Wysyłamy sztuczne dane
            s.sendall(b'Hello $protocol Server')
            data = s.recv(1024)
            print('Otrzymano:', data)
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    s.close()

if __name__ == '__main__':
    simulate_client()
EOF
      ;;
    *)
      echo "Nieznany protokół: $protocol"
      ;;
  esac
done

# 4. Uruchomienie serwerów w przestrzeniach nazw
echo "Uruchamianie serwerów w przestrzeniach nazw..."
for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  ip netns exec "$ns" bash -c "python3 server_$protocol.py &"
done

# 5. Uruchomienie klientów na hoście
echo "Uruchamianie klientów na hoście..."
for protocol in "${nodes[@]}"; do
  bash -c "python3 client_$protocol.py &"
done

echo "Symulacja protokołów OT jest uruchomiona."
echo "Aby zatrzymać symulację, użyj polecenia 'pkill -f client_' i 'pkill -f server_'"

# 6. Opcjonalne: Monitorowanie ruchu
echo ""
echo "Aby monitorować ruch, użyj polecenia 'tcpdump' na interfejsach veth lub $host_if."
