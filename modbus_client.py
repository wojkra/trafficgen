#!/usr/bin/env python3

from pymodbus.client.sync import ModbusTcpClient
import random
import time
import logging
import sys
import socket

def run_client():
    # Konfiguracja logowania
    logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
    log = logging.getLogger()

    # Utworzenie klienta Modbus z własnym socketem
    client = ModbusTcpClient('192.168.81.2', port=502)
    client.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # Powiązanie socketu z adresem źródłowym (ens37)
    client.socket.bind(('192.168.81.1', 0))

    client.connect()

    while True:
        # Generowanie losowych wartości
        coil_value = random.randint(0, 1)
        register_value = random.randint(0, 100)

        # Zapis losowej wartości do cewki
        client.write_coil(1, coil_value)
        log.debug(f"Written coil value: {coil_value}")

        # Zapis losowej wartości do rejestru holding
        client.write_register(1, register_value)
        log.debug(f"Written register value: {register_value}")

        # Odczyt cewek
        rr = client.read_coils(1, 10)
        log.debug(f"Read coils: {rr.bits}")

        # Odczyt rejestrów holding
        rr = client.read_holding_registers(1, 10)
        log.debug(f"Read holding registers: {rr.registers}")

        # Odczekaj 1 sekundę
        time.sleep(1)

    client.close()

if __name__ == "__main__":
    run_client()
