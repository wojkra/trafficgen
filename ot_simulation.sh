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
  ["dnp3"]=20000
  ["s7"]=102
)

# Lista węzłów (przestrzeni nazw) i przypisanych protokołów
declare -A nodes
nodes=(
  ["ns_modbus"]="modbus"
  ["ns_iec104"]="iec104"
  ["ns_dnp3"]="dnp3"
  ["ns_s7"]="s7"
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
  ip_ns=$(ip netns exec "$ns" ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  echo "Tworzenie skryptu serwera dla protokołu $protocol w $ns..."

  # Tworzenie skryptu serwera w przestrzeni nazw
  case $protocol in
    "modbus")
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
    "iec104")
      # Instalacja biblioteki pyIEC104 (jeśli dostępna)
      ip netns exec "$ns" pip3 install pyIEC104
      ip netns exec "$ns" bash -c "cat > server_$protocol.py << EOF
#!/usr/bin/env python3

from iec104.server import IEC104Server
import logging

def run_server():
    logging.basicConfig(level=logging.INFO)
    server = IEC104Server(address=('$ip_ns', $port))
    server.start()

if __name__ == '__main__':
    run_server()
EOF"
      ;;
    "dnp3")
      # Instalacja biblioteki pydnp3 (jeśli dostępna)
      ip netns exec "$ns" pip3 install pydnp3
      ip netns exec "$ns" bash -c "cat > server_$protocol.py << EOF
#!/usr/bin/env python3

from pydnp3 import opendnp3, asiodnp3, asiopal
import logging

def run_server():
    logging.basicConfig(level=logging.INFO)
    # Konfiguracja serwera DNP3 (szczegóły implementacji zależą od biblioteki)
    # Tu należy dodać kod uruchamiający serwer DNP3
    pass

if __name__ == '__main__':
    run_server()
EOF"
      ;;
    "s7")
      # Instalacja biblioteki snap7
      ip netns exec "$ns" pip3 install python-snap7
      ip netns exec "$ns" bash -c "cat > server_$protocol.py << EOF
#!/usr/bin/env python3

import snap7
from snap7.server import Server
import logging
import time

def run_server():
    logging.basicConfig(level=logging.INFO)
    server = Server()
    server.register_area(snap7.types.srvAreaDB, 1, bytearray(1024))
    server.start(tcpport=$port, address='$ip_ns')

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        server.stop()
        server.destroy()

if __name__ == '__main__':
    run_server()
EOF"
      ;;
    *)
      echo "Nieznany protokół: $protocol"
      ;;
  esac
done

# 3. Tworzenie skryptów klienta na hoście
echo "Tworzenie skryptów klienta na hoście..."

for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  port=${protocols[$protocol]}
  ip_ns=$(ip netns exec "$ns" ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

  echo "Tworzenie skryptu klienta dla protokołu $protocol..."

  case $protocol in
    "modbus")
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
    "iec104")
      # Instalacja biblioteki pyIEC104 (jeśli dostępna)
      pip3 install pyIEC104
      cat > client_$protocol.py << EOF
#!/usr/bin/env python3

from iec104.client import IEC104Client
import logging

def run_client():
    logging.basicConfig(level=logging.INFO)
    client = IEC104Client(address=('$ip_ns', $port))
    client.connect()
    client.send_interrogation_command()
    client.disconnect()

if __name__ == '__main__':
    run_client()
EOF
      ;;
    "dnp3")
      # Instalacja biblioteki pydnp3 (jeśli dostępna)
      pip3 install pydnp3
      cat > client_$protocol.py << EOF
#!/usr/bin/env python3

from pydnp3 import opendnp3, asiopal, asiodnp3
import logging

def run_client():
    logging.basicConfig(level=logging.INFO)
    # Konfiguracja klienta DNP3 (szczegóły implementacji zależą od biblioteki)
    # Tu należy dodać kod uruchamiający klienta DNP3
    pass

if __name__ == '__main__':
    run_client()
EOF
      ;;
    "s7")
      # Instalacja biblioteki python-snap7
      pip3 install python-snap7
      cat > client_$protocol.py << EOF
#!/usr/bin/env python3

import snap7
from snap7.client import Client
import logging
import time

def run_client():
    logging.basicConfig(level=logging.INFO)
    client = Client()
    client.connect('$ip_ns', 0, 1, $port)

    try:
        while True:
            data = client.db_read(1, 0, 10)
            logging.info(f"Read data: {data}")
            time.sleep(1)
    except KeyboardInterrupt:
        client.disconnect()

if __name__ == '__main__':
    run_client()
EOF
      ;;
    *)
      echo "Nieznany protokół: $protocol"
      ;;
  esac
done

# 4. Instalacja zależności Pythona w przestrzeniach nazw (serwery)
echo "Instalacja zależności Pythona w przestrzeniach nazw..."
for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  case $protocol in
    "modbus")
      ip netns exec "$ns" pip3 install pymodbus
      ;;
    "iec104")
      # Już zainstalowane podczas tworzenia skryptu
      ;;
    "dnp3")
      # Już zainstalowane podczas tworzenia skryptu
      ;;
    "s7")
      # Już zainstalowane podczas tworzenia skryptu
      ;;
  esac
done

# 5. Instalacja zależności Pythona na hoście (klienci)
echo "Instalacja zależności Pythona na hoście..."
for protocol in "${nodes[@]}"; do
  case $protocol in
    "modbus")
      pip3 install pymodbus
      ;;
    "iec104")
      # Już zainstalowane podczas tworzenia skryptu
      ;;
    "dnp3")
      # Już zainstalowane podczas tworzenia skryptu
      ;;
    "s7")
      # Już zainstalowane podczas tworzenia skryptu
      ;;
  esac
done

# 6. Uruchomienie serwerów w przestrzeniach nazw
echo "Uruchamianie serwerów w przestrzeniach nazw..."
for ns in "${!nodes[@]}"; do
  protocol=${nodes[$ns]}
  ip netns exec "$ns" bash -c "python3 server_$protocol.py &"
done

# 7. Uruchomienie klientów na hoście
echo "Uruchamianie klientów na hoście..."
for protocol in "${nodes[@]}"; do
  bash -c "python3 client_$protocol.py &"
done

echo "Symulacja protokołów OT jest uruchomiona."
echo "Aby zatrzymać symulację, użyj polecenia 'pkill -f client_' i 'pkill -f server_'"

# 8. Opcjonalne: Monitorowanie ruchu
echo ""
echo "Aby monitorować ruch, użyj polecenia 'tcpdump' na interfejsach veth lub $host_if."
