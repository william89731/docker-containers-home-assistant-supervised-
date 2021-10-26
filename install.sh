#!/bin/bash
echo "
	 ##         ######   ###   ##  ##    ##  ##    ## 
	 ##         ######   ###   ##  ##    ##  :##  ##: 
	 ##           ##     ###:  ##  ##    ##   ##  ##  
	 ##           ##     ####  ##  ##    ##   :####:  
	 ##           ##     ##:#: ##  ##    ##    ####   
	 ##           ##     ## ## ##  ##    ##    :##:   
	 ##           ##     ## ## ##  ##    ##    :##:   
	 ##           ##     ## :#:##  ##    ##    ####   
	 ##           ##     ##  ####  ##    ##   :####:  
	 ##           ##     ##  :###  ##    ##   ##::##  
	 ########   ######   ##   ###  :######:  :##  ##: 
	 ########   ######   ##   ###   :####:   ##    ## "
sleep 3	  
echo "Benvenuto,figlio della perdizione "
printf "\U$(printf %08x 128520)\n"
sleep 3
echo "stai per installare un container docker di home assistant supervised !"
sleep 7
echo "cominciamo!"

add-apt-repository universe
apt-get update
apt-get install -y apparmor-utils apt-transport-https avahi-daemon ca-certificates curl dbus jq network-manager socat software-properties-common bluez bluetooth libbluetooth-dev 
systemctl disable ModemManager
apt-get purge -y modemmanager



WD=/opt/hassio
mkdir -p $WD/setup
cd $WD/setup
cat << 'FNE' >/opt/hassio/setup/apparmor_setup.sh
cat << 'EOF' >/opt/hassio/setup/hassio.json
{
    "supervisor": "homeassistant/amd64-hassio-supervisor",
    "machine": "qemux86-64",
    "data": "/opt/hassio"
}
EOF

cat << 'FOE' >/usr/sbin/hassio-apparmor
#!/usr/bin/env bash
set -e

# carica config
CONFIG_FILE=/opt/hassio/setup/hassio.json

# leggi config
DATA="$(jq --raw-output '.data // "/usr/share/hassio"' ${CONFIG_FILE})"
PROFILES_DIR="${DATA}/apparmor"
CACHE_DIR="${PROFILES_DIR}/cache"
REMOVE_DIR="${PROFILES_DIR}/remove"

# Exists AppArmor
if ! command -v apparmor_parser > /dev/null 2>&1; then
    echo "[Warning]: No apparmor_parser on host system!"
    exit 0
fi

# Check folder structure
mkdir -p "${PROFILES_DIR}"
mkdir -p "${CACHE_DIR}"
mkdir -p "${REMOVE_DIR}"

# Load/Update exists/new profiles
for profile in "${PROFILES_DIR}"/*; do
    if [ ! -f "${profile}" ]; then
        continue
    fi

    # Load Profile
    if ! apparmor_parser -r -W -L "${CACHE_DIR}" "${profile}"; then
        echo "[Error]: Can't load profile ${profile}"
    fi
done

# Cleanup old profiles
for profile in "${REMOVE_DIR}"/*; do
    if [ ! -f "${profile}" ]; then
        continue
    fi

    # Unload Profile
    if apparmor_parser -R -W -L "${CACHE_DIR}" "${profile}"; then
        if rm -f "${profile}"; then
            continue
        fi
    fi
    echo "[Error]: Can't remove profile ${profile}"
done
FOE
chmod +x /usr/sbin/hassio-apparmor
#repeated on purpose
#/usr/sbin/hassio-apparomor
#/usr/sbin/hassio-apparomor
FNE
chmod +x /opt/hassio/setup/apparmor_setup.sh


WD=/opt/hassio
mkdir -p $WD/setup
cd $WD/setup
cat << 'EOF' >docker-compose.yaml
version: '3.8'
services:
  hassio_supervisor:
    container_name: hassio_supervisor
    image: "homeassistant/amd64-hassio-supervisor"
    privileged: true

    volumes:
      - type: bind
        source: /opt/hassio
        target: /data
      - type: bind
        source: /etc/machine-id
        target: /etc/machine-id
      - type: bind
        source: /etc/localtime
        target: /etc/localtime
      - type: bind
        source: /run/docker.sock
        target: /run/docker.sock
      - type: bind
        source: /run/dbus
        target: /run/dbus
      - type: bind
        source: /dev/bus/usb
        target: /dev/bus/usb

    security_opt:
      - seccomp:unconfined
     # - apparmor:hassio-supervisor

    environment:
      - SUPERVISOR_SHARE=/opt/hassio
      - SUPERVISOR_NAME=hassio_supervisor
      - HOMEASSISTANT_REPOSITORY=homeassistant/qemux86-homeassistant
      - DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket
    ports:
      - "8124:8123"  
EOF
docker-compose up -d 

sleep 5

echo "
╔╗ ╔╗╔═══╗╔═╗╔═╗╔═══╗    ╔═══╗╔═══╗╔═══╗╔══╗╔═══╗╔════╗╔═══╗╔═╗ ╔╗╔════╗
║║ ║║║╔═╗║║║╚╝║║║╔══╝    ║╔═╗║║╔═╗║║╔═╗║╚╣╠╝║╔═╗║║╔╗╔╗║║╔═╗║║║╚╗║║║╔╗╔╗║
║╚═╝║║║ ║║║╔╗╔╗║║╚══╗    ║║ ║║║╚══╗║╚══╗ ║║ ║╚══╗╚╝║║╚╝║║ ║║║╔╗╚╝║╚╝║║╚╝
║╔═╗║║║ ║║║║║║║║║╔══╝    ║╚═╝║╚══╗║╚══╗║ ║║ ╚══╗║  ║║  ║╚═╝║║║╚╗║║  ║║  
║║ ║║║╚═╝║║║║║║║║╚══╗    ║╔═╗║║╚═╝║║╚═╝║╔╣╠╗║╚═╝║ ╔╝╚╗ ║╔═╗║║║ ║║║ ╔╝╚╗ 
╚╝ ╚╝╚═══╝╚╝╚╝╚╝╚═══╝    ╚╝ ╚╝╚═══╝╚═══╝╚══╝╚═══╝ ╚══╝ ╚╝ ╚╝╚╝ ╚═╝ ╚══╝ "
                                                                        
                                                                        

                                                                        
sleep 3                                                                        

echo "fine installazione. BUON DIVERTIMENTO"


