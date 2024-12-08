$FB_IP = "192.168.178.1"

$MERGED_M3U = "dvbc.m3u"
$DVBC_FREQ = "dvbc-freq.txt"
$DVBC_NAME = "dvbc-name.txt"
$CSV_OUTPUT = "dvbc.csv"
$M3U_LINK_PREFIX = "dvb/m3u"
$M3U_LISTS = @("radio.m3u", "tvhd.m3u", "tvsd.m3u")

Remove-Item -Path $MERGED_M3U, $DVBC_FREQ, $DVBC_NAME, $CSV_OUTPUT -ErrorAction Ignore

foreach ($M3U_LIST in $M3U_LISTS) {
    Remove-Item -Path $M3U_LIST -ErrorAction Ignore
    Invoke-WebRequest -Uri "http://$FB_IP/$M3U_LINK_PREFIX/$M3U_LIST" -OutFile $M3U_LIST
    if ($?) {
        Get-Content -Path $M3U_LIST | Add-Content -Path $MERGED_M3U
    } else {
        Write-Host "Download http://$FB_IP/$M3U_LINK_PREFIX/$M3U_LIST failed"
        exit 1
    }
}

Get-Content -Path $MERGED_M3U | Select-String -Pattern "rtsp" | Set-Content -Path $DVBC_FREQ
Get-Content -Path $MERGED_M3U | Select-String -Pattern "#EXTINF" | Set-Content -Path $DVBC_NAME

"Sendername,Frequenz,QAM,SR" | Out-File -FilePath $CSV_OUTPUT -Encoding UTF8

$freqs = Get-Content -Path $DVBC_FREQ -Encoding UTF8 | ForEach-Object { $_ -match 'freq=([^&]+)' | Out-Null; $matches[1] }
$qams = Get-Content -Path $DVBC_FREQ -Encoding UTF8 | ForEach-Object { $_ -match 'mtype=([^&]+)' | Out-Null; $matches[1] }
$srs = Get-Content -Path $DVBC_FREQ -Encoding UTF8 | ForEach-Object { $_ -match 'sr=([^&]+)' | Out-Null; $matches[1] }
$names = Get-Content -Path $DVBC_NAME -Encoding UTF8 | ForEach-Object { $_ -split ',' | Select-Object -Last 1 }

for ($i = 0; $i -lt $freqs.Length; $i++) {
    "$($names[$i]),$($freqs[$i]),$($qams[$i]),$($srs[$i])" | Out-File -FilePath $CSV_OUTPUT -Append -Encoding UTF8
}
