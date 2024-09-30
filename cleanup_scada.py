#!/usr/bin/env python3

import subprocess

# Funkcja pomocnicza do wykonywania poleceń systemowych
def run_cmd(cmd):
    print(f"Executing: {cmd}")
    subprocess.run(cmd, shell=True, check=False)

def cleanup_network():
    # Lista przestrzeni nazw do usunięcia
    namespaces = ['ns_server', 'ns_client_modbus', 'ns_client_s7']
    
    # Zatrzymanie procesów w przestrzeniach nazw (jeśli to konieczne)
    # Możesz dodać tutaj kod, który zatrzyma uruchomione serwery i klientów
    
    # Przywrócenie interfejsów fizycznych do domyślnej przestrzeni nazw
    physical_interfaces = ['ens37', 'ens38']
    for iface in physical_interfaces:
        # Sprawdź, czy interfejs istnieje w jakiejkolwiek przestrzeni nazw
        found = False
        for ns in namespaces:
            result = subprocess.run(f'ip netns exec {ns} ip link show {iface}', shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if result.returncode == 0:
                found = True
                # Przenieś interfejs z powrotem do domyślnej przestrzeni nazw
                run_cmd(f'ip netns exec {ns} ip link set {iface} netns 1')
                # Ustaw interfejs jako aktywny
                run_cmd(f'ip link set {iface} up')
                # Usuń adresy IP
                run_cmd(f'ip addr flush dev {iface}')
                break
        if not found:
            print(f"Interfejs {iface} nie został znaleziony w przestrzeniach nazw.")
    
    # Usunięcie mostu w ns_client_modbus
    run_cmd('ip netns exec ns_client_modbus ip link set br0 down')
    run_cmd('ip netns exec ns_client_modbus brctl delbr br0')
    
    # Usunięcie interfejsów wirtualnych
    run_cmd('ip link delete veth_s7 type veth')
    # Jeśli istnieje drugi koniec, usuń go
    run_cmd('ip link delete veth_s7_br type veth')
    
    # Usunięcie przestrzeni nazw
    for ns in namespaces:
        run_cmd(f'ip netns delete {ns}')
    
    print("Konfiguracja została wyczyszczona.")

if __name__ == '__main__':
    cleanup_network()
