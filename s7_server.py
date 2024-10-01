# s7_server.py
import snap7
from snap7.server import Server
from snap7.snap7types import S7AreaDB
import random
import threading
import time

def update_s7_data(server):
    while True:
        value = random.randint(20, 30)
        # Zakładamy, że DB1 jest typu INT (2 bajty)
        data = value.to_bytes(2, byteorder='big')
        try:
            server.db_write(1, 0, data)
            print(f"[S7 Server] Updated DB1, offset 0 to {value}")
        except Exception as e:
            print(f"[S7 Server] Błąd podczas zapisu do DB1: {e}")
        time.sleep(5)

def run_s7_server():
    server = Server()
    
    # Ustawienie adresu IP serwera
    try:
        server.set_param_server_ip("192.168.81.1")
    except AttributeError as e:
        print(f"[S7 Server] Błąd podczas ustawiania IP serwera: {e}")
        return

    # Uruchomienie serwera
    try:
        server.start()
    except Exception as e:
        print(f"[S7 Server] Błąd podczas uruchamiania serwera: {e}")
        return
    print("[S7 Server] Uruchomiono serwer S7 na 192.168.81.1")

    # Rejestracja bloków danych
    try:
        # Rejestracja Bloku Danych 1 (DB1) z 2 bajtami (INT)
        server.register_area(S7AreaDB, 1, 2)  # Area, DB number, size
    except TypeError as e:
        print(f"[S7 Server] Błąd podczas rejestrowania DB1: {e}")
        server.stop()
        server.destroy()
        return
    except Exception as e:
        print(f"[S7 Server] Inny błąd podczas rejestrowania DB1: {e}")
        server.stop()
        server.destroy()
        return

    # Uruchomienie wątku aktualizującego dane
    thread = threading.Thread(target=update_s7_data, args=(server,))
    thread.daemon = True
    thread.start()

    # Utrzymanie serwera w działaniu
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        server.stop()
        server.destroy()
        print("[S7 Server] Zatrzymano serwer S7")

if __name__ == "__main__":
    run_s7_server()
