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
echo "rimozione di home assistant!"
sleep 3
echo "cominciamo!"

WD=/opt/hassio
cd $WD/setup
docker-compose down --remove-orphans

rm -rf /opt/hassio
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

sleep 3                                                                        

echo "alla prossima. bye bye!"
