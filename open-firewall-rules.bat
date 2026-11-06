@echo off
chcp 65001 >nul
title KidPro - Mo Windows Firewall (Port 8080 va 8000)

:: 1. Tu dong xin quyen Administrator neu chua co va GIU NGUYEN CUA SO KHONG DUOC DONG
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [THONG BAO] Dang yeu cau quyen Administrator...
    echo Vui long bam YES (Co) trong hop thoai Windows UAC vua xuat hien!
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/k cd /d \"\"%~dp0\"\" && \"\"%~nx0\"\" elevated' -Verb RunAs"
    exit /b
)

cls
echo ========================================================
echo   KIDPRO - MO CONG WINDOWS FIREWALL (PORT 8080 va 8000)
echo ========================================================
echo.
echo [1/5] Chuyen mang Wi-Fi sang Private (Cho phep ket noi noi bo LAN)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-NetConnectionProfile | ForEach-Object { Set-NetConnectionProfile -InputObject $_ -NetworkCategory Private -ErrorAction SilentlyContinue }; Write-Host '  ==> [OK] Da chuyen profile mang sang Private!' -ForegroundColor Green"

echo.
echo [2/5] Xoa cac Rule cu (neu co)...
netsh advfirewall firewall delete rule name="KidPro Backend SpringBoot (8080)" >nul 2>&1
netsh advfirewall firewall delete rule name="KidPro AI Face Server (8000)" >nul 2>&1

echo.
echo [3/5] Dang mo Inbound Port 8080 (Spring Boot Backend)...
netsh advfirewall firewall add rule name="KidPro Backend SpringBoot (8080)" dir=in action=allow protocol=TCP localport=8080 profile=any >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "New-NetFirewallRule -DisplayName 'KidPro Backend SpringBoot (8080)' -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null; Write-Host '  ==> [OK] Da mo cong 8080 (TCP Inbound)!' -ForegroundColor Green"

echo.
echo [4/5] Dang mo Inbound Port 8000 (Python AI Server)...
netsh advfirewall firewall add rule name="KidPro AI Face Server (8000)" dir=in action=allow protocol=TCP localport=8000 profile=any >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "New-NetFirewallRule -DisplayName 'KidPro AI Face Server (8000)' -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null; Write-Host '  ==> [OK] Da mo cong 8000 (TCP Inbound)!' -ForegroundColor Green"

echo.
echo [5/5] Cho phep Ping (ICMPv4) giua dien thoai va laptop...
netsh advfirewall firewall add rule name="KidPro Allow ICMP Ping" protocol=icmpv4:any,any dir=in action=allow >nul 2>&1

echo.
echo ========================================================
echo   THONG TIN DIA CHI IP HIEN TAI CUA MAY TINH:
echo ========================================================
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address" /c:"IPv4" /c:"Dia chi IPv4"') do (
    echo   ==^> IP LAN: %%a
)
echo ========================================================
echo.
echo [HUONG DAN]:
echo   1. Base URL backend : http://[IP_LAN_o_tren]:8080 (vi du: http://192.168.10.51:8080)
echo   2. URL AI camera    : http://[IP_LAN_o_tren]:8000 (vi du: http://192.168.10.51:8000)
echo.
echo [HOAN TAT TAT CA CAC BUOC CAU HINH FIREWALL!]
echo Cua so nay se khong tu tat. Ban co the dong cua so nay lai.
echo.
pause
