#!/usr/bin/env python3

import subprocess
import threading
import random
import time
from pymodbus.server.sync import StartTcpServer
from pymodbus.client.sync import ModbusTcpClient
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
import snap7
from snap7.server import Server as S7Server
from snap7.client import Client as S7Client

# Funkcje pomocnicze do wykonywania poleceń systemowych
def run_cmd(cmd):
    subprocess.run(cmd, shell=True, check=True)

# Konfiguracja przestrzeni nazw i interfejsów sieciowych
def setup_network():
    # Tworzenie przestrzeni nazw
    run_cmd('ip netns add ns_server')
    run_cmd('ip netns add ns_client_modbus')
    run_cmd('ip netns add ns_client_s7')

    # Przeniesienie interfejsów do przestrzeni nazw
    run_cmd('ip link set ens37 netns ns_server')
    run_cmd('ip link set ens38 netns ns_client_modbus')

    # Konfiguracja adresów IP
    run_cmd('ip netns exec ns_server ip addr add 192.168.81.1/24 dev ens37')
    run_cmd('ip netns exec ns_server ip link set ens37 up')

    run_cmd('ip netns exec ns_client_modbus ip addr add 192.168.82.1/24 dev ens38')
    run_cmd('ip netns exec ns_client_modbus ip link set ens38 up')

    # Dodanie tras (jeśli konieczne)
    # run_cmd('ip netns exec ns_client_modbus ip route add default via 192.168.81.1')

    # Konfiguracja dla klienta S7 (użyjemy wirtualnego interfejsu)
    run_cmd('ip netns exec ns_client_modbus ip link add veth0 type veth peer name veth1')
    run_cmd('ip link set veth1 netns ns_client_s7')
    run_cmd('ip netns exec ns_client_modbus ip addr add 192.168.82.2/24 dev veth0')
    run_cmd('ip netns exec ns_client_modbus ip link set veth0 up')
    run_cmd('ip netns exec ns_client_s7 ip addr add 192.168.83.1/24 dev veth1')
    run_cmd('ip netns exec ns_client_s7 ip link set veth1 up')

# Funkcje serwera i klienta Modbus
def modbus_server():
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [17]*100),
        co=ModbusSequentialDataBlock(0, [17]*100),
        hr=ModbusSequentialDataBlock(0, [17]*100),
        ir=ModbusSequentialDataBlock(0, [17]*100))
    context = ModbusServerContext(slaves=store, single=True)
    identity = None  # Możesz skonfigurować identyfikację serwera
    StartTcpServer(context, identity=identity, address=("192.168.81.1", 502))

def modbus_client():
    client = ModbusTcpClient('192.168.81.1', port=502)
    client.connect()
    try:
        while True:
            value = random.randint(10, 20)
            client.write_register(1, value)
            response = client.read_holding_registers(1, 1)
            print(f"Modbus Client: Wrote and Read Value {response.registers[0]}")
            time.sleep(5)
    finally:
        client.close()

# Funkcje serwera i klienta S7
def s7_server():
    server = S7Server()
    server.start(tcpport=102)
    while True:
        time.sleep(1)

def s7_client():
    client = S7Client()
    client.connect('192.168.81.1', 0, 1, 102)
    data = bytearray([0]*10)
    try:
        while True:
            value = random.randint(10, 20)
            data[0] = value
            client.db_write(1, 0, data)
            read_data = client.db_read(1, 0, 1)
            print(f"S7 Client: Wrote and Read Value {read_data[0]}")
            time.sleep(5)
    finally:
        client.disconnect()

# Funkcja główna
def main():
    setup_network()

    # Uruchomienie serwera Modbus w przestrzeni nazw ns_server
    modbus_server_thread = threading.Thread(target=lambda: subprocess.run(
        'ip netns exec ns_server python3 -c "from __main__ import modbus_server; modbus_server()"', shell=True))
    modbus_server_thread.start()

    # Uruchomienie klienta Modbus w przestrzeni nazw ns_client_modbus
    modbus_client_thread = threading.Thread(target=lambda: subprocess.run(
        'ip netns exec ns_client_modbus python3 -c "from __main__ import modbus_client; modbus_client()"', shell=True))
    modbus_client_thread.start()

    # Uruchomienie serwera S7 w przestrzeni nazw ns_server
    s7_server_thread = threading.Thread(target=lambda: subprocess.run(
        'ip netns exec ns_server python3 -c "from __main__ import s7_server; s7_server()"', shell=True))
    s7_server_thread.start()

    # Uruchomienie klienta S7 w przestrzeni nazw ns_client_s7
    s7_client_thread = threading.Thread(target=lambda: subprocess.run(
        'ip netns exec ns_client_s7 python3 -c "from __main__ import s7_client; s7_client()"', shell=True))
    s7_client_thread.start()

    # Dołączenie wątków
    modbus_server_thread.join()
    modbus_client_thread.join()
    s7_server_thread.join()
    s7_client_thread.join()

if __name__ == '__main__':
    main()
