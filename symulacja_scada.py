import threading
import time
import random
from pymodbus.server.sync import StartTcpServer
from pymodbus.device import ModbusDeviceIdentification
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
from pymodbus.client.sync import ModbusTcpClient
from scapy.all import IP, TCP, send

# Konfiguracja
MODBUS_SERVER_IP = "192.168.81.1"
MODBUS_SERVER_PORT = 502

MODBUS_CLIENT_IP = "192.168.82.10"
S7_CLIENT_IP = "192.168.82.20"

S7_SERVER_IP = "192.168.81.1"
S7_SERVER_PORT = 102  # Domyślny port S7

REGISTER_ADDRESS = 100

# Ustawienie Serwera Modbus
def run_modbus_server():
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

    print(f"Uruchamianie serwera Modbus na {MODBUS_SERVER_IP}:{MODBUS_SERVER_PORT}")
    StartTcpServer(context, identity=identity, address=(MODBUS_SERVER_IP, MODBUS_SERVER_PORT))

# Ustawienie Klienta Modbus
def run_modbus_client():
    client = ModbusTcpClient(MODBUS_SERVER_IP, port=MODBUS_SERVER_PORT, source_address=(MODBUS_CLIENT_IP, 0))
    if not client.connect():
        print("Nie udało się połączyć klienta Modbus z serwerem")
        return
    print(f"Klient Modbus połączony z {MODBUS_SERVER_IP}:{MODBUS_SERVER_PORT} z adresu {MODBUS_CLIENT_IP}")

    while True:
        # Generowanie losowej wartości między 10 a 20
        value = random.randint(10, 20)
        # Zapis rejestru
        write = client.write_register(REGISTER_ADDRESS, value, unit=1)
        if write.isError():
            print(f"Błąd zapisu Modbus: {write}")
        else:
            print(f"Modbus Zapis: Rejestr {REGISTER_ADDRESS} ustawiony na {value}")

        # Odczyt rejestru
        read = client.read_holding_registers(REGISTER_ADDRESS, 1, unit=1)
        if read.isError():
            print(f"Błąd odczytu Modbus: {read}")
        else:
            read_value = read.registers[0]
            print(f"Modbus Odczyt: Rejestr {REGISTER_ADDRESS} ma wartość {read_value}")

        time.sleep(5)

# Symulacja Ruchu S7
def run_s7_simulation():
    while True:
        # Tworzenie prostego pakietu S7 (To jest placeholder i nie reprezentuje rzeczywistego pakietu S7)
        # Poprawne tworzenie pakietów S7 wymaga przestrzegania specyfikacji protokołu
        s7_packet = IP(src=S7_CLIENT_IP, dst=S7_SERVER_IP)/TCP(sport=random.randint(1000, 50000), dport=S7_SERVER_PORT)/b'\x03\x00\x00\x16\x11\xe0\x00\x00\x00\x08\x00\x01\x02\x01\x00\x00\x00\x00'

        # Wysyłanie pakietu
        send(s7_packet, verbose=False)
        print(f"Pakiet S7 wysłany z {S7_CLIENT_IP} do {S7_SERVER_IP}:{S7_SERVER_PORT}")

        time.sleep(5)

# Funkcja Główna
if __name__ == "__main__":
    # Uruchomienie Serwera Modbus w osobnym wątku
    modbus_server_thread = threading.Thread(target=run_modbus_server, daemon=True)
    modbus_server_thread.start()

    # Odczekanie chwili na uruchomienie serwera
    time.sleep(1)

    # Uruchomienie Klienta Modbus w osobnym wątku
    modbus_client_thread = threading.Thread(target=run_modbus_client, daemon=True)
    modbus_client_thread.start()

    # Uruchomienie Symulacji S7 w osobnym wątku
    s7_simulation_thread = threading.Thread(target=run_s7_simulation, daemon=True)
    s7_simulation_thread.start()

    # Utrzymanie głównego wątku aktywnego
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Zamykanie symulacji.")
