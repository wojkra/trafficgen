#!/usr/bin/env python3
import subprocess
import threading
import time
import random
import signal
import sys
from pymodbus.server.sync import StartTcpServer
from pymodbus.device import ModbusDeviceIdentification
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
from pymodbus.client.sync import ModbusTcpClient
from scapy.all import IP, TCP, send

# Konfiguracja
BRIDGE_NAME = "br1"  # Zmieniona nazwa mostu
SERVER_NS = "server_ns"
CLIENT_NS = "client_ns"
VETH_CLIENT_BRIDGE = "veth-client-br"
VETH_CLIENT_NS = "veth-client-ns"
VETH_SERVER_BRIDGE = "veth-server-br"
VETH_SERVER_NS = "veth-server-ns"

# Adresy IP
SERVER_IP = "192.168.81.1/24"
CLIENT_MODBUS_IP = "192.168.82.10/24"
CLIENT_S7_IP = "192.168.82.20/24"

# Porty
MODBUS_SERVER_PORT = 502  # Możesz zmienić na 1502, jeśli nie chcesz uruchamiać jako root
S7_SERVER_PORT = 102

# Rejestr Modbus
REGISTER_ADDRESS = 100

# Funkcja do uruchamiania poleceń systemowych
def run_command(cmd):
    try:
        subprocess.run(cmd, check=True, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        print(f"Błąd podczas wykonywania polecenia: {cmd}")
        print(e.stderr.decode())
        cleanup()
        sys.exit(1)

# Funkcja do czyszczenia poprzedniej konfiguracji
def initial_cleanup():
    print("Czyszczenie poprzedniej konfiguracji...")
    namespaces = [SERVER_NS, CLIENT_NS]
    for ns in namespaces:
        run_command(f"ip netns delete {ns} || true")
    interfaces = [VETH_CLIENT_BRIDGE, VETH_CLIENT_NS, VETH_SERVER_BRIDGE, VETH_SERVER_NS]
    for iface in interfaces:
        run_command(f"ip link delete {iface} || true")
    run_command(f"ip link delete {BRIDGE_NAME} || true")

# Funkcja do tworzenia przestrzeni nazw
def create_namespace(ns_name):
    run_command(f"ip netns add {ns_name}")

# Funkcja do usuwania przestrzeni nazw
def delete_namespace(ns_name):
    run_command(f"ip netns delete {ns_name}")

# Funkcja do tworzenia par veth
def create_veth(veth1, veth2):
    run_command(f"ip link add {veth1} type veth peer name {veth2}")

# Funkcja do przypisywania veth do przestrzeni nazw
def set_veth_namespace(veth, ns_name):
    run_command(f"ip link set {veth} netns {ns_name}")

# Funkcja do ustawiania adresów IP i włączania interfejsów
def setup_interface(ns_name, interface, ip_address):
    run_command(f"ip netns exec {ns_name} ip addr add {ip_address} dev {interface}")
    run_command(f"ip netns exec {ns_name} ip link set {interface} up")

# Funkcja do włączania interfejsów veth w mostu
def set_interface_up_global(interface):
    run_command(f"ip link set {interface} up")

# Funkcja do tworzenia mostu
def create_bridge(bridge_name):
    run_command(f"ip link add name {bridge_name} type bridge")

# Funkcja do usuwania mostu
def delete_bridge(bridge_name):
    run_command(f"ip link delete {bridge_name} || true")

# Funkcja do dodawania interfejsów do mostu
def add_to_bridge(bridge_name, interface):
    run_command(f"ip link set {interface} master {bridge_name}")

# Funkcja do konfiguracji trasowania
def setup_routing():
    run_command("sysctl -w net.ipv4.ip_forward=1")

# Funkcja do czyszczenia konfiguracji
def cleanup():
    print("Czyszczenie konfiguracji...")
    delete_namespace(SERVER_NS)
    delete_namespace(CLIENT_NS)
    run_command(f"ip link delete {VETH_CLIENT_BRIDGE} || true")
    run_command(f"ip link delete {VETH_SERVER_BRIDGE} || true")
    delete_bridge(BRIDGE_NAME)
    sys.exit(0)

# Obsługa sygnałów dla czyszczenia
signal.signal(signal.SIGINT, lambda sig, frame: cleanup())
signal.signal(signal.SIGTERM, lambda sig, frame: cleanup())

# Funkcja uruchamiająca serwer Modbus
def run_modbus_server_ns():
    # Inicjalizacja datastore
    store = ModbusSlaveContext(
        hr=ModbusSequentialDataBlock(0, [0]*1000)
    )
    context = ModbusServerContext(slaves=store, single=True)

    # Tożsamość Serwera
    identity = ModbusDeviceIdentification()
    identity.VendorName = 'OpenAI'
    identity.ProductCode = 'SCADA_SIM'
    identity.VendorUrl = 'http://openai.com'
    identity.ProductName = 'SCADA Modbus Server'
    identity.ModelName = 'Modbus Server'
    identity.MajorMinorRevision = '1.0'

    server_ip = SERVER_IP.split('/')[0]
    print(f"[server_ns] Uruchamianie serwera Modbus na {server_ip}:{MODBUS_SERVER_PORT}")
    StartTcpServer(context, identity=identity, address=(server_ip, MODBUS_SERVER_PORT))

# Funkcja uruchamiająca klienta Modbus
def run_modbus_client_ns():
    client = ModbusTcpClient("192.168.81.1", port=MODBUS_SERVER_PORT, source_address=("192.168.82.10", 0))
    if not client.connect():
        print("[client_ns] Nie udało się połączyć klienta Modbus z serwerem")
        return
    print("[client_ns] Klient Modbus połączony z 192.168.81.1:{} z adresu 192.168.82.10".format(MODBUS_SERVER_PORT))

    while True:
        # Generowanie losowej wartości między 10 a 20
        value = random.randint(10, 20)
        # Zapis rejestru
        write = client.write_register(REGISTER_ADDRESS, value, unit=1)
        if write.isError():
            print(f"[client_ns] Błąd zapisu Modbus: {write}")
        else:
            print(f"[client_ns] Modbus Zapis: Rejestr {REGISTER_ADDRESS} ustawiony na {value}")

        # Odczyt rejestru
        read = client.read_holding_registers(REGISTER_ADDRESS, 1, unit=1)
        if read.isError():
            print(f"[client_ns] Błąd odczytu Modbus: {read}")
        else:
            read_value = read.registers[0]
            print(f"[client_ns] Modbus Odczyt: Rejestr {REGISTER_ADDRESS} ma wartość {read_value}")

        time.sleep(5)

# Funkcja uruchamiająca symulację S7
def run_s7_simulation_ns():
    while True:
        # Tworzenie prostego pakietu S7 (Placeholder)
        s7_packet = IP(src="192.168.82.20", dst="192.168.81.1")/TCP(sport=random.randint(1000, 50000), dport=S7_SERVER_PORT)/b'\x03\x00\x00\x16\x11\xe0\x00\x00\x00\x08\x00\x01\x02\x01\x00\x00\x00\x00'

        # Wysyłanie pakietu
        send(s7_packet, verbose=False)
        print(f"[server_ns] Pakiet S7 wysłany z 192.168.82.20 do 192.168.81.1:{S7_SERVER_PORT}")

        time.sleep(5)

# Główna funkcja konfigurująca sieć i uruchamiająca serwer oraz klienta
def main():
    # Czyszczenie poprzedniej konfiguracji
    initial_cleanup()

    # Tworzenie mostu
    create_bridge(BRIDGE_NAME)
    run_command(f"ip link set {BRIDGE_NAME} up")
    print(f"Most {BRIDGE_NAME} utworzony i włączony.")

    # Tworzenie przestrzeni nazw
    create_namespace(SERVER_NS)
    create_namespace(CLIENT_NS)

    # Tworzenie par veth dla klienta
    create_veth(VETH_CLIENT_BRIDGE, VETH_CLIENT_NS)
    set_veth_namespace(VETH_CLIENT_NS, CLIENT_NS)
    setup_interface(CLIENT_NS, VETH_CLIENT_NS, CLIENT_MODBUS_IP)
    setup_interface(CLIENT_NS, VETH_CLIENT_NS, CLIENT_S7_IP)
    set_interface_up_global(VETH_CLIENT_BRIDGE)
    add_to_bridge(BRIDGE_NAME, VETH_CLIENT_BRIDGE)

    # Tworzenie par veth dla serwera
    create_veth(VETH_SERVER_BRIDGE, VETH_SERVER_NS)
    set_veth_namespace(VETH_SERVER_NS, SERVER_NS)
    setup_interface(SERVER_NS, VETH_SERVER_NS, SERVER_IP)
    set_interface_up_global(VETH_SERVER_BRIDGE)
    add_to_bridge(BRIDGE_NAME, VETH_SERVER_BRIDGE)

    # Konfiguracja trasowania
    setup_routing()

    # Uruchomienie serwera Modbus w przestrzeni server_ns
    server_thread = threading.Thread(target=lambda: subprocess.run(
        f"ip netns exec {SERVER_NS} python3 -c \"from __main__ import run_modbus_server_ns; run_modbus_server_ns()\"",
        shell=True
    ))
    server_thread.start()

    # Uruchomienie symulacji S7 w przestrzeni server_ns
    s7_thread = threading.Thread(target=lambda: subprocess.run(
        f"ip netns exec {SERVER_NS} python3 -c \"from __main__ import run_s7_simulation_ns; run_s7_simulation_ns()\"",
        shell=True
    ))
    s7_thread.start()

    # Uruchomienie klienta Modbus w przestrzeni client_ns
    client_thread = threading.Thread(target=lambda: subprocess.run(
        f"ip netns exec {CLIENT_NS} python3 -c \"from __main__ import run_modbus_client_ns; run_modbus_client_ns()\"",
        shell=True
    ))
    client_thread.start()

    # Utrzymanie głównego wątku aktywnego
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        cleanup()

if __name__ == "__main__":
    main()
