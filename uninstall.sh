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

sleep 3                                                                        

echo "alla prossima. bye bye!"
