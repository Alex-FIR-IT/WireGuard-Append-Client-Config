# WireGuard-Append-Client-Config

### What Does script do

Create a new clint configuration WireGuard file and generate qrcode.
Please pay attention to the fact that this README.md file does not provide instructions for configuring the WireGuard service on your server. 
It merely describes the way my script works 

### PreRequirements of directory

To ensure that the script "append_client.sh" is workable on you machine you need:

1) Install qrencode. Do to that you need to put and execute the following command:
```bash
sudo apt install
``` 
2) Locate your base WireGuard folder into the following directory - "/etc/wireguard".
3) Ensure that the following files and directories in "/etc/wireguard" exist:
* append_client.sh - bash script from this repository
* wg0.conf - your main WireGuard config
* backups - just a directory. Script will save your wg0.conf into this one every time you run script
* clients - just a directory where a client files will be stored, namely: 
pubk${client_number} - client public key,
pvk${client_number} - client secret key, 
wg${client_number}.conf - client configuration file.
All there files will be appended by bash script "append_client.sh"
* .env - a file with your environmental variables. It must contain:
1) SERVER_PRIVATE_KEY=...
2) SERVER_PUBLIC_KEY=...
3) SERVER_ENDPOINT=...
4) SERVER_PORT=...
5) SERVER_DNS=...

### Execution of the script

to execute script, type:
```bash
cd /etc/wireguard/ && bash append_client.sh
```

OR if you are already in the wireguard directory, then just type: 
```bash
bash append_client.sh
```
