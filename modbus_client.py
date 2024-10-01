# modbus_client.py
from pymodbus.client.sync import ModbusTcpClient
from pymodbus.exceptions import ModbusException
import time
import struct
import logging

# Ustawienie logowania dla debugowania
logging.basicConfig()
log = logging.getLogger()
log.setLevel(logging.INFO)  # Możesz zmienić na DEBUG, jeśli potrzebujesz więcej informacji

# Konfiguracja klienta
SERVER_IP = '192.168.81.1'  # Adres IP serwera Modbus
SERVER_PORT = 5020           # Port serwera Modbus

# Inicjalizacja klienta
client = ModbusTcpClient(SERVER_IP, port=SERVER_PORT)

def connect_client():
    if client.connect():
        print(f"[Modbus Client] Połączono z serwerem Modbus (IP: {SERVER_IP}, Port: {SERVER_PORT}).")
    else:
        print(f"[Modbus Client] Nie udało się połączyć z serwerem Modbus (IP: {SERVER_IP}, Port: {SERVER_PORT}).")

def disconnect_client():
    client.close()
    print("[Modbus Client] Rozłączono z serwerem Modbus.")

def read_registers(unit=1, address=0, count=1):
    """
    Odczyt rejestrów z serwera Modbus.
    :param unit: ID urządzenia Modbus (domyślnie 1)
    :param address: Adres początkowy rejestrów
    :param count: Liczba rejestrów do odczytu
    :return: Lista odczytanych wartości lub None w przypadku błędu
    """
    try:
        result = client.read_holding_registers(address, count, unit=unit)
        if not result.isError():
            return result.registers
        else:
            print(f"[Modbus Client] Błąd podczas odczytu rejestrów: {result}")
            return None
    except ModbusException as e:
        print(f"[Modbus Client] Błąd Modbus podczas odczytu rejestrów: {e}")
        return None
    except Exception as e:
        print(f"[Modbus Client] Wyjątek podczas odczytu rejestrów: {e}")
        return None

def main():
    try:
        connect_client()
        while True:
            # Odczyt rejestru z adresu 0 (możesz zmienić adres na odpowiedni)
            registers = read_registers(address=0, count=1)
            if registers is not None:
                value = registers[0]
                print(f"[Modbus Client] Odczytano wartość {value} z rejestru 0.")
            else:
                print("[Modbus Client] Nie udało się odczytać rejestru.")
            time.sleep(5)  # Czekaj 5 sekund przed następnym cyklem
    except KeyboardInterrupt:
        print("\n[Modbus Client] Zatrzymano klienta Modbus.")
    finally:
        disconnect_client()

if __name__ == "__main__":
    main()
