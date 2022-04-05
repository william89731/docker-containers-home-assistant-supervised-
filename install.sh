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
TIMEOUT=3	 
sleep $TIMEOUT	 

declare -a MISSING_PACKAGES

function info { echo -e "\e[32m[info] $*\e[39m"; }
function warn  { echo -e "\e[33m[warn] $*\e[39m"; }
function error { echo -e "\e[31m[error] $*\e[39m"; exit 1; }

if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root" 
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


#controlla se la directory è scrivibile dall'utente 
if [[ -d $BASE_DIR ]]; then
  echo -n "The $BASE_DIR folder already exists, do I delete its contents? [Y/N]: ";
  read;
  if [[ $REPLY =~ ^(Y) ]]; then
    sudo rm -rf $BASE_DIR
  else
    warn "$BASE_DIR folder cannot be deleted. Select another folder"
    exit 1
  fi
fi

#controllo la connessione di rete
while ! ping -c 1 -W 1 ${URL_VERSION_HOST}; do
    info "Waiting for ${URL_VERSION_HOST} - the network interface may be down ..."
    sleep $TIMEOUT
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
            error "Please set the machine type (-m) for $ARCH"
            info "machine type: intel-nuc / odroid-c2 / odroid-n2 / odroid-xu / qemuarm / qemuarm-64 / qemux86 / qemux86-64 / raspberrypi / raspberrypi2 / raspberrypi3 / raspberrypi4 / raspberrypi3-64 / raspberrypi4-64 / tinker"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/armhf-hassio-supervisor"
    ;;
    "armv7l")
        if [ -z $MACHINE ]; then
            error "Please set the machine type (-m) for $ARCH"
            info "machine type: intel-nuc / odroid-c2 / odroid-n2 / odroid-xu / qemuarm / qemuarm-64 / qemux86 / qemux86-64 / raspberrypi / raspberrypi2 / raspberrypi3 / raspberrypi4 / raspberrypi3-64 / raspberrypi4-64 / tinker"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/armv7-hassio-supervisor"
    ;;
    "aarch64")
        if [ -z $MACHINE ]; then
            error "Please set the machine type (-m) for $ARCH"
            info "machine type: intel-nuc / odroid-c2 / odroid-n2 / odroid-xu / qemuarm / qemuarm-64 / qemux86 / qemux86-64 / raspberrypi / raspberrypi2 / raspberrypi3 / raspberrypi4 / raspberrypi3-64 / raspberrypi4-64 / tinker"
        fi
        HASSIO_DOCKER="$DOCKER_REPO/aarch64-hassio-supervisor"
    ;;
    *)
        error "$ARCH unknown!"
        info "ARCH could be: i386 - i686 - x86_64 - arm - armv6l - armv7l - aarch64"
    ;;
esac

if [[ ! "${MACHINE}" =~ ^(generic-x86-64|odroid-c2|odroid-n2|odroid-xu|qemuarm|qemuarm-64|qemux86|qemux86-64|raspberrypi|raspberrypi2|raspberrypi3|raspberrypi4|raspberrypi3-64|raspberrypi4-64!tinker|khadas-vim3)$ ]]; then
    error "Unknown machine type: ${MACHINE}!"
    info "machine type: generic-x86-64, odroid-c2, odroid-n2, odroid-xu, qemuarm, qemuarm-64, qemux86, qemux86-64, raspberrypi, raspberrypi2, raspberrypi3, raspberrypi4, raspberrypi3-64, raspberrypi4-64, tinker, khadas-vim3"
fi


sleep $TIMEOUT

info "welcome "
printf "\U$(printf %08x 128520)\n"
sleep $TIMEOUT
warn "you are about to install home assistant supervised docker containers..."
sleep $TIMEOUT
info "let's start!"

#aggiungo i repo nel caso di ubuntu
if [[ "${DISTRO}" =~ ^(ubuntu)$ ]]; then
  add-apt-repository universe
fi

# controlla pacchetti mancanti
#command -v systemctl > /dev/null 2>&1 || MISSING_PACKAGES+=("systemd")
command -v nmcli > /dev/null 2>&1 || MISSING_PACKAGES+=("network-manager")
command -v apparmor_parser > /dev/null 2>&1 || MISSING_PACKAGES+=("apparmor-utils")
command -v jq > /dev/null 2>&1 || MISSING_PACKAGES+=("jq")
command -v curl > /dev/null 2>&1 || MISSING_PACKAGES+=("curl")
command -v dbus-daemon > /dev/null 2>&1 || MISSING_PACKAGES+=("dbus")
command -v socat > /dev/null 2>&1 || MISSING_PACKAGES+=("socat")
command -v btmon > /dev/null 2>&1 || MISSING_PACKAGES+=("bluetooth")
command -v update-ca-certificates > /dev/null 2>&1 || MISSING_PACKAGES+=("ca-certificates")
command -v avahi-daemon > /dev/null 2>&1 || MISSING_PACKAGES+=("avahi-daemon")

#warn "MISSING_PACKAGES=$MISSING_PACKAGES"

if [[ ! -z "$MISSING_PACKAGES" ]]; then
  info "I install the necessary packages ..."
  apt-get update
  apt-get install -y $MISSING_PACKAGES
  #software-properties-common : serve solo su ubuntu per installare il pacchetto add-apt-repository
  #apt-transport-https  bluez bluetooth libbluetooth-dev
fi
#verifico se modemmanager è installato
MODEMMANAGER=$(dpkg -l|grep ^modemmanager)
if [[ ! -z "$MODEMMANAGER" ]]; then
  #modemmanager presente, lo disabilito e disinstallo
  info "Disabled ModemManager"
  systemctl disable ModemManager
  apt-get purge -y modemmanager
  apt autoremove -y
fi

#creo le cartelle se non già presenti
if [ ! -d "$SCRIPT_DIR" ]; then
    mkdir -p "$SCRIPT_DIR"
fi
if [ ! -d "$DATA_SHARE" ]; then
    mkdir -p "$DATA_SHARE"
fi

HASSIO_VERSION=$(curl -s $URL_VERSION | jq -e -r '.supervisor')



#docker-compose.yml
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
    image: "$HASSIO_DOCKER"
    privileged: true

    volumes:
      - type: bind
        source: $DATA_SHARE
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
    #  - apparmor:hassio-supervisor

    environment:
      - SUPERVISOR_SHARE=$DATA_SHARE
      - SUPERVISOR_NAME=hassio_supervisor
      - HOMEASSISTANT_REPOSITORY=$DOCKER_REPO/$MACHINE-$DOCKER_REPO
      - DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket
    ports:
      - "8124:8123"  
EOF



sleep $TIMEOUT

echo "
╔╗ ╔╗╔═══╗╔═╗╔═╗╔═══╗    ╔═══╗╔═══╗╔═══╗╔══╗╔═══╗╔════╗╔═══╗╔═╗ ╔╗╔════╗
║║ ║║║╔═╗║║║╚╝║║║╔══╝    ║╔═╗║║╔═╗║║╔═╗║╚╣╠╝║╔═╗║║╔╗╔╗║║╔═╗║║║╚╗║║║╔╗╔╗║
║╚═╝║║║ ║║║╔╗╔╗║║╚══╗    ║║ ║║║╚══╗║╚══╗ ║║ ║╚══╗╚╝║║╚╝║║ ║║║╔╗╚╝║╚╝║║╚╝
║╔═╗║║║ ║║║║║║║║║╔══╝    ║╚═╝║╚══╗║╚══╗║ ║║ ╚══╗║  ║║  ║╚═╝║║║╚╗║║  ║║  
║║ ║║║╚═╝║║║║║║║║╚══╗    ║╔═╗║║╚═╝║║╚═╝║╔╣╠╗║╚═╝║ ╔╝╚╗ ║╔═╗║║║ ║║║ ╔╝╚╗ 
╚╝ ╚╝╚═══╝╚╝╚╝╚╝╚═══╝    ╚╝ ╚╝╚═══╝╚═══╝╚══╝╚═══╝ ╚══╝ ╚╝ ╚╝╚╝ ╚═╝ ╚══╝ "
                                                                        
                                                                        

                                                                        
sleep $TIMEOUT                                                                        

info "end of installation. HAVE FUN!"



echo "
	╔══╗ ╔╗  ╔╗╔═══╗    ╔══╗ ╔╗  ╔╗╔═══╗
	║╔╗║ ║╚╗╔╝║║╔══╝    ║╔╗║ ║╚╗╔╝║║╔══╝
	║╚╝╚╗╚╗╚╝╔╝║╚══╗    ║╚╝╚╗╚╗╚╝╔╝║╚══╗
	║╔═╗║ ╚╗╔╝ ║╔══╝    ║╔═╗║ ╚╗╔╝ ║╔══╝
	║╚═╝║  ║║  ║╚══╗    ║╚═╝║  ║║  ║╚══╗
	╚═══╝  ╚╝  ╚═══╝    ╚═══╝  ╚╝  ╚═══╝"

