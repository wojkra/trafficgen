#!/usr/bin/env python3

from pymodbus.client.sync import ModbusTcpClient
import random
import time
import logging
import sys
import socket

def run_client():
    # Konfiguracja logowania
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.DEBUG)

    # Utworzenie klienta Modbus
    client = ModbusTcpClient('192.168.81.2', port=502)
    # Powiązanie socketu z adresem źródłowym (ens37)
    client.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client.socket.bind(('192.168.81.1', 0))
    client.connect()

    # Liczba alertów do wygenerowania po uruchomieniu
    num_alerts = 5  # Możesz dostosować tę wartość

    # Generowanie wartości powyżej 10 na różnych rejestrach
    for _ in range(num_alerts):
        reg_addr = random.randint(1, 10)
        register_value = random.randint(11, 100)  # Wartość między 11 a 100

        # Zapis wartości do rejestru holding
        client.write_register(reg_addr, register_value)
        log.debug(f"Written register at {reg_addr}: {register_value}")

        # Odczyt rejestru holding
        rr_regs = client.read_holding_registers(reg_addr, 1)
        if rr_regs.isError():
            log.error(f"Error reading registers at {reg_addr}")
        else:
            read_value = rr_regs.registers[0]
            log.debug(f"Read register at {reg_addr}: {read_value}")

            # Generowanie alertu, jeśli wartość przekracza 10
            if read_value > 10:
                log.warning(f"ALERT: Value at register {reg_addr} exceeds 10: {read_value}")

    # Kontynuacja normalnej pracy skryptu
    while True:
        # Generowanie losowych adresów
        coil_addr = random.randint(1, 10)
        reg_addr = random.randint(1, 10)

        # Generowanie wartości w zakresie 0-10
        register_value = random.randint(0, 10)

        # Zapis losowej wartości do cewki (0 lub 1)
        coil_value = random.randint(0, 1)
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
            log.debug(f"Read coil at {coil_addr}: {rr_coils.bits[0]}")

        # Odczyt rejestrów holding
        rr_regs = client.read_holding_registers(reg_addr, 1)
        if rr_regs.isError():
            log.error(f"Error reading registers at {reg_addr}")
        else:
            read_value = rr_regs.registers[0]
            log.debug(f"Read register at {reg_addr}: {read_value}")

            # Sprawdzenie, czy wartość przekracza 10 i generowanie alertu
            if read_value > 10:
                log.warning(f"ALERT: Value at register {reg_addr} exceeds 10: {read_value}")

        # Odczekaj 1 sekundę
        time.sleep(1)

    client.close()

if __name__ == "__main__":
    run_client()
