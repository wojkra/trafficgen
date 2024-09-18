#!/usr/bin/env python3

from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
from pymodbus.datastore import ModbusSequentialDataBlock
import logging
import sys

def run_server():
    # Konfiguracja logowania
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.DEBUG)

    # Inicjalizacja magazynu danych z wartościami losowymi
    import random
    di_values = [random.randint(0, 1) for _ in range(100)]
    co_values = [random.randint(0, 1) for _ in range(100)]
    hr_values = [random.randint(0, 10) for _ in range(100)]
    ir_values = [random.randint(0, 10) for _ in range(100)]

    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, di_values),
        co=ModbusSequentialDataBlock(0, co_values),
        hr=ModbusSequentialDataBlock(0, hr_values),
        ir=ModbusSequentialDataBlock(0, ir_values))
    context = ModbusServerContext(slaves=store, single=True)

    # Uruchomienie serwera Modbus na wszystkich interfejsach, port 502
    StartTcpServer(context, address=("0.0.0.0", 502))

if __name__ == "__main__":
    run_server()
