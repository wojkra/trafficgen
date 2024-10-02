# s7_client.py
import snap7
from snap7.util import *
from snap7.snap7types import Areas
import time
import random
import logging

# Konfiguracja logowania
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Parametry połączenia
PLC_IP = '192.168.81.1'
PLC_RACK = 0
PLC_SLOT = 1

# Adres danych DB1, offset 0, typ REAL (4 bajty)
DB_NUMBER = 1
START_ADDRESS = 0
DATA_SIZE = 4

def connect_to_plc():
    client = snap7.client.Client()
    try:
        client.connect(PLC_IP, PLC_RACK, PLC_SLOT)
        if client.get_connected():
            logger.info(f"Połączono z PLC {PLC_IP}")
        else:
            logger.error(f"Nie udało się połączyć z PLC {PLC_IP}")
            return None
        return client
    except Exception as e:
        logger.error(f"Błąd podczas łączenia z PLC: {e}")
        return None

def write_real_value(client, db, start, value):
    try:
        data = bytearray(4)
        set_real(data, 0, float(value))
        result = client.write_area(Areas.DB, db, start, data)
        if result == 0:
            logger.info(f"Zapisano wartość {value} do DB{db} na adresie {start}")
        else:
            logger.error(f"Błąd zapisu do DB{db}: kod błędu {result}")
    except Exception as e:
        logger.error(f"Błąd podczas zapisu do PLC: {e}")

def read_real_value(client, db, start):
    try:
        data = client.read_area(Areas.DB, db, start, DATA_SIZE)
        if data:
            value = get_real(data, 0)
            logger.info(f"Odczytano wartość {value} z DB{db} na adresie {start}")
            return value
        else:
            logger.error("Błąd odczytu danych z PLC")
            return None
    except Exception as e:
        logger.error(f"Błąd podczas odczytu z PLC: {e}")
        return None

def main():
    client = connect_to_plc()
    if not client:
        return

    try:
        while True:
            # Generowanie losowej wartości między 20 a 30
            value = random.uniform(20, 30)
            # Zapis wartości do PLC
            write_real_value(client, DB_NUMBER, START_ADDRESS, value)
            # Odczyt wartości z PLC
            read_value = read_real_value(client, DB_NUMBER, START_ADDRESS)
            # Weryfikacja poprawności
            if read_value is not None and 20 <= read_value <= 30:
                logger.info("Komunikacja S7 działa poprawnie.")
            else:
                logger.warning("Komunikacja S7 może mieć problemy.")
            # Czekaj 5 sekund
            time.sleep(5)
    except KeyboardInterrupt:
        logger.info("Zakończono działanie klienta S7.")
    finally:
        client.disconnect()
        logger.info("Rozłączono z PLC.")

if __name__ == "__main__":
    main()
