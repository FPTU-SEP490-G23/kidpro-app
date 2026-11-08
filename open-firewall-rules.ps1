# KidPro - Mo Windows Firewall (Port 8080 & 8000)
# Tu dong xin quyen Administrator neu chua co
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Dang yeu cau quyen Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Clear-Host
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  KIDPRO - MO CONG WINDOWS FIREWALL (PORT 8080 & 8000)  " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Chuyen network profile sang Private
Write-Host "[1/4] Chuyen profile mang sang Private (cho phep LAN ket noi)..." -ForegroundColor Yellow
try {
    Get-NetConnectionProfile | ForEach-Object {
        Set-NetConnectionProfile -InputObject $_ -NetworkCategory Private -ErrorAction SilentlyContinue
    }
    Write-Host "  ==> [OK] Da chuyen profile sang Private!" -ForegroundColor Green
} catch {
    Write-Host "  ==> [Bo qua] Khong the thay doi network profile: $_" -ForegroundColor DarkGray
}

# 2. Xoa cac rule cu
Remove-NetFirewallRule -DisplayName "KidPro Backend SpringBoot (8080)" -ErrorAction SilentlyContinue
Remove-NetFirewallRule -DisplayName "KidPro AI Face Server (8000)" -ErrorAction SilentlyContinue

# 3. Mo Port 8080
Write-Host "[2/4] Dang mo Inbound Port 8080 (Spring Boot Backend)..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "KidPro Backend SpringBoot (8080)" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -Profile Any | Out-Null
Write-Host "  ==> [OK] Da mo thanh cong Port 8080 (TCP Inbound)!" -ForegroundColor Green

# 4. Mo Port 8000
Write-Host "[3/4] Dang mo Inbound Port 8000 (Python AI Server)..." -ForegroundColor Yellow
New-NetFirewallRule -DisplayName "KidPro AI Face Server (8000)" -Direction Inbound -LocalPort 8000 -Protocol TCP -Action Allow -Profile Any | Out-Null
Write-Host "  ==> [OK] Da mo thanh cong Port 8000 (TCP Inbound)!" -ForegroundColor Green

Write-Host ""
Write-Host "[4/4] Thong tin IP LAN Wi-Fi hien tai:" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  ==> IP Wi-Fi: $($_.IPAddress)" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "  HOAN TAT! Cong 8080 va 8000 da duoc mo tren Firewall!  " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Read-Host "Nhan Enter de thoat..."

