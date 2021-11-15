#!/bin/bash

#da qui si possono impostare tutti i parametri dei files e delle cartelle
BASE_DIR=/opt/hassio
SETUP_DIR=$BASE_DIR/setup
APPARMOR_SETUP=$SETUP_DIR/apparmor_setup.sh
HASSIO_APPARMOR=$SETUP_DIR/hassio-apparmor
HASSIO_JSON=$SETUP_DIR/hassio.json
#trovo quale distro è
DISTRO=$(cat /etc/issue|awk '{print $1}'|tr '[:upper:]' '[:lower:]')

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
echo "stai per installare dei containers docker di home assistant supervised !"
sleep 7
echo "cominciamo!"

#aggiungo i repo nel caso di ubuntu
if [[ "${DISTRO}" =~ ^(ubuntu)$ ]]; then
  add-apt-repository universe
fi

echo "Installo i pacchetti necessari..."
apt-get update
apt-get install -y apparmor-utils apt-transport-https avahi-daemon ca-certificates curl dbus jq network-manager socat software-properties-common bluez bluetooth libbluetooth-dev 
echo "Disabilito ModemManager"
systemctl disable ModemManager
apt-get purge -y modemmanager
apt autoremove -y


mkdir -p $SETUP_DIR
cd $SETUP_DIR

#rendiamo il file parametrico - ho tolto le referenze a /opt/hassio e sostituito con $BASE_DIR
cat << FNE > $APPARMOR_SETUP
cat << EOF > $HASSIO_JSON
{
    "supervisor": "homeassistant/amd64-hassio-supervisor",
    "machine": "qemux86-64",
    "data": "$BASE_DIR"
}
EOF

cat << 'FOE' > $HASSIO_APPARMOR
#!/usr/bin/env bash
set -e

# carica config
CONFIG_FILE=$HASSIO_JSON

# leggi config
DATA="\$(jq --raw-output '.data // "/usr/share/hassio"' \${CONFIG_FILE})"
PROFILES_DIR="\${DATA}/apparmor"
CACHE_DIR="\${PROFILES_DIR}/cache"
REMOVE_DIR="\${PROFILES_DIR}/remove"

#  AppArmor
if ! command -v apparmor_parser > /dev/null 2>&1; then
    echo "[Warning]: No apparmor_parser on host system!"
    exit 0
fi

# Check struttura cartelle
mkdir -p "\${PROFILES_DIR}"
mkdir -p "\${CACHE_DIR}"
mkdir -p "\${REMOVE_DIR}"

# Load/Update profili
for profile in "\${PROFILES_DIR}"/*; do
    if [ ! -f "\${profile}" ]; then
        continue
    fi

    # Load Profile
    if ! apparmor_parser -r -W -L "\${CACHE_DIR}" "\${profile}"; then
        echo "[Error]: Can't load profile \${profile}"
    fi
done

# Cleanup old profili
for profile in "\${REMOVE_DIR}"/*; do
    if [ ! -f "\${profile}" ]; then
        continue
    fi

    # Unload Profili
    if apparmor_parser -R -W -L "\${CACHE_DIR}" "\${profile}"; then
        if rm -f "\${profile}"; then
            continue
        fi
    fi
    echo "[Error]: Can't remove profile \${profile}"
done
FOE
chmod +x $HASSIO_APPARMOR
#repeated on purpose
#$HASSIO_APPARMOR
#$HASSIO_APPARMOR
FNE
chmod +x $APPARMOR_SETUP

#già fatto prima...
#mkdir -p $SETUP_DIR
#cd $SETUP_DIR
cat << EOF >docker-compose.yaml
version: '3.8'
services:
  hassio_supervisor:
    container_name: hassio_supervisor
    image: "homeassistant/amd64-hassio-supervisor"
    privileged: true

    volumes:
      - type: bind
        source: $BASE_DIR
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
      - SUPERVISOR_SHARE=$BASE_DIR
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

