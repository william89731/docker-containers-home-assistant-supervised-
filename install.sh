#!/bin/bash

declare -a MISSING_PACKAGES

function info { echo -e "\e[32m[info] $*\e[39m"; }
function warn  { echo -e "\e[33m[warn] $*\e[39m"; }
function error { echo -e "\e[31m[error] $*\e[39m"; exit 1; }

if [[ $EUID -ne 0 ]]; then
   error "Questo script deve essere eseguito come root" 
   exit 1
fi
#parametri per la scelta del repo e dell'architettura
ARCH=$(uname -m)
IP_ADDRESS=$(hostname -I | awk '{ print $1 }')

# Parse command line parameters
while [[ $# -gt 0 ]]; do
    arg="$1"

    case $arg in
        -m|--machine)
            MACHINE=$2
            shift
            ;;
        -d|--data-share)
            DATA_SHARE=$2
            shift
            ;;
        -p|--prefix)
            BASE_DIR=$2
            shift
            ;;
        -s|--scriptdir)
            SCRIPT_DIR=$2
            shift
            ;;
        *)
            error "Unrecognized option $1"
            ;;
    esac
    shift
done

BASE_DIR=${BASE_DIR:-/opt/hassio}
SCRIPT_DIR=${SCRIPT_DIR:-$BASE_DIR/scripts}
DATA_SHARE=${DATA_SHARE:-$BASE_DIR}
DOCKER_REPO=homeassistant

URL_VERSION_HOST="version.home-assistant.io"
URL_VERSION="https://version.home-assistant.io/stable.json"
URL_APPARMOR_PROFILE="https://version.home-assistant.io/apparmor.txt"

#da qui si possono impostare tutti i parametri dei files e delle cartelle
APPARMOR_SETUP=$SCRIPT_DIR/apparmor_setup.sh
HASSIO_APPARMOR=$SCRIPT_DIR/hassio-apparmor
HASSIO_JSON=$SCRIPT_DIR/hassio.json
#trovo quale distro è
DISTRO=$(cat /etc/issue|awk '{print $1}'|tr '[:upper:]' '[:lower:]')
COMPOSE_DIR=$BASE_DIR
TIMEOUT=1

#controllo la connessione di rete
while ! ping -c 1 -W 1 ${URL_VERSION_HOST}; do
    info "In attesa di ${URL_VERSION_HOST} - l'interfaccia di rete potrebbe esseere inattiva..."
    sleep 2
done

# Genera le info HW
case $ARCH in
    "i386" | "i686")
        MACHINE=${MACHINE:=qemux86}
        HASSIO_DOCKER="$DOCKER_REPO/i386-hassio-supervisor"
    ;;
    "x86_64")
        MACHINE=${MACHINE:=qemux86-64}
        HASSIO_DOCKER="$DOCKER_REPO/amd64-hassio-supervisor"
    ;;
    "arm" |"armv6l")
        if [ -z $MACHINE ]; then
            error "Per favore imposta il tipo di macchina (-m) per $ARCH"
            info "Tipo di macchina: intel-nuc / odroid-c2 / odroid-n2 / odroid-xu / qemuarm / qemuarm-64 / qemux86 / qemux86-64 / raspberrypi / raspberrypi2 / raspberrypi3 / raspberrypi4 / raspberrypi3-64 / raspberrypi4-64 / tinker"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/armhf-hassio-supervisor"
    ;;
    "armv7l")
        if [ -z $MACHINE ]; then
            error "Per favore imposta il tipo di macchina (-m) per $ARCH"
            info "Tipo di macchina: intel-nuc / odroid-c2 / odroid-n2 / odroid-xu / qemuarm / qemuarm-64 / qemux86 / qemux86-64 / raspberrypi / raspberrypi2 / raspberrypi3 / raspberrypi4 / raspberrypi3-64 / raspberrypi4-64 / tinker"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/armv7-hassio-supervisor"
    ;;
    "aarch64")
        if [ -z $MACHINE ]; then
            error "Per favore imposta il tipo di macchina (-m) per $ARCH"
            info "Tipo di macchina: intel-nuc / odroid-c2 / odroid-n2 / odroid-xu / qemuarm / qemuarm-64 / qemux86 / qemux86-64 / raspberrypi / raspberrypi2 / raspberrypi3 / raspberrypi4 / raspberrypi3-64 / raspberrypi4-64 / tinker"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/aarch64-hassio-supervisor"
    ;;
    *)
        error "$ARCH sconosciuta!"
        info "ARCH puo' essere: i386 - i686 - x86_64 - arm - armv6l - armv7l - aarch64"
    ;;
esac

if [[ ! "${MACHINE}" =~ ^(generic-x86-64|odroid-c2|odroid-n2|odroid-xu|qemuarm|qemuarm-64|qemux86|qemux86-64|raspberrypi|raspberrypi2|raspberrypi3|raspberrypi4|raspberrypi3-64|raspberrypi4-64!tinker|khadas-vim3)$ ]]; then
    error "Tipo di macchina sconosciuta: ${MACHINE}!"
    info "Tipo di macchina: generic-x86-64, odroid-c2, odroid-n2, odroid-xu, qemuarm, qemuarm-64, qemux86, qemux86-64, raspberrypi, raspberrypi2, raspberrypi3, raspberrypi4, raspberrypi3-64, raspberrypi4-64, tinker, khadas-vim3"
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
sleep $TIMEOUT
info "Benvenuto,figlio della perdizione "
#questo codice non funziona su Debian
printf "\U$(printf %08x 128520)\n"
sleep $TIMEOUT
warn "stai per installare dei containers docker di home assistant supervised !"
sleep $TIMEOUT
info "cominciamo!"

#aggiungo i repo nel caso di ubuntu
if [[ "${DISTRO}" =~ ^(ubuntu)$ ]]; then
  add-apt-repository universe
fi

# controlla pacchetti mancanti
#command -v systemctl > /dev/null 2>&1 || MISSING_PACKAGES+=("systemd")
command -v nmcli > /dev/null 2>&1 || MISSING_PACKAGES+=("network-manager")
command -v apparmor_parser > /dev/null 2>&1 || MISSING_PACKAGES+=("apparmor")
command -v docker > /dev/null 2>&1 || MISSING_PACKAGES+=("docker")
command -v jq > /dev/null 2>&1 || MISSING_PACKAGES+=("jq")
command -v curl > /dev/null 2>&1 || MISSING_PACKAGES+=("curl")
command -v dbus-daemon > /dev/null 2>&1 || MISSING_PACKAGES+=("dbus")

info "Installo i pacchetti necessari..."
apt-get update
apt-get install -y apparmor-utils avahi-daemon ca-certificates curl dbus jq network-manager socat software-properties-common bluez bluetooth libbluetooth-dev
#apt-transport-https  
info "Disabilito ModemManager"
systemctl disable ModemManager
apt-get purge -y modemmanager
apt autoremove -y

#creo le cartelle se non già presenti
if [ ! -d "$SCRIPT_DIR" ]; then
    mkdir -p "$SCRIPT_DIR"
fi
if [ ! -d "$DATA_SHARE" ]; then
    mkdir -p "$DATA_SHARE"
fi

HASSIO_VERSION=$(curl -s $URL_VERSION | jq -e -r '.supervisor')

cd $SCRIPT_DIR

#rendiamo il file parametrico - ho tolto le referenze a /opt/hassio e sostituito con $BASE_DIR
info "creo il file $APPARMOR_SETUP"
info "creo il file $HASSIO_JSON"
info "creo il file $HASSIO_APPARMOR"
cat << FNE > $APPARMOR_SETUP
cat << EOF > $HASSIO_JSON
{
    "supervisor": "${HASSIO_DOCKER}",
    "machine": "${MACHINE}",
    "data": "${DATA_SHARE}"
}
EOF

cat << 'FOE' > $HASSIO_APPARMOR
#!/usr/bin/env bash
set -e

# leggi config
DATA="\$(jq --raw-output '.data // "/usr/share/hassio"' ${HASSIO_JSON})"
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

curl -sL ${URL_APPARMOR_PROFILE} > "\${PROFILES_DIR}/hassio-supervisor"

# Load/Update profili
for profile in "\${PROFILES_DIR}"/*; do
    if [ ! -f "\${profile}" ]; then
        continue
    fi

    # Carica i profili apparmor
    if ! apparmor_parser -r -W -L "\${CACHE_DIR}" "\${profile}"; then
        echo "[Errore]: Non riesco a caricare il profilo \${profile}"
    fi
done

# Pulisci i vecchi profili
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
    echo "[Error]: Non riesco a rimuovere il profilo \${profile}"
done
FOE
chmod +x $HASSIO_APPARMOR
#repeated on purpose
$HASSIO_APPARMOR
$HASSIO_APPARMOR
FNE
chmod +x $APPARMOR_SETUP
$APPARMOR_SETUP

if [[ -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
  COMPOSE_FILE=$COMPOSE_DIR/docker-compose.yml
fi

if [[ -f "$COMPOSE_DIR/docker-compose.yaml" ]]; then
  COMPOSE_FILE=$COMPOSE_DIR/docker-compose.yaml
fi
if [[ ! -f "$COMPOSE_FILE" ]]; then
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

info "Memorizzo i percorsi per la disinstallazione"
#è corretto memorizzarli qui?
cat << EOF > /root/.ha_uninstall
BASE_DIR=$BASE_DIR
SCRIPT_DIR=$SCRIPT_DIR
DATA_SHARE=$DATA_SHARE
COMPOSE_DIR=$COMPOSE_DIR
EOF

info "fine installazione. BUON DIVERTIMENTO"
info "E' stato installato Home Assistant Supervised versione ${HASSIO_VERSION}"
info "Puoi trovare la tua installazione a http://${IP_ADDRESS}:8123"

