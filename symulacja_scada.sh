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

    # Inicjalizacja magazynu danych z 2 rejestrami i 2 cewkami
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [17, 18]),  # dwa rejestry input
        co=ModbusSequentialDataBlock(0, [True, False]),  # dwie cewki
        hr=ModbusSequentialDataBlock(0, [100, 200]),  # dwa rejestry holding
        ir=ModbusSequentialDataBlock(0, [10, 20]))  # dwa rejestry input
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
        # Zapis wartości do pierwszej cewki (adres 0)
        client.write_coil(0, True)
        log.debug(f"Written coil at 0: True")

        # Zapis wartości do pierwszego rejestru holding (adres 0)
        client.write_register(0, 100)
        log.debug(f"Written register at 0: 100")

        # Odczyt cewki (adres 0)
        rr_coils = client.read_coils(0, 1)
        if rr_coils.isError():
            log.error(f"Error reading coil at 0")
        else:
            log.debug(f"Read coil at 0: {rr_coils.bits[0]}")

        # Odczyt rejestru holding (adres 0)
        rr_regs = client.read_holding_registers(0, 1)
        if rr_regs.isError():
            log.error(f"Error reading register at 0")
        else:
            log.debug(f"Read register at 0: {rr_regs.registers[0]}")

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
