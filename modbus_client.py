#!/usr/bin/env python3

from pymodbus.client.sync import ModbusTcpClient
import random
import time

def run_client():
    # Połączenie z serwerem Modbus na 192.168.81.2, port 502, z ens37 (192.168.81.1)
    client = ModbusTcpClient('192.168.81.2', port=502, source_address=("192.168.81.1", 0))

    client.connect()

    while True:
        # Generowanie losowych wartości
        coil_value = random.randint(0, 1)
        register_value = random.randint(0, 100)

        # Zapis losowej wartości do cewki
        client.write_coil(1, coil_value)

        # Zapis losowej wartości do rejestru holding
        client.write_register(1, register_value)

        # Odczyt cewek
        rr = client.read_coils(1, 10)
        # Odczyt rejestrów holding
        rr = client.read_holding_registers(1, 10)

        # Odczekaj 1 sekundę
        time.sleep(1)

    client.close()

if __name__ == "__main__":
    run_client()
