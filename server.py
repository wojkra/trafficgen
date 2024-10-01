import time
import random
from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import ModbusSlaveContext, ModbusServerContext, ModbusSequentialDataBlock
from pymodbus.device import ModbusDeviceIdentification
import snap7
from snap7.server import Server

# Konfiguracja serwera Modbus
def setup_modbus_server():
    store = ModbusSlaveContext(
        di=ModbusSequentialDataBlock(0, [0] * 100),
        co=ModbusSequentialDataBlock(0, [0] * 100),
        hr=ModbusSequentialDataBlock(0, [0] * 100),
        ir=ModbusSequentialDataBlock(0, [0] * 100))
    context = ModbusServerContext(slaves=store, single=True)

    identity = ModbusDeviceIdentification()
    identity.VendorName = 'ModbusServer'
    identity.ProductCode = 'MS'
    identity.VendorUrl = 'http://example.com'
    identity.ProductName = 'ModbusServer'
    identity.ModelName = 'ModbusServer'
    identity.MajorMinorRevision = '1.0'

    return context, identity

# Konfiguracja serwera S7
def setup_s7_server():
    s7_server = Server()
    s7_server.register_area(snap7.types.areas.DB, 1, bytearray(100))
    return s7_server

# Funkcja uruchamiająca oba serwery
def start_servers():
    # Serwer Modbus
    modbus_context, modbus_identity = setup_modbus_server()
    print("Uruchamianie serwera Modbus...")
    StartTcpServer(modbus_context, identity=modbus_identity, address=("192.168.81.1", 502))

    # Serwer S7
    s7_server = setup_s7_server()
    print("Uruchamianie serwera S7 na porcie 102...")
    s7_server.start(tcpport=102)

    try:
        while True:
            print("Serwery działają...")
            time.sleep(5)
    except KeyboardInterrupt:
        print("Zatrzymywanie serwerów...")
        s7_server.stop()

if __name__ == "__main__":
    start_servers()
