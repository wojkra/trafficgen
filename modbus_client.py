# modbus_client.py
from pymodbus.client import ModbusTcpClient
from pymodbus.exceptions import ModbusException
import time
import struct
import logging
import random

# Ustawienie logowania dla debugowania
logging.basicConfig()
log = logging.getLogger()
log.setLevel(logging.INFO)  # Możesz zmienić na DEBUG, jeśli potrzebujesz więcej informacji

# Konfiguracja klienta
SERVER_IP = '192.168.81.1'  # Adres IP serwera Modbus
SERVER_PORT = 502           # Port serwera Modbus

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

def read_registers(unit=1, address=0, count=2):
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

def write_registers(unit=1, address=0, values=None):
    """
    Zapis rejestrów na serwerze Modbus.
    :param unit: ID urządzenia Modbus (domyślnie 1)
    :param address: Adres początkowy rejestrów
    :param values: Lista wartości do zapisania
    :return: True jeśli zapis się powiódł, False w przeciwnym razie
    """
    if values is None:
        print("[Modbus Client] Brak wartości do zapisania.")
        return False
    try:
        result = client.write_registers(address, values, unit=unit)
        if not result.isError():
            print(f"[Modbus Client] Zapisano wartości {values} do rejestrów {address}.")
            return True
        else:
            print(f"[Modbus Client] Błąd podczas zapisu rejestrów: {result}")
            return False
    except ModbusException as e:
        print(f"[Modbus Client] Błąd Modbus podczas zapisu rejestrów: {e}")
        return False
    except Exception as e:
        print(f"[Modbus Client] Wyjątek podczas zapisu rejestrów: {e}")
        return False

def main():
    try:
        connect_client()
        while True:
            # Odczyt rejestrów z adresu 0 (możesz zmienić adres na odpowiedni)
            registers = read_registers(address=0, count=2)
            if registers is not None:
                # Konwersja wartości z rejestrów (przykład: 32-bitowy INT)
                packed = struct.pack('>HH', registers[0], registers[1])
                value = struct.unpack('>I', packed)[0]
                print(f"[Modbus Client] Odczytano wartość {value} z rejestrów.")

                # Przykładowa operacja zapisu: losowa wartość w zakresie 10-20
                new_value = random.randint(10, 20)
                print(f"[Modbus Client] Zapisuję nową wartość: {new_value}")

                # Konwersja wartości do dwóch rejestrów (32-bitowy INT)
                new_registers = struct.unpack('>HH', struct.pack('>I', new_value))
                write_registers(address=0, values=new_registers)
            else:
                print("[Modbus Client] Nie udało się odczytać rejestrów.")

            time.sleep(5)  # Czekaj 5 sekund przed następnym cyklem
    except KeyboardInterrupt:
        print("\n[Modbus Client] Zatrzymano klienta Modbus.")
    finally:
        disconnect_client()

if __name__ == "__main__":
    main()
