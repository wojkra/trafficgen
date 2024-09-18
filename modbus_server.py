#!/usr/bin/env python3

from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
from pymodbus.datastore import ModbusSequentialDataBlock
import logging

def run_server():
    # Konfiguracja logowania
    logging.basicConfig()
    log = logging.getLogger()
    log.setLevel(logging.INFO)

    # Inicjalizacja magazynu danych
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [0]*100),
        co=ModbusSequentialDataBlock(0, [0]*100),
        hr=ModbusSequentialDataBlock(0, [0]*100),
        ir=ModbusSequentialDataBlock(0, [0]*100))
    context = ModbusServerContext(slaves=store, single=True)

    # Uruchomienie serwera Modbus na ens38 (192.168.81.2), port 502
    StartTcpServer(context, address=("192.168.81.2", 502))

if __name__ == "__main__":
    run_server()
