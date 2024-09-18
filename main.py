#!/usr/bin/env python3

import subprocess
import time

def main():
    # Uruchomienie serwera Modbus
    server_process = subprocess.Popen(['sudo', 'python3', 'modbus_server.py'])

    # Odczekanie na uruchomienie serwera
    time.sleep(2)

    # Uruchomienie klienta Modbus
    client_process = subprocess.Popen(['python3', 'modbus_client.py'])

    # Nieskończona pętla
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        # Zakończenie procesów po przerwaniu
        client_process.terminate()
        server_process.terminate()

if __name__ == "__main__":
    main()
