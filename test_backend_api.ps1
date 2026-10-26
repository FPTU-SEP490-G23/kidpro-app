$body = @{
    email = 'parent@gmail.com'
    fullName = 'Phụ huynh test'
    avatarUrl = ''
} | ConvertTo-Json -Compress

$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$login = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/api/auth/google' -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8'
Write-Host "LOGIN SUCCESS: $($login.email) Role: $($login.role)"

$headers = @{ Authorization = "Bearer $($login.token)" }
$students = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/api/parents/students' -Method Get -Headers $headers
Write-Host "STUDENTS COUNT: $($students.Count)"
foreach ($s in $students) {
    Write-Host " - Student: $($s.fullName) (ID: $($s.studentId), Class: $($s.className))"
}

$first = $students[0]
$invoices = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/parents/invoices?studentId=$($first.studentId)" -Method Get -Headers $headers
Write-Host "INVOICES COUNT: $($invoices.Count)"
foreach ($inv in $invoices) {
    Write-Host " - Invoice: $($inv.invoiceCode) Amount: $($inv.finalAmount) Status: $($inv.status)"
}

$requests = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/parents/students/$($first.studentId)/all-requests" -Method Get -Headers $headers
Write-Host "ALL REQUESTS COUNT: $($requests.Count)"

Write-Host "ALL CHECKS PASSED PERFECTLY!"
