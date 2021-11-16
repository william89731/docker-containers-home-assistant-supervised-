#!/bin/bash

#da qui si possono impostare tutti i parametri dei files e delle cartelle
BASE_DIR=/opt/hassio
SETUP_DIR=$BASE_DIR/scripts
APPARMOR_SETUP=$SETUP_DIR/apparmor_setup.sh
HASSIO_APPARMOR=$SETUP_DIR/hassio-apparmor
HASSIO_JSON=$SETUP_DIR/hassio.json
#trovo quale distro è
DISTRO=$(cat /etc/issue|awk '{print $1}'|tr '[:upper:]' '[:lower:]')
COMPOSE_DIR=$BASE_DIR


if [[ $EUID -ne 0 ]]; then
   echo "Questo script deve essere eseguito come root" 
   exit 1
fi

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
sleep 1	  
echo "Benvenuto,figlio della perdizione "
#questo codice non funziona su Debian
printf "\U$(printf %08x 128520)\n"
sleep 1
echo "stai per installare dei containers docker di home assistant supervised !"
sleep 2
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

cat << NEF > "\${PROFILES_DIR}/hassio-supervisor"
#include <tunables/global>

profile hassio-supervisor flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  #include <abstractions/python>

  network,
  deny network raw,

  signal (send) set=(kill,term,int,hup,cont),

  capability net_admin,
  capability net_bind_service,
  capability dac_read_search,
  capability dac_override,

  /bin/** ix,
  /usr/bin/** ix,
  /bin/udevadm Ux,
  /sbin/udevd Ux,
  /usr/local/bin/python* ix,
  /usr/bin/git cx,
  /usr/bin/gdbus cx,
  /usr/lib/bashio/** ix,
  /etc/s6/** ix,
  /run/s6/** ix,
  /etc/services.d/** rwix,
  /etc/cont-init.d/** rwix,
  /etc/cont-finish.d/** rwix,

  deny /proc/** wl,
  deny /root/** wl,
  deny /sys/** wl,

  / r,
  /** r,
  /tmp/** rw,
  /data/** rw,
  /os/** rw,
  /run/** rwk,
  /dev/tty rw,
  /etc/resolv.conf rw,
  /run/docker.sock rw,

  /usr/local/lib/** mr,

  profile /usr/bin/gdbus flags=(attach_disconnected,mediate_deleted) {
    #include <abstractions/base>
    #include <abstractions/dbus>

    signal (receive) set=(int),
    unix (send, receive) type=stream,

    capability sys_nice,

    /** r,
    /lib/* mr,
    /usr/bin/gdbus mr,
    /usr/local/lib/** mr,

    /run/dbus/system_bus_socket rw,
  }

  profile /usr/bin/git flags=(attach_disconnected,mediate_deleted) {
    #include <abstractions/base>

    network,
    deny network raw,

    signal (receive) set=(term),

    /bin/busybox ix,
    /usr/bin/git mr,
    /usr/libexec/git-core/* ix,

    deny /data/homeassistant rw,
    deny /data/ssl rw,

    /** r,
    /lib/* mr,
    /data/addons/** lrw,
    /usr/local/lib/** mr,

    capability dac_override,
  }
}

NEF

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
$HASSIO_APPARMOR
$HASSIO_APPARMOR
FNE
chmod +x $APPARMOR_SETUP
$APPARMOR_SETUP

if [[ -d "$COMPOSE_DIR/docker-compose.yml" ]]; then
  COMPOSE_FILE=$COMPOSE_DIR/docker-compose.yml
fi

if [[ -d "$COMPOSE_DIR/docker-compose.yaml" ]]; then
  COMPOSE_FILE=$COMPOSE_DIR/docker-compose.yaml
fi
if [[ ! -d "$COMPOSE_FILE" ]]; then
  #non esiste nessuna delle due versioni del compose file pertanto lo creiamo
  COMPOSE_FILE=$COMPOSE_DIR/docker-compose.yaml  
  cat << EOF > $COMPOSE_FILE
version: '3.8'
services:
EOF
fi   

#sia che esista il compose o che lo abbia creato io, finisco di inserire i valori.
cat << EOF >> $COMPOSE_FILE
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
      - apparmor:hassio-supervisor

    environment:
      - SUPERVISOR_SHARE=$BASE_DIR
      - SUPERVISOR_NAME=hassio_supervisor
      - HOMEASSISTANT_REPOSITORY=homeassistant/qemux86-homeassistant
      - DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket
    ports:
      - "8124:8123"  
EOF
#docker-compose up -d 

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

