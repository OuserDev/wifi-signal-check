> 출장이나 카페같은 상황에서 최적의 공용와이파이를 선택하기 위해 뚝딱하였습니다.
> 
# wifi-signal-check

주변 Wi-Fi AP의 신호 세기를 **여러 번 측정해 평균으로** 순위를 내는 PowerShell 스크립트. 설치할 게 없다(Windows 내장 `netsh` + `wlanapi.dll`만 사용).

```powershell
.\wifi-signal.ps1                       # 측정 횟수를 물어본다, 전체 AP
.\wifi-signal.ps1 cagong                # 측정 횟수를 물어본다, SSID에 'cagong' 포함만
.\wifi-signal.ps1 cagong 5              # 묻지 않고 바로 5회 (배치/예약 실행용)
.\wifi-signal.ps1 cagong 5 -DelaySec 8  # 스캔 요청 후 대기 8초
.\wifi-signal.ps1 -SelfTest             # 파서 자체 검사
```

횟수를 인자로 주지 않으면 실행 시 직접 물어본다. Enter만 치면 5회:



출력 예:

```
스캔 1/5 ... 11개
스캔 2/5 ... 14개
스캔 3/5 ... 19개
스캔 4/5 ... 21개
스캔 5/5 ... 22개

SSID        Avg% Min% Max%   dBm N
----        ---- ---- ----   --- -
cagongzok_1 89.2   89   90 -55.4 5
cagongzok_4 88.6   87   90 -55.7 5
cagongzok_2 79.6   66   86 -60.2 5
cagongzok_3   75   60   85 -62.5 5

→ 가장 강함: cagongzok_1  평균 89.2% (약 -55.4 dBm, 89~90%, 5/5 회 포착)
```

## 읽는 법

| 열 | 의미 |
|---|---|
| `Avg%` | 평균 신호 세기. 순위 기준 |
| `Min%` / `Max%` | 측정 범위. **차이가 크면 불안정한 AP** |
| `dBm` | `%/2 - 100` 근사치 (Windows 환산식) |
| `N` | 잡힌 횟수. `Count`보다 작으면 간헐적으로 놓친 AP |

세기가 비슷하면 `Min~Max` 편차가 작은 쪽을 고르는 게 낫다. 세기만 같고 채널이 혼잡하면 체감은 다르므로, 필요하면 `netsh wlan show networks mode=bssid`에서 `채널 사용률`과 밴드(2.4/5GHz)도 같이 본다.

## 실행 정책 오류가 나면

```
이 시스템에서 스크립트를 실행할 수 없으므로 ... 파일을 로드할 수 없습니다.
+ CategoryInfo : 보안 오류: (:) [], PSSecurityException
```

Windows 기본 실행 정책이 `Restricted`라 `.ps1` 로드 자체가 막힌 것이다. 정책을 바꾸지 않고 **한 번만 우회**하는 쪽을 권한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\wifi-signal.ps1" cagong 5
```

이미 열려 있는 창에서 그대로 쓰려면 — `-Scope Process`는 그 창을 닫으면 사라지므로 시스템 설정을 건드리지 않는다:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\wifi-signal.ps1 cagong 5
```

매번 치기 귀찮으면 계정 단위로 완화할 수도 있다. 다만 이건 그 계정의 **모든** 스크립트에 적용되니 알고 쓸 것:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

참고로 같은 오류가 `Microsoft.PowerShell_profile.ps1`에 대해서도 뜬다면 그건 프로필 로드 실패지 이 스크립트와는 무관하다.
