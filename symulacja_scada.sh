#!/bin/bash
set -x

function cleanup {
    echo "Czyszczenie konfiguracji..."
    ip netns pids ns_server | xargs kill -9 2>/dev/null
    ip netns pids ns_client_modbus | xargs kill -9 2>/dev/null
    ip netns pids ns_client_s7 | xargs kill -9 2>/dev/null

    ip netns exec ns_server ip link set ens37 netns 1 2>/dev/null
    ip link set ens37 up 2>/dev/null
    ip addr flush dev ens37 2>/dev/null

    ip netns exec ns_client_modbus ip link set ens38 netns 1 2>/dev/null
    ip link set ens38 up 2>/dev/null
    ip addr flush dev ens38 2>/dev/null

    ip netns exec ns_client_modbus ip link set br0 down 2>/dev/null
    ip netns exec ns_client_modbus brctl delbr br0 2>/dev/null

    ip link delete veth_s7_br type veth 2>/dev/null
    ip link delete veth_s7 type veth 2>/dev/null

    ip netns delete ns_server 2>/dev/null
    ip netns delete ns_client_modbus 2>/dev/null
    ip netns delete ns_client_s7 2>/dev/null

    echo "Konfiguracja wyczyszczona."
}

trap cleanup EXIT

# Tworzenie przestrzeni nazw
ip netns add ns_server
ip netns add ns_client_modbus
ip netns add ns_client_s7

# Przeniesienie interfejsów fizycznych do przestrzeni nazw
ip link set ens37 netns ns_server
ip link set ens38 netns ns_client_modbus

# Konfiguracja interfejsu serwera
ip netns exec ns_server ip addr add 192.168.81.10/24 dev ens37
ip netns exec ns_server ip link set ens37 up

# Konfiguracja interfejsu klienta Modbus
ip netns exec ns_client_modbus ip link set ens38 up

# Tworzenie pary veth dla klienta S7
ip link add veth_s7_br type veth peer name veth_s7

# Przeniesienie interfejsów do odpowiednich przestrzeni nazw
ip link set veth_s7_br netns ns_client_modbus
ip link set veth_s7 netns ns_client_s7

# Konfiguracja interfejsu klienta S7
ip netns exec ns_client_s7 ip addr add 192.168.82.20/24 dev veth_s7
ip netns exec ns_client_s7 ip link set veth_s7 up

# Tworzenie mostu w ns_client_modbus
ip netns exec ns_client_modbus brctl addbr br0
ip netns exec ns_client_modbus brctl addif br0 ens38
ip netns exec ns_client_modbus brctl addif br0 veth_s7_br
ip netns exec ns_client_modbus ip link set br0 up
ip netns exec ns_client_modbus ip link set ens38 up
ip netns exec ns_client_modbus ip link set veth_s7_br up

# Przypisanie adresu IP do mostu
ip netns exec ns_client_modbus ip addr add 192.168.82.10/24 dev br0

# Uruchomienie serwera Modbus w ns_server
ip netns exec ns_server bash -c '
python3 -c "
from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext, ModbusSequentialDataBlock
store = ModbusSlaveContext(
    di=ModbusSequentialDataBlock(0, [17]*100),
    co=ModbusSequentialDataBlock(0, [17]*100),
    hr=ModbusSequentialDataBlock(0, [17]*100),
    ir=ModbusSequentialDataBlock(0, [17]*100))
context = ModbusServerContext(slaves=store, single=True)
StartTcpServer(context, address=(\"192.168.81.10\", 502))
" &' &
echo "Serwer Modbus uruchomiony"

# Uruchomienie serwera S7 w ns_server
ip netns exec ns_server bash -c '
python3 -c "
import time
from snap7.server import Server as S7Server
server = S7Server()
server.start(tcpport=102)
while True:
    time.sleep(1)
" &' &
echo "Serwer S7 uruchomiony"

# Czekamy chwilę, aby serwery się uruchomiły
sleep 5

# Uruchomienie klienta Modbus w ns_client_modbus
ip netns exec ns_client_modbus bash -c '
python3 -c "
import random
import time
from pymodbus.client.sync import ModbusTcpClient
client = ModbusTcpClient(\"192.168.81.10\", port=502)
client.connect()
try:
    while True:
        value = random.randint(10, 20)
        client.write_register(1, value)
        response = client.read_holding_registers(1, 1)
        print(f\"Modbus Client: Wrote and Read Value {response.registers[0]}\")
        time.sleep(5)
finally:
    client.close()
" &' &
echo "Klient Modbus uruchomiony"

# Uruchomienie klienta S7 w ns_client_s7
ip netns exec ns_client_s7 bash -c '
python3 -c "
import time
import random
from snap7.client import Client as S7Client
client = S7Client()
client.connect(\"192.168.81.10\", 0, 1, 102)
data = bytearray([0]*10)
try:
    while True:
        value = random.randint(10, 20)
        data[0] = value
        client.db_write(1, 0, data)
        read_data = client.db_read(1, 0, 1)
        print(f\"S7 Client: Wrote and Read Value {read_data[0]}\")
        time.sleep(5)
finally:
    client.disconnect()
" &' &
echo "Klient S7 uruchomiony"

# Utrzymanie skryptu aktywnego
wait
