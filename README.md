# wifi-signal-check

주변 Wi-Fi AP의 신호 세기를 강한 순으로 보여주는 PowerShell 스크립트. `netsh wlan show networks mode=bssid` 출력만 파싱하므로 설치할 게 없다.

```powershell
.\wifi-signal.ps1            # 전체
.\wifi-signal.ps1 cagong     # SSID에 'cagong' 포함된 것만
```

출력 예:

```
SSID        Percent   dBm
----        -------   ---
cagongzok_3      81 -59.5
cagongzok_4      81 -59.5
cagongzok_2      79 -60.5

→ 가장 강함: cagongzok_3  81% (약 -59.5 dBm)
```

- `Percent`는 netsh가 주는 값, `dBm`은 `%/2 - 100` 근사치(Windows가 쓰는 환산식).
- SSID 줄과 `...%`로 끝나는 줄만 정규식으로 잡으므로 한글/영문 로케일 모두 동작한다.
