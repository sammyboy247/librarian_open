#!/usr/bin/env powershell
# Create a task manually for testing

cd D:\dev\librarian_open

$taskId = "gdpr$(Get-Random -Minimum 10000 -Maximum 99999)"
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

$taskJson = @{
    task_id = $taskId
    agent_name = "gdpr_auditor"
    status = "PENDING"
    description = "Audit all documents for GDPR compliance"
    timestamp = $timestamp
} | ConvertTo-Json

$taskFile = Join-Path (Get-Location) ".gemini\agents\tasks\$taskId.json"
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Gray
Write-Host "Task file path: $taskFile" -ForegroundColor Gray

# Ensure directory exists
$taskDir = Split-Path -Parent $taskFile
if (-not (Test-Path $taskDir)) {
    New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
}

Set-Content -Path $taskFile -Value $taskJson

Write-Host "`n✓ Task created: $taskId" -ForegroundColor Green
Write-Host "✓ Task file: $taskFile" -ForegroundColor Green
Write-Host "`nContent:" -ForegroundColor Yellow
Get-Content $taskFile
Write-Host "`nTask Queue:" -ForegroundColor Yellow
Get-ChildItem .gemini\agents\tasks\
