@echo off
chcp 65001 >nul
title KidPro - Mo cong Firewall (Port 8080 & 8000)

:: Kiem tra quyen Administrator, neu chua co thi tu dong chay voi quyen Admin
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Dang yeu cau quyen Administrator de mo Firewall...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ========================================================
echo   KIDPRO - MO CONG WINDOWS FIREWALL (PORT 8080 va 8000)
echo ========================================================
echo.

echo [1/4] Xoa cac rule cu (neu co)...
netsh advfirewall firewall delete rule name="KidPro Backend SpringBoot (8080)" >nul 2>&1
netsh advfirewall firewall delete rule name="KidPro AI Face Server (8000)" >nul 2>&1

echo [2/4] Dang mo Inbound Port 8080 (Spring Boot Backend)...
netsh advfirewall firewall add rule name="KidPro Backend SpringBoot (8080)" dir=in action=allow protocol=TCP localport=8080 profile=any >nul
if %ERRORLEVEL% equ 0 (
    echo     ==> [OK] Da mo cong 8080 (TCP - Inbound)!
) else (
    echo     ==> [LOI] Khong the them rule port 8080.
)

echo [3/4] Dang mo Inbound Port 8000 (Python AI Server)...
netsh advfirewall firewall add rule name="KidPro AI Face Server (8000)" dir=in action=allow protocol=TCP localport=8000 profile=any >nul
if %ERRORLEVEL% equ 0 (
    echo     ==> [OK] Da mo cong 8000 (TCP - Inbound)!
) else (
    echo     ==> [LOI] Khong the them rule port 8000.
)

echo.
echo [4/4] Thong tin dia chi IP mang LAN hien tai cua may tinh:
echo --------------------------------------------------------
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address" /c:"IPv4" /c:"Dia chi IPv4"') do (
    echo   IP LAN: %%a
)
echo --------------------------------------------------------
echo.
echo [HUONG DAN]:
echo Neu dung Wi-Fi (khong cam cap USB), tren app dien thoai:
echo   1. Base URL backend: http://[IP_LAN_o_tren]:8080 (vi du: http://192.168.10.125:8080)
echo   2. URL AI camera:    http://[IP_LAN_o_tren]:8000 (vi du: http://192.168.10.125:8000)
echo.
echo Hoan tat! Nhan phim bat ky de thoat...
pause >nul
