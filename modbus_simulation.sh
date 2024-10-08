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
ip netns exec ns2 ip addr add 192.168.81.2/24 dev ens38
ip netns exec ns2 ip link set ens38 up
ip netns exec ns2 ip link set lo up

# 5. Sprawdzenie połączenia między przestrzeniami nazw
echo "Sprawdzanie połączenia między ns1 i ns2..."
ip netns exec ns1 ping -c 2 192.168.81.2

# 6. Tworzenie skryptu Modbus server w ns2
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
    log.setLevel(logging.DEBUG)

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

# 7. Tworzenie skryptu Modbus client w ns1
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
    log.setLevel(logging.DEBUG)

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
        log.debug(f"Written coil at {coil_addr}: {coil_value}")

        # Zapis losowej wartości do rejestru holding
        client.write_register(reg_addr, register_value)
        log.debug(f"Written register at {reg_addr}: {register_value}")

        # Odczyt cewek
        rr_coils = client.read_coils(coil_addr, 1)
        if rr_coils.isError():
            log.error(f"Error reading coils at {coil_addr}")
        else:
            log.debug(f"Read coil at {coil_addr}: {rr_coils.bits}")

        # Odczyt rejestrów holding
        rr_regs = client.read_holding_registers(reg_addr, 1)
        if rr_regs.isError():
            log.error(f"Error reading registers at {reg_addr}")
        else:
            log.debug(f"Read register at {reg_addr}: {rr_regs.registers}")

        # Odczekaj 1 sekundę
        time.sleep(1)

    client.close()

if __name__ == "__main__":
    run_client()
EOF'

# 8. Instalacja zależności w obu przestrzeniach nazw (jeśli nie są zainstalowane)
echo "Instalacja zależności Pythona (pymodbus)..."
ip netns exec ns1 bash -c 'pip3 install pymodbus'
ip netns exec ns2 bash -c 'pip3 install pymodbus'

# 9. Uruchomienie serwera Modbus w ns2
echo "Uruchamianie serwera Modbus w ns2..."
ip netns exec ns2 bash -c 'python3 modbus_server.py &'

# 10. Uruchomienie klienta Modbus w ns1
echo "Uruchamianie klienta Modbus w ns1..."
ip netns exec ns1 bash -c 'python3 modbus_client.py &'

echo "Symulacja Modbus jest uruchomiona."
echo "Aby zatrzymać symulację, użyj poleceń 'pkill -f modbus_server.py' i 'pkill -f modbus_client.py' w odpowiednich przestrzeniach nazw."

# 11. Opcjonalne: Monitorowanie ruchu na interfejsach
echo ""
echo "Aby monitorować ruch na interfejsie ens37 w ns1, użyj:"
echo "sudo ip netns exec ns1 tcpdump -i ens37 port 502 -nn -X"
echo ""
echo "Aby monitorować ruch na interfejsie ens38 w ns2, użyj:"
echo "sudo ip netns exec ns2 tcpdump -i ens38 port 502 -nn -X"
