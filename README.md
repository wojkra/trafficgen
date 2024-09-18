**Nadaj uprawnienia wykonania:**

_chmod +x main_script.sh modbus_server.py modbus_client.py_

**Uruchom main_script.sh z uprawnieniami administratora:**

_sudo ./main_script.sh_

**Monitorowanie ruchu na interfejsie ens37**

_sudo tcpdump -i ens37 port 5020 -vv
_
**Przekazywanie IP:
Skrypt włącza przekazywanie IP na hoście, ale możesz to sprawdzić poleceniem:**

_cat /proc/sys/net/ipv4/ip_forward
_
**Powinno zwrócić 1.**
