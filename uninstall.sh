#!/bin/bash
TIMEOUT=1
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
echo "Benvenuto,figlio della perdizione "
printf "\U$(printf %08x 128520)\n"
sleep $TIMEOUT
echo "rimozione di home assistant!"
sleep $TIMEOUT
echo "cominciamo!"

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


rm -rf $BASE_DIR
rm -rf /root/.ha_uninstall

sleep 3                                                                        

echo "
	╔══╗ ╔╗  ╔╗╔═══╗    ╔══╗ ╔╗  ╔╗╔═══╗
	║╔╗║ ║╚╗╔╝║║╔══╝    ║╔╗║ ║╚╗╔╝║║╔══╝
	║╚╝╚╗╚╗╚╝╔╝║╚══╗    ║╚╝╚╗╚╗╚╝╔╝║╚══╗
	║╔═╗║ ╚╗╔╝ ║╔══╝    ║╔═╗║ ╚╗╔╝ ║╔══╝
	║╚═╝║  ║║  ║╚══╗    ║╚═╝║  ║║  ║╚══╗
	╚═══╝  ╚╝  ╚═══╝    ╚═══╝  ╚╝  ╚═══╝"
