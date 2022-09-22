#!/bin/bash

# Script should work from Fritz OS 6.0 (2013) - also for the 6.8x and 6.9x 
# This bash script uses the TR-064 protocol and does not use the WEBCM interface

# http://fritz.box:49000/tr64desc.xml
# https://wiki.fhem.de/wiki/FRITZBOX#TR-064
# https://avm.de/service/schnittstellen/

# Thanks to Dragonfly (https://homematic-forum.de/forum/viewtopic.php?t=27994)


###=======###
# Variablen #
###=======###

IPS="192.168.178.1
192.168.178.20"

FRITZUSER=""
FRITZPW="0000"


###====###
# Skript #
###====###

location="/upnp/control/userif"
uri="urn:dslforum-org:service:UserInterface:1"
action='X_AVM-DE_DoUpdate'

for IP in ${IPS}; do
	curl -k -m 5 --anyauth -u "$FRITZUSER:$FRITZPW" http://$IP:49000$location -H 'Content-Type: text/xml; charset="utf-8"' -H "SoapAction:$uri#$action" -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'></u:$action></s:Body></s:Envelope>" -s
done
