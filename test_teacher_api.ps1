$body = @{
    email = 'teacher@kidpro.edu.vn'
    fullName = 'Cô Mai Lan'
    avatarUrl = ''
} | ConvertTo-Json -Compress

$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$login = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/api/auth/google' -Method Post -Body $bytes -ContentType 'application/json; charset=utf-8'
Write-Host "TEACHER LOGIN: $($login.email) Role: $($login.role)"

$headers = @{ Authorization = "Bearer $($login.token)" }

# 1. My classes
$classesResp = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/api/teachers/my-classes' -Method Get -Headers $headers
$classes = $classesResp.data
Write-Host "TEACHER CLASSES COUNT: $($classes.Count)"
foreach ($c in $classes) {
    Write-Host " - Class: $($c.className) (ID: $($c.classId), Grade: $($c.gradeLevel), Students: $($c.studentCount))"
}

# 2. Students in first class
$firstClass = $classes[0]
$studentsResp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/teachers/classes/$($firstClass.classId)/students" -Method Get -Headers $headers
$students = $studentsResp.data
Write-Host "CLASS '$($firstClass.className)' REAL STUDENTS COUNT: $($students.Count)"
foreach ($st in $students) {
    Write-Host "   * $($st.fullName) (Code: $($st.studentCode), Status: $($st.status))"
}

# 3. Class Chat
$chatResp = Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/comms/chat/rooms/$($firstClass.classId)/messages" -Method Get -Headers $headers
Write-Host "CLASS CHAT MESSAGES COUNT: $($chatResp.data.Count)"

Write-Host "TEACHER ENDPOINTS VERIFIED SUCCESSFULLY!"
