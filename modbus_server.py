# modbus_server.py
from pymodbus.server.sync import StartTcpServer
from pymodbus.device import ModbusDeviceIdentification
from pymodbus.datastore import ModbusSequentialDataBlock, ModbusSlaveContext, ModbusServerContext
import random
import threading
import time

def update_modbus_values(context):
    while True:
        value = random.randint(10, 20)
        context[0].setValues(3, 0, [value])  # Holding Register 0
        print(f"[Modbus Server] Updated holding register to {value}")
        time.sleep(5)

def run_modbus_server():
    store = ModbusSlaveContext(
        hr=ModbusSequentialDataBlock(0, [0]*100)
    )
    context = ModbusServerContext(slaves=store, single=True)

    identity = ModbusDeviceIdentification()
    identity.VendorName = 'SimulatedModbusServer'
    identity.ProductCode = 'MB'
    identity.VendorUrl = 'http://example.com'
    identity.ProductName = 'Modbus Server'
    identity.ModelName = 'ModbusServerModel'
    identity.MajorMinorRevision = '1.0'

    # Start thread to update values
    thread = threading.Thread(target=update_modbus_values, args=(context,))
    thread.daemon = True
    thread.start()

    # Start Modbus server na interfejsie ens36 (192.168.81.10) port 5020
    print("[Modbus Server] Uruchamianie serwera Modbus na 192.168.81.10:5020")
    StartTcpServer(context, identity=identity, address=("192.168.81.10", 5020))

if __name__ == "__main__":
    run_modbus_server()
