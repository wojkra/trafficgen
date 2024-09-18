**Nadaj uprawnienia wykonania:**
chmod +x main_script.sh modbus_server.py modbus_client.py

**Uruchom main_script.sh z uprawnieniami administratora:**
sudo ./main_script.sh

**Monitorowanie ruchu na interfejsie ens37**
sudo tcpdump -i ens37 port 5020 -vv

**Przekazywanie IP:
Skrypt włącza przekazywanie IP na hoście, ale możesz to sprawdzić poleceniem:**
cat /proc/sys/net/ipv4/ip_forward
**Powinno zwrócić 1.**
