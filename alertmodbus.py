#!/usr/bin/env python3

from pymodbus.client.sync import ModbusTcpClient
import random
import time
import logging
import sys
import socket

def run_client():
    # Configure logging
    logging.basicConfig(stream=sys.stdout)
    log = logging.getLogger()
    log.setLevel(logging.DEBUG)

    # Create Modbus client
    client = ModbusTcpClient('192.168.81.2', port=502)
    # Bind socket to source address (ens37)
    client.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client.socket.bind(('192.168.81.1', 0))
    client.connect()

    alert_generated = False  # Flag to ensure the alert is generated only once

    while True:
        # Generate random addresses
        coil_addr = random.randint(1, 10)
        reg_addr = random.randint(1, 10)

        # Check if the alert has been generated
        if not alert_generated:
            # Generate a value outside the 0-100 range to trigger an alert
            coil_value = random.randint(0, 1)
            register_value = random.randint(101, 200)  # Value outside the normal range
            alert_generated = True  # Set the flag so this block runs only once
            log.warning(f"Alert triggered! Writing out-of-range value {register_value} at register {reg_addr}")
        else:
            # Generate normal values within the range
            coil_value = random.randint(0, 1)
            register_value = random.randint(0, 100)

        # Write value to coil
        client.write_coil(coil_addr, coil_value)
        log.debug(f"Written coil at {coil_addr}: {coil_value}")

        # Write value to holding register
        client.write_register(reg_addr, register_value)
        log.debug(f"Written register at {reg_addr}: {register_value}")

        # Read coils
        rr_coils = client.read_coils(coil_addr, 1)
        if rr_coils.isError():
            log.error(f"Error reading coils at {coil_addr}")
        else:
            log.debug(f"Read coil at {coil_addr}: {rr_coils.bits}")

        # Read holding registers
        rr_regs = client.read_holding_registers(reg_addr, 1)
        if rr_regs.isError():
            log.error(f"Error reading registers at {reg_addr}")
        else:
            log.debug(f"Read register at {reg_addr}: {rr_regs.registers}")

        # Wait 1 second
        time.sleep(1)

    client.close()

if __name__ == "__main__":
    run_client()
