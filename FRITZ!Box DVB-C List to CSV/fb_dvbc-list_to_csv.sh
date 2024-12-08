#!/bin/bash

FB_IP="192.168.178.1"

MERGED_M3U="dvbc.m3u"
DVBC_FREQ="dvbc-freq.txt"
DVBC_NAME="dvbc-name.txt"
CSV_OUTPUT="dvbc.csv"
M3U_LINK_PREFIX="dvb/m3u"
M3U_LISTS="radio.m3u
tvhd.m3u
tvsd.m3u"

rm -rf ${MERGED_M3U} ${DVBC_FREQ} ${DVBC_NAME} ${CSV_OUTPUT}
for M3U_LIST in ${M3U_LISTS}; do
        rm -rf ${M3U_LIST}
        wget http://${FB_IP}/${M3U_LINK_PREFIX}/${M3U_LIST} -O ${M3U_LIST}
        cat ${M3U_LIST} >> ${MERGED_M3U}
        RESULT=$?
        if [ $RESULT -ne 0 ]; then
                echo download http://${FB_IP}/${M3U_LINK_PREFIX}/${M3U_LIST} failed;
                exit 1;
        fi
done

cat ${MERGED_M3U} | grep "rtsp" > ${DVBC_FREQ}
cat ${MERGED_M3U} | grep "#EXTINF" > ${DVBC_NAME}

echo "Sendername,Frequenz,QAM,SR" > $CSV_OUTPUT
paste -d ',' <(awk -F'[=&]' '{for(i=1;i<=NF;i++) if($i=="freq") print $(i+1)}' ${DVBC_FREQ}) \
              <(awk -F'[=&]' '{for(i=1;i<=NF;i++) if($i=="mtype") print $(i+1)}' ${DVBC_FREQ}) \
              <(awk -F'[=&]' '{for(i=1;i<=NF;i++) if($i=="sr") print $(i+1)}' ${DVBC_FREQ}) \
              <(awk -F',' '{print $2}' ${DVBC_NAME}) | while IFS=',' read -r freq qam sr sendername; do
    echo "$sendername,$freq,$qam,$sr" >> ${CSV_OUTPUT}
done
