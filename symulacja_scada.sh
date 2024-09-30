#!/bin/bash

# Upewnij się, że skrypt jest uruchamiany z uprawnieniami root
if [ "$EUID" -ne 0 ]; then
  echo "Proszę uruchomić skrypt jako root (sudo)."
  exit 1
fi

echo "Konfiguracja przestrzeni nazw sieciowych i interfejsów..."

# 1. Stworzenie trzech przestrzeni nazw sieciowych
ip netns add ns1       # Modbus Client
ip netns add ns2       # Modbus Server & S7 Server
ip netns add ns3       # S7 Client

# 2. Przeniesienie interfejsów fizycznych do odpowiednich przestrzeni nazw
ip link set ens37 netns ns1
ip link set ens38 netns ns2
ip link set ens39 netns ns3   # Upewnij się, że masz interfejs ens39

# 3. Konfiguracja interfejsu w przestrzeni nazw ns1 (ens37)
ip netns exec ns1 ip addr flush dev ens37
ip netns exec ns1 ip addr add 192.168.81.1/24 dev ens37
ip netns exec ns1 ip link set ens37 up
ip netns exec ns1 ip link set lo up

# 4. Konfiguracja interfejsu w przestrzeni nazw ns2 (ens38)
ip netns exec ns2 ip addr flush dev ens38
ip netns exec ns2 ip addr add 192.168.81.2/24 dev ens38
ip netns exec ns2 ip link set ens38 up
ip netns exec ns2 ip link set lo up

# 5. Konfiguracja interfejsu w przestrzeni nazw ns3 (ens39)
ip netns exec ns3 ip addr flush dev ens39
ip netns exec ns3 ip addr add 192.168.81.3/24 dev ens39
ip netns exec ns3 ip link set ens39 up
ip netns exec ns3 ip link set lo up

# 6. Sprawdzenie połączenia między przestrzeniami nazw
echo "Sprawdzanie połączenia między ns1, ns2 i ns3..."
ip netns exec ns1 ping -c 2 192.168.81.2
ip netns exec ns1 ping -c 2 192.168.81.3
ip netns exec ns3 ping -c 2 192.168.81.2

# 7. Tworzenie skryptu Modbus server w ns2
echo "Tworzenie skryptu Modbus server..."
ip netns exec ns2 bash -c 'cat > modbus_server.py << EOF
#!/usr/bin/env python3

from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
from pymodbus.datastore import ModbusSequentialDataBlock
import logging
import sys

def run_server():
    # Konfiguracja logowania
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    # Inicjalizacja magazynu danych
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [17]*100),
        co=ModbusSequentialDataBlock(0, [17]*100),
        hr=ModbusSequentialDataBlock(0, [17]*100),
        ir=ModbusSequentialDataBlock(0, [17]*100))
    context = ModbusServerContext(slaves=store, single=True)

    # Uruchomienie serwera Modbus na 192.168.81.2, port 502
    StartTcpServer(context, address=("192.168.81.2", 502))

if __name__ == "__main__":
    run_server()
EOF'

# 8. Tworzenie skryptu Modbus client w ns1
echo "Tworzenie skryptu Modbus client..."
ip netns exec ns1 bash -c 'cat > modbus_client.py << EOF
#!/usr/bin/env python3

from pymodbus.client.sync import ModbusTcpClient
import random
import time
import logging
import sys

def run_client():
    # Konfiguracja logowania
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    # Połączenie z serwerem Modbus na 192.168.81.2, port 502
    client = ModbusTcpClient("192.168.81.2", port=502)
    client.connect()

    while True:
        # Generowanie losowych wartości
        coil_addr = random.randint(1, 10)
        coil_value = random.randint(0, 1)
        reg_addr = random.randint(1, 10)
        register_value = random.randint(0, 100)

        # Zapis losowej wartości do cewki
        client.write_coil(coil_addr, coil_value)
        log.info(f"Written coil at {coil_addr}: {coil_value}")

        # Zapis losowej wartości do rejestru holding
        client.write_register(reg_addr, register_value)
        log.info(f"Written register at {reg_addr}: {register_value}")

        # Odczyt cewek
        rr_coils = client.read_coils(coil_addr, 1)
        if rr_coils.isError():
            log.error(f"Error reading coils at {coil_addr}")
        else:
            log.info(f"Read coil at {coil_addr}: {rr_coils.bits}")

        # Odczyt rejestrów holding
        rr_regs = client.read_holding_registers(reg_addr, 1)
        if rr_regs.isError():
            log.error(f"Error reading registers at {reg_addr}")
        else:
            log.info(f"Read register at {reg_addr}: {rr_regs.registers}")

        # Odczekaj 1 sekundę
        time.sleep(1)

    client.close()

if __name__ == "__main__":
    run_client()
EOF'

# 9. Tworzenie skryptu S7 server w ns2
echo "Tworzenie skryptu S7 server..."
ip netns exec ns2 bash -c 'cat > s7_server.py << EOF
#!/usr/bin/env python3

import snap7
from snap7.server import Server
from snap7.util import *
import struct
import time
import logging
import sys

def run_server():
    # Konfiguracja logowania
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    server = Server()
    db = (ctypes.c_uint8 * 1024)()
    server.register_area(snap7.types.srvAreaDB, 1, db)
    server.start(tcpport=102)

    log.info("S7 Server started on 192.168.81.2:102")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        log.info("Stopping S7 Server...")
        server.stop()
        server.destroy()

if __name__ == "__main__":
    run_server()
EOF'

# 10. Tworzenie skryptu S7 client w ns3
echo "Tworzenie skryptu S7 client..."
ip netns exec ns3 bash -c 'cat > s7_client.py << EOF
#!/usr/bin/env python3

import snap7
from snap7.client import Client
from snap7.util import *
import time
import random
import logging
import sys

def run_client():
    # Konfiguracja logowania
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    client = Client()
    client.connect("192.168.81.2", 0, 1, 102)

    log.info("Connected to S7 Server at 192.168.81.2:102")

    db_number = 1
    start = 0
    size = 10

    try:
        while True:
            data_to_write = bytearray(random.getrandbits(8) for _ in range(size))
            client.db_write(db_number, start, data_to_write)
            log.info(f"Written to DB{db_number}: {list(data_to_write)}")

            data_read = client.db_read(db_number, start, size)
            log.info(f"Read from DB{db_number}: {list(data_read)}")

            time.sleep(1)
    except KeyboardInterrupt:
        log.info("Stopping S7 Client...")
    finally:
        client.disconnect()

if __name__ == "__main__":
    run_client()
EOF'

# 11. Instalacja zależności w przestrzeniach nazw (jeśli nie są zainstalowane)
echo "Instalacja zależności Pythona (pymodbus, python-snap7)..."
ip netns exec ns1 bash -c 'pip3 install pymodbus'
ip netns exec ns2 bash -c 'pip3 install pymodbus python-snap7'
ip netns exec ns3 bash -c 'pip3 install python-snap7'

# 12. Uruchomienie serwera Modbus w ns2
echo "Uruchamianie serwera Modbus w ns2..."
ip netns exec ns2 bash -c 'python3 modbus_server.py &' &

# 13. Uruchomienie klienta Modbus w ns1
echo "Uruchamianie klienta Modbus w ns1..."
ip netns exec ns1 bash -c 'python3 modbus_client.py &' &

# 14. Uruchomienie serwera S7 w ns2
echo "Uruchamianie serwera S7 w ns2..."
ip netns exec ns2 bash -c 'python3 s7_server.py &' &

# 15. Uruchomienie klienta S7 w ns3
echo "Uruchamianie klienta S7 w ns3..."
ip netns exec ns3 bash -c 'python3 s7_client.py &' &

echo "Symulacja Modbus i S7 jest uruchomiona."
echo "Aby zatrzymać symulację, użyj poleceń 'pkill -f modbus_server.py', 'pkill -f modbus_client.py', 'pkill -f s7_server.py' i 'pkill -f s7_client.py' w odpowiednich przestrzeniach nazw."

# 16. Opcjonalne: Monitorowanie ruchu na interfejsach
echo ""
echo "Aby monitorować ruch na interfejsie ens37 w ns1 (Modbus Client), użyj:"
echo "sudo ip netns exec ns1 tcpdump -i ens37 port 502 -nn -X"
echo ""
echo "Aby monitorować ruch na interfejsie ens38 w ns2 (Modbus & S7 Server), użyj:"
echo "sudo ip netns exec ns2 tcpdump -i ens38 'port 502 or port 102' -nn -X"
echo ""
echo "Aby monitorować ruch na interfejsie ens39 w ns3 (S7 Client), użyj:"
echo "sudo ip netns exec ns3 tcpdump -i ens39 port 102 -nn -X"
