#!/bin/bash

TIMEOUT=0	 
declare -a MISSING_PACKAGES
function info { echo -e "\e[32m[info] $*\e[39m"; }
function warn  { echo -e "\e[33m[warn] $*\e[39m"; }
function error { echo -e "\e[31m[error] $*\e[39m"; exit 1; }

echo "
╔╗ ╔╗╔═══╗╔═╗╔═╗╔═══╗    ╔═══╗╔═══╗╔═══╗╔══╗╔═══╗╔════╗╔═══╗╔═╗ ╔╗╔════╗
║║ ║║║╔═╗║║║╚╝║║║╔══╝    ║╔═╗║║╔═╗║║╔═╗║╚╣╠╝║╔═╗║║╔╗╔╗║║╔═╗║║║╚╗║║║╔╗╔╗║
║╚═╝║║║ ║║║╔╗╔╗║║╚══╗    ║║ ║║║╚══╗║╚══╗ ║║ ║╚══╗╚╝║║╚╝║║ ║║║╔╗╚╝║╚╝║║╚╝
║╔═╗║║║ ║║║║║║║║║╔══╝    ║╚═╝║╚══╗║╚══╗║ ║║ ╚══╗║  ║║  ║╚═╝║║║╚╗║║  ║║  
║║ ║║║╚═╝║║║║║║║║╚══╗    ║╔═╗║║╚═╝║║╚═╝║╔╣╠╗║╚═╝║ ╔╝╚╗ ║╔═╗║║║ ║║║ ╔╝╚╗ 
╚╝ ╚╝╚═══╝╚╝╚╝╚╝╚═══╝    ╚╝ ╚╝╚═══╝╚═══╝╚══╝╚═══╝ ╚══╝ ╚╝ ╚╝╚╝ ╚═╝ ╚══╝ "
sleep $TIMEOUT
echo ""
echo ""
warn "press ctr+c to abort this script"	 
count=0
total=34
pstr="[=======================================================================] "
while [ $count -lt $total ]; do
  sleep 0.1 # this is work
  count=$(( $count + 1 ))
  pd=$(( $count * 73 / $total ))
  printf "\r%3d.%1d%% %.${pd}s" $(( $count * 100 / $total )) $(( ($count * 1000 / $total) % 10 )) $pstr  
done	 
echo ""
echo ""

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
#cartella per i daati
DATA_SHARE=${DATA_SHARE:-$BASE_DIR/data}
SCRIPT_DIR=${SCRIPT_DIR:-$DATA_SHARE/scripts}
DOCKER_REPO=homeassistant

URL_VERSION_HOST="version.home-assistant.io"
URL_VERSION="https://version.home-assistant.io/stable.json"
URL_APPARMOR_PROFILE="https://version.home-assistant.io/apparmor.txt"

#da qui si possono impostare tutti i parametri dei files e delle cartelle
#cartella per i profili apparmor
APPARMOR_DIR=${DATA_SHARE}/apparmor
#profilo apparmor per HA 
HASSIO_APPARMOR=$APPARMOR_DIR/hassio-apparmor
#script per caricare i profili apparmor
APPARMOR_SETUP=$SCRIPT_DIR/apparmor_setup.sh
#file di configurazione per docker
#HASSIO_JSON=$SCRIPT_DIR/hassio.json
#trovo quale distro è
DISTRO=$(cat /etc/issue|awk '{print $1}'|tr '[:upper:]' '[:lower:]')
COMPOSE_DIR=$BASE_DIR
UNINSTALL_FILE=/root/.ha_uninstall

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
# CREO LE ALTRE CARTELLE NECESSARIE
if [[ ! -d $SCRIPT_DIR ]]; then
    mkdir -p $SCRIPT_DIR
fi
if [[ ! -d $APPARMOR_DIR ]]; then
    mkdir -p $APPARMOR_DIR
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
        MACHINE=${MACHINE:=raspberrypi4-64}
        HASSIO_DOCKER="$DOCKER_REPO/aarch64-hassio-supervisor"
    ;;
    *)
        error "$ARCH unknown!"
        info "ARCH could be: i386 - i686 - x86_64 - arm - armv6l - armv7l - aarch64"
    ;;
esac

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

warn "MISSING_PACKAGES=$MISSING_PACKAGES"

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

#install il file di configurazione di docker
if [[ -f /etc/docker/daemon.json ]]; then
    warn "Il file /etc/docker/daemon.json esiste gia."
    warn "Modificarlo a mano per inserire i seguenti valori"
    warn '{ 
    "log-driver": "journald",
    "storage-driver": "overlay2",
    "ip6tables": true,
    "experimental": true,
    "log-opts": {
        "tag": "{{.Name}}"
        }
    }'
else 
    cat << EFO > /etc/docker/daemon.json 
{
    "log-driver": "journald",
    "storage-driver": "overlay2",
    "ip6tables": true,
    "experimental": true,
    "log-opts": {
        "tag": "{{.Name}}"
    }
}
EFO
fi

cat << FOE > /etc/systemd/system/hassio-apparmor.service
[Unit]
Description=Hass.io AppArmor
#Wants=hassio-supervisor.service
Before=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=${APPARMOR_SETUP}

[Install]
WantedBy=multi-user.target
FOE


cat << FEO > /usr/lib/systemd/system/systemd-journal-gatewayd.socket
[Unit]
Description=Journal Gateway Service Socket
Documentation=man:systemd-journal-gatewayd(8)

[Socket]
ListenStream=/run/systemd-journal-gatewayd.sock

[Install]
WantedBy=sockets.target
FEO

HASSIO_VERSION=$(curl -s $URL_VERSION | jq -e -r '.supervisor')

#Install AppArmor - downlod profile and save it
curl -sL ${URL_APPARMOR_PROFILE} > "${HASSIO_APPARMOR}"


# create apparmor-setup.sh
cat << END > $APPARMOR_SETUP
#!/usr/bin/env bash
set -e

# Read configs
DATA=${DATA_SHARE}
PROFILES_DIR=${APPARMOR_DIR}
CACHE_DIR="\${PROFILES_DIR}/cache"

# Check folder structure
mkdir -p "\${PROFILES_DIR}"
mkdir -p "\${CACHE_DIR}"

# Load existing profiles
for profile in "\${PROFILES_DIR}"/*; do
    if [ ! -f "\${profile}" ]; then
        continue
    fi

    # Load Profile
    if ! apparmor_parser -r -W -L "\${CACHE_DIR}" "\${profile}"; then
        echo "[Error]: Can't load profile \${profile}"
    fi
done
END

chmod +x ${APPARMOR_SETUP}

#eseguo lo script app_armor setupd
info "Loading apparmor profiles..."
#$APPARMOR_SETUP
systemctl enable hassio-apparmor.service> /dev/null 2>&1;
systemctl start hassio-apparmor.service> /dev/null 2>&1;
systemctl enable systemd-journal-gatewayd.socket> /dev/null 2>&1;
systemctl start systemd-journal-gatewayd.socket> /dev/null 2>&1;

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
  cat << NED > $COMPOSE_FILE
version: '3.8'
services:
NED
fi   

#sia che esista il compose o che lo abbia creato io, finisco di inserire i valori.
cat << DEN >> $COMPOSE_FILE
  hassio_supervisor:
    container_name: hassio_supervisor
    image: "$HASSIO_DOCKER"
    privileged: true
    restart: "always"

    volumes:
      - $DATA_SHARE:/data
      - /run/docker.sock:/run/docker.sock:rw
      - /run/systemd-journal-gatewayd.sock:/run/systemd-journal-gatewayd.sock:rw
      - /run/dbus:/run/dbus:ro
      - /run/udev:/run/udev:ro
      - /etc/machine-id:/etc/machine-id:ro
      - /etc/localtime:/etc/localtime
      - /dev/bus/usb:/dev/bus/usb

    security_opt:
      - seccomp:unconfined
      - apparmor:hassio-supervisor

    environment:
      - SUPERVISOR_SHARE=$DATA_SHARE
      - SUPERVISOR_NAME=hassio_supervisor
      - SUPERVISOR_MACHINE=${MACHINE}
      - HOMEASSISTANT_REPOSITORY=$DOCKER_REPO/$MACHINE-$DOCKER_REPO
      - DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket
    ports:
      - "8124:8123"  
DEN
sleep $TIMEOUT   
if [[ -f ${UNINSTALL_FILE} ]]; then
    #piallo il file
    truncate -s 0 $UNINSTALL_FILE
else
    touch $UNINSTALL_FILE
fi
echo "COMPOSE_FILE=${COMPOSE_FILE}" >> ${UNINSTALL_FILE}
echo "BASE_DIR=${BASE_DIR}" >> ${UNINSTALL_FILE}
echo "COMPOSE_DIR=${COMPOSE_DIR}" >> ${UNINSTALL_FILE}
echo "DATA_SHARE=${DATA_SHARE}" >> ${UNINSTALL_FILE}

echo ""
echo "Now give this command"                                                                  
echo "docker-compose -f $COMPOSE_DIR/docker-compose.yaml up -d"
echo "Wait for some minute for the system to come up and then digit this address in the browser"
echo "http://$IP_ADDRESS:8123"
info "end of installation. HAVE FUN!"
