<#
  주변 Wi-Fi AP 신호 세기를 여러 번 측정해 평균으로 순위를 낸다.

  그냥 실행하면 측정 횟수와 SSID를 순서대로 물어본다.
    .\wifi-signal.ps1

  인자로 넘기면 묻지 않는다 (배치/예약 실행용).
    .\wifi-signal.ps1 cagong 5              cagong 포함 AP, 5회
    .\wifi-signal.ps1 '' 5                  전체 AP, 5회
    .\wifi-signal.ps1 cagong 5 -DelaySec 8  스캔 요청 후 8초 대기
    .\wifi-signal.ps1 -SelfTest             파서 자체 검사

  중요: netsh는 스캔을 새로 돌리지 않고 드라이버가 캐시한 결과만 돌려준다.
  그냥 반복 호출하면 같은 값이 그대로 복사되고, 캐시가 비어 있으면 AP가
  한두 개만 잡히기도 한다. 그래서 매 회차마다 wlanapi.dll의 WlanScan()으로
  실제 스캔을 요청하고(Wi-Fi 목록 UI가 쓰는 그 API, 관리자 권한 불필요)
  결과가 올라올 시간을 -DelaySec 만큼 기다린다.
#>
param(
    [string]$Filter = '',
    [int]$Count = 0,
    [int]$DelaySec = 5,
    [switch]$SelfTest
)

# netsh 출력 → @{SSID; Percent} 목록. 로케일 무관(SSID 줄 + %로 끝나는 줄만 본다).
function ConvertFrom-NetshWlan([string[]]$Lines) {
    $ssid = $null
    foreach ($line in $Lines) {
        if ($line -match '^SSID\s+\d+\s*:\s*(.*)$') {
            $ssid = $Matches[1].Trim()
        } elseif ($ssid -and $line -match ':\s*(\d{1,3})\s*%\s*$') {
            [pscustomobject]@{ SSID = $ssid; Percent = [int]$Matches[1] }
        }
    }
}

if ($SelfTest) {
    $ko = @('SSID 1 : ko_ap', '    신호 : 81%  ', '    채널 : 36')   # %없는 숫자 줄은 무시돼야 함
    $en = @('SSID 2 : en_ap', '    Signal : 42%')
    $r = @(ConvertFrom-NetshWlan ($ko + $en))
    if ($r.Count -ne 2) { throw "SelfTest 실패: 2개 기대, $($r.Count)개" }
    if ($r[0].SSID -ne 'ko_ap' -or $r[0].Percent -ne 81) { throw "SelfTest 실패: 한글 파싱" }
    if ($r[1].SSID -ne 'en_ap' -or $r[1].Percent -ne 42) { throw "SelfTest 실패: 영문 파싱" }
    Write-Host 'SelfTest OK'
    exit 0
}

# 인자를 안 줬으면 직접 물어본다 (탐색기에서 실행한 경우 포함)
$asked = $false

if ($Count -lt 1) {
    $asked = $true
    while ($true) {
        $in = Read-Host '원하는 측정 횟수를 입력해주세요 (Enter = 5)'
        if ([string]::IsNullOrWhiteSpace($in)) { $Count = 5; break }
        if ($in -match '^\d+$' -and [int]$in -ge 1) { $Count = [int]$in; break }
        Write-Host '1 이상의 숫자로 입력해주세요.' -ForegroundColor Yellow
    }
}

if (-not $PSBoundParameters.ContainsKey('Filter')) {
    $asked = $true
    $Filter = (Read-Host '찾을 SSID를 입력해주세요, 일부만 입력해도 됩니다 (Enter = 전체)').Trim()
}

if ($asked) {
    $what = if ($Filter) { "'$Filter' 포함 AP" } else { '전체 AP' }
    Write-Host "$what, $Count 회 측정 — 약 $($Count * $DelaySec)초 소요`n"
}

# 드라이버에 실제 스캔을 요청한다. 실패하면 $false (캐시만 읽고 진행).
function Request-WlanScan {
    if (-not ('W.Lan' -as [type])) {
        Add-Type -Namespace W -Name Lan -MemberDefinition @'
[DllImport("wlanapi.dll")] public static extern int WlanOpenHandle(uint v, IntPtr r, out uint n, out IntPtr h);
[DllImport("wlanapi.dll")] public static extern int WlanEnumInterfaces(IntPtr h, IntPtr r, out IntPtr list);
[DllImport("wlanapi.dll")] public static extern int WlanScan(IntPtr h, ref Guid g, IntPtr ssid, IntPtr ie, IntPtr r);
[DllImport("wlanapi.dll")] public static extern int WlanCloseHandle(IntPtr h, IntPtr r);
[DllImport("wlanapi.dll")] public static extern void WlanFreeMemory(IntPtr p);
'@
    }
    $h = [IntPtr]::Zero; $ver = 0; $list = [IntPtr]::Zero
    try {
        if ([W.Lan]::WlanOpenHandle(2, [IntPtr]::Zero, [ref]$ver, [ref]$h) -ne 0) { return $false }
        if ([W.Lan]::WlanEnumInterfaces($h, [IntPtr]::Zero, [ref]$list) -ne 0) { return $false }
        if ([Runtime.InteropServices.Marshal]::ReadInt32($list, 0) -lt 1) { return $false }
        # WLAN_INTERFACE_INFO_LIST: [0]=개수 [4]=인덱스 [8]=첫 인터페이스 GUID
        $guid = [Runtime.InteropServices.Marshal]::PtrToStructure([IntPtr]::Add($list, 8), [Type][Guid])
        return ([W.Lan]::WlanScan($h, [ref]$guid, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero) -eq 0)
    } catch { return $false }
    finally {
        if ($list -ne [IntPtr]::Zero) { [W.Lan]::WlanFreeMemory($list) }
        if ($h -ne [IntPtr]::Zero) { [void][W.Lan]::WlanCloseHandle($h, [IntPtr]::Zero) }
    }
}

$samples = foreach ($i in 1..$Count) {
    Write-Host "스캔 $i/$Count ..." -NoNewline
    if (-not (Request-WlanScan)) { Write-Host ' (스캔 요청 실패, 캐시 사용)' -NoNewline }
    Start-Sleep -Seconds $DelaySec
    # 같은 SSID에 BSSID가 여럿이면 가장 센 것만 (실제로 붙는 건 그 라디오)
    $r = @(ConvertFrom-NetshWlan (netsh wlan show networks mode=bssid) |
           Group-Object SSID | ForEach-Object { $_.Group | Sort-Object Percent -Descending | Select-Object -First 1 })
    Write-Host " $($r.Count)개"
    $r
}

if ($Filter) { $samples = @($samples | Where-Object { $_.SSID -like "*$Filter*" }) }

if (-not $samples) {
    Write-Host "`n잡히는 AP 없음 (Wi-Fi 꺼짐 또는 SSID 불일치)" -ForegroundColor Yellow
    if ($asked) { Read-Host "`n종료하려면 Enter" | Out-Null }
    exit 1
}

$result = $samples | Group-Object SSID | ForEach-Object {
    $s = $_.Group.Percent | Measure-Object -Average -Minimum -Maximum
    [pscustomobject]@{
        SSID   = $_.Name
        'Avg%' = [math]::Round($s.Average, 1)
        'Min%' = $s.Minimum
        'Max%' = $s.Maximum
        dBm    = [math]::Round($s.Average / 2 - 100, 1)
        N      = $_.Count      # 잡힌 횟수. Count보다 작으면 간헐적으로 놓친 AP = 불안정
    }
} | Sort-Object 'Avg%' -Descending

$result | Format-Table -AutoSize
$b = $result[0]
Write-Host "→ 가장 강함: $($b.SSID)  평균 $($b.'Avg%')% (약 $($b.dBm) dBm, $($b.'Min%')~$($b.'Max%')%, $($b.N)/$Count 회 포착)"

if ($asked) { Read-Host "`n종료하려면 Enter" | Out-Null }
