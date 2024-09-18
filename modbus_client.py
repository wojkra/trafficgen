#!/usr/bin/env python3

import time
from pymodbus.client.sync import ModbusTcpClient

def modbus_client():
    client = ModbusTcpClient("192.168.81.1", port=5020)
    while True:
        # Operacje na Coils
        rq = client.write_coil(1, True)
        rr = client.read_coils(1, 1)
        print(f"Coil[1] = {rr.bits[0]}")

        # Operacje na Discrete Inputs
        rr = client.read_discrete_inputs(1, 1)
        print(f"Discrete Input[1] = {rr.bits[0]}")

        # Operacje na Holding Registers
        rq = client.write_register(1, 42)
        rr = client.read_holding_registers(1, 1)
        print(f"Holding Register[1] = {rr.registers[0]}")

        # Operacje na Input Registers
        rr = client.read_input_registers(1, 1)
        print(f"Input Register[1] = {rr.registers[0]}")

        time.sleep(15)

if __name__ == "__main__":
    modbus_client()
