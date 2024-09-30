import time
import random
from pymodbus.client.sync import ModbusTcpClient
import snap7
from snap7.util import set_bool

# Klient Modbus łączy się z serwerem na IP 192.168.81.1
modbus_client = ModbusTcpClient('192.168.81.1')

# Klient S7 łączy się z serwerem na IP 192.168.81.1
s7_client = snap7.client.Client()
s7_client.connect('192.168.81.1', 0, 1, 102)

# Symulacja sterownika Modbus (przy założeniu, że sterownik ma IP 192.168.82.10)
def simulate_modbus():
    value = random.randint(10, 20)
    print(f"Zapis wartości {value} do sterownika Modbus.")
    modbus_client.write_register(1, value)

# Symulacja sterownika S7 (przy założeniu, że sterownik ma IP 192.168.82.20)
def simulate_s7():
    value = random.randint(20, 30)
    print(f"Zapis wartości {value} do sterownika S7.")
    data = bytearray(1)
    set_bool(data, 0, 0, value % 2)
    s7_client.db_write(1, 0, data)

# Funkcja główna
def run_client():
    while True:
        print("Symulacja komunikacji...")
        simulate_modbus()
        simulate_s7()
        time.sleep(5)

if __name__ == "__main__":
    try:
        run_client()
    except KeyboardInterrupt:
        print("Zatrzymywanie klienta...")
        modbus_client.close()
        s7_client.disconnect()
