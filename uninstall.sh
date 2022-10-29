#!/bin/bash

TIMEOUT=3    
declare -a MISSING_PACKAGES
function info { echo -e "\e[32m[info] $*\e[39m"; }
function warn  { echo -e "\e[33m[warn] $*\e[39m"; }
function error { echo -e "\e[31m[error] $*\e[39m"; exit 1; }

echo "
REMOVAL OF
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
  sleep 0.3 # this is work
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

war "rimozione di home assistant!"
sleep $TIMEOUT
info "cominciamo!"

if [[ -f "/root/.ha_uninstall" ]]; then
    . /root/.ha_uninstall
else 
    echo -n "In quale percorso è installato HA supervised?"
    read BASE_DIR;
fi
if [[ ! -f "$COMPOSE_FILE" || -d "$COMPOSE_DIR" ]]; then
    # il parametro COMPOSE_FILE e/o COMPOSE_DIR non esistono o non sono file/dir
    # cerco il compose file nella directory di installazione
    if [[ -f "$BASE_DIR/docker-compose.yml" ]]; then
      COMPOSE_FILE=$BASE_DIR/docker-compose.yml
    fi

    if [[ -f "$BASE_DIR/docker-compose.yaml" ]]; then
      COMPOSE_FILE=$BASE_DIR/docker-compose.yaml
    fi
    if [[ ! -f "$COMPOSE_FILE" ]]; then
      #non esiste nessuna delle due versioni del compose file pertanto lo chiediamo
      echo "Non trovo il file docker-compose.yaml nella cartella $BASE_DIR"
      echo -n "Mi sai indicare il percorso del docker-compose? "
      read COMPOSE_FILE;
    fi
fi
cd $BASE_DIR

docker-compose -f $COMPOSE_FILE down --remove-orphans

docker stop hassio_audio
docker stop hassio_cli
docker stop hassio_dns
docker stop hassio_multicast
docker stop hassio_observer
docker stop homeassistant

docker rm hassio_audio
docker rm hassio_cli
docker rm hassio_dns
docker rm hassio_multicast
docker rm hassio_observer
docker rm homeassistant

ADDONS=$(docker ps -f name=addon_core -q)
for addon in ${ADDONS}; do 
    docker stop $addon
    docker rm $addon
done;

systemctl stop hassio-apparmor.service
systemctl disable hassio-apparmor.service
rm -rf /etc/systemd/system/hassio-apparmor.service
systemctl stop systemd-journal-gatewayd.socket
systemctl disable systemd-journal-gatewayd.socket
rm -rf /usr/lib/systemd/system/systemd-journal-gatewayd.socket

info "If you want to free disk space run as root"
info "docker image prune -a"
info "Do you want to run it now? [Y/N]"
read;
if [[ $REPLY =~ ^(Y) ]]; then
    sudo docker image prune -a -f --filtet until=1h
fi

rm -rf COMPOSE_FILE
#just don't delete data
#rm -rf DATA_SHARE
#rm -rf $BASE_DIR
rm -rf /root/.ha_uninstall

sleep 3                                                                        

echo "
    ╔══╗ ╔╗  ╔╗╔═══╗    ╔══╗ ╔╗  ╔╗╔═══╗
    ║╔╗║ ║╚╗╔╝║║╔══╝    ║╔╗║ ║╚╗╔╝║║╔══╝
    ║╚╝╚╗╚╗╚╝╔╝║╚══╗    ║╚╝╚╗╚╗╚╝╔╝║╚══╗
    ║╔═╗║ ╚╗╔╝ ║╔══╝    ║╔═╗║ ╚╗╔╝ ║╔══╝
    ║╚═╝║  ║║  ║╚══╗    ║╚═╝║  ║║  ║╚══╗
    ╚═══╝  ╚╝  ╚═══╝    ╚═══╝  ╚╝  ╚═══╝"
