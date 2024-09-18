#!/usr/bin/env python3

from pymodbus.server.sync import StartTcpServer
from pymodbus.device import ModbusDeviceIdentification
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext
from pymodbus.datastore import ModbusSequentialDataBlock

def run_modbus_server():
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [0]*100),
        co=ModbusSequentialDataBlock(0, [0]*100),
        ir=ModbusSequentialDataBlock(0, [0]*100),
        hr=ModbusSequentialDataBlock(0, [0]*100)
    )
    context = ModbusServerContext(slaves=store, single=True)
    identity = ModbusDeviceIdentification()
    identity.VendorName = 'Custom Modbus Server'
    identity.ProductName = 'Modbus Server'
    identity.ModelName = 'Modbus Server'
    identity.MajorMinorRevision = '1.0'

    print("Serwer Modbus uruchomiony.")
    StartTcpServer(context, identity=identity, address=("192.168.81.1", 5020))

if __name__ == "__main__":
    run_modbus_server()
