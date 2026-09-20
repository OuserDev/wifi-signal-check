# 주변 Wi-Fi AP 신호 세기를 강한 순으로 출력. 인자로 SSID 필터(부분일치) 가능.
# 사용법:  .\wifi-signal.ps1            (전체)
#          .\wifi-signal.ps1 cagong     (cagong 포함만)
param([string]$Filter = '')

$ssid = $null
$rows = foreach ($line in (netsh wlan show networks mode=bssid)) {
    # 'SSID 7 : cagongzok_2' — 로케일 무관하게 번호+콜론으로 잡는다
    if ($line -match '^SSID\s+\d+\s*:\s*(.*)$') {
        $ssid = $Matches[1].Trim()
    } elseif ($ssid -and $line -match ':\s*(\d{1,3})\s*%\s*$') {
        # '  신호 : 81%' / '  Signal : 81%' — 퍼센트로 끝나는 줄이 신호 세기
        [pscustomobject]@{ SSID = $ssid; Percent = [int]$Matches[1]; dBm = [int]$Matches[1] / 2 - 100 }
    }
}

if ($Filter) { $rows = @($rows | Where-Object { $_.SSID -like "*$Filter*" }) }
if (-not $rows) { Write-Host '잡히는 AP 없음 (Wi-Fi 꺼짐 또는 필터 불일치)'; exit 1 }

$sorted = $rows | Sort-Object Percent -Descending
$sorted | Format-Table -AutoSize
Write-Host "→ 가장 강함: $($sorted[0].SSID)  $($sorted[0].Percent)% (약 $($sorted[0].dBm) dBm)"
