@echo off

pushd "%CD%"
CD /D "%~dp0"

TITLE Vorbereite Senderliste

set FRITZBOX-IP=192.168.178.1

aria2c.exe http://%FRITZBOX-IP%/dvb/m3u/radio.m3u
aria2c.exe http://%FRITZBOX-IP%/dvb/m3u/tvhd.m3u
aria2c.exe http://%FRITZBOX-IP%/dvb/m3u/tvsd.m3u

copy *.m3u tvlist.txt
type tvlist.txt | find "rtsp" > tvfreq.txt
type tvlist.txt | find "#EXTINF" > tvname.txt

cls
ECHO die Tabelle wird aufgerufen (Microsoft Office vorausgesetzt)
echo --
ECHO fuege den Text aus der tvfreq.txt in den Tabellen-Reiter "tvfreq"
ECHO fuege den Text aus der tvname.txt in den Tabellen-Reiter "tvname"
echo --
ECHO danach wird dadurch eine Senderliste in der Tabellen-Reiter "senderliste" erstellt.
echo Zum aufrufen des Tabellen-Reiters "senderliste"
echo wird bei Microsoft Office die Privottabelle vorausgesetzt falls mit installiert.
echo --
echo in den Tabellen-Reiter "senderliste" mit der Privottabelle, die Tastenkompo. "Alt+F5"
echo druecken und die Tabelle wird aktuallisiert mit den werten.

timeout 2
explorer .\TV-Senderliste.xltx
echo --
pause

cls
echo Fertig
pause
exit