# s7_server.py
import snap7
from snap7.server import Server
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
    try:
        # Używamy tylko pozycyjnych argumentów
        server.create("192.168.81.1", 0, 1)  # IP, Rack, Slot
    except TypeError as e:
        print(f"[S7 Server] Błąd podczas tworzenia serwera: {e}")
        return
    except Exception as e:
        print(f"[S7 Server] Inny błąd podczas tworzenia serwera: {e}")
        return

    try:
        server.start()
    except Exception as e:
        print(f"[S7 Server] Błąd podczas uruchamiania serwera: {e}")
        return

    try:
        # Utwórz blok danych DB1 z 2 bajtami (INT)
        server.db_create(1, 2)  # DB1 z 2 bajtami
    except Exception as e:
        print(f"[S7 Server] Błąd podczas tworzenia DB1: {e}")
        server.stop()
        server.destroy()
        return

    print("[S7 Server] Uruchomiono serwer S7 na 192.168.81.1")

    # Start thread to update data
    thread = threading.Thread(target=update_s7_data, args=(server,))
    thread.daemon = True
    thread.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        server.stop()
        server.destroy()
        print("[S7 Server] Zatrzymano serwer S7")

if __name__ == "__main__":
    run_s7_server()
