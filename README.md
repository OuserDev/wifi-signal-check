> **[여기에 넣을 문구 — 수정하세요]**
> 예시: 카페에서 어느 AP에 붙어야 할지 매번 감으로 고르다 만들었다. Wi-Fi 목록의 안테나 4칸은
> 세기를 3~4단계로 뭉개버리는데, 실제로는 같은 4칸 안에서도 20% 넘게 차이가 난다.
> 그걸 숫자로 보고 싶어서 쓴 스크립트.

# wifi-signal-check

주변 Wi-Fi AP의 신호 세기를 **여러 번 측정해 평균으로** 순위를 내는 PowerShell 스크립트. 설치할 게 없다(Windows 내장 `netsh` + `wlanapi.dll`만 사용).

```powershell
.\wifi-signal.ps1                       # 전체, 1회
.\wifi-signal.ps1 cagong                # SSID에 'cagong' 포함, 1회
.\wifi-signal.ps1 cagong 5              # 5회 측정 후 평균  ← 권장
.\wifi-signal.ps1 cagong 5 -DelaySec 8  # 스캔 요청 후 대기 8초
.\wifi-signal.ps1 -SelfTest             # 파서 자체 검사
```

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

## 왜 1회 측정은 못 믿나

`netsh wlan show networks`는 **스캔을 새로 돌리지 않는다.** 드라이버가 캐시해 둔 지난 스캔 결과를 그대로 돌려줄 뿐이다. 그래서

- 연속으로 호출하면 값이 소수점 하나 안 틀리고 똑같이 반복된다 (측정이 아니라 복사).
- 캐시가 비어 있으면 주변에 20개가 있어도 **1~2개만** 잡힌다.

이 스크립트는 회차마다 `wlanapi.dll`의 `WlanScan()`을 호출해 실제 스캔을 요청하고(Windows Wi-Fi 목록 UI가 쓰는 그 API, **관리자 권한 불필요**) `-DelaySec` 만큼 결과가 올라오길 기다린다. 위 출력에서 회차가 갈수록 잡히는 AP 수가 11 → 22로 늘어나는 게 그 효과다.

실제로 위 예시의 `cagongzok_3`은 1회 측정에서 81%로 공동 1위였지만, 5회 평균은 75%에 편차 60~85%로 가장 불안정한 AP였다. 반대로 `cagongzok_1`은 캐시에 아예 없어서 1회 측정에서는 보이지도 않았다.

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
