# Manual Inquiry Guide - Gemini CLI

## Command Line Syntax

Based on the actual Gemini CLI format, here's the correct syntax for manual inquiries:

### 1. Queue a Task (Start an Inquiry)

```bash
gemini agents:start "<AGENT_NAME>" "<TASK_DESCRIPTION>"
```

**Examples:**

```bash
# Queue GDPR audit
gemini agents:start "gdpr_auditor" "Audit Employee_Handbook_2024.txt for GDPR compliance"

# Queue HR audit
gemini agents:start "hr_auditor" "Check Contractor_Agreement_US.txt for labor law violations"

# Queue Legal audit
gemini agents:start "legal_auditor" "Review Data_Processing_Agreement_EU.txt for legal issues"

# Queue Governance audit
gemini agents:start "governance_auditor" "Audit Onboarding_Policy_2019.txt for governance compliance"

# Queue Medical audit
gemini agents:start "medical_auditor" "Check Patient_Data_Handling_Protocol.txt for medical data privacy"

# Queue Conflict Finder
gemini agents:start "conflict_finder" "Find conflicts between Employee_Handbook_2024.txt and Data_Processing_Agreement_EU.txt"

# Queue Template Suite
gemini agents:start "template_suite" "Generate new templates for updated policies"
```

**Valid Agent Names (from extension files):**
- `gdpr_auditor`
- `legal_auditor`
- `hr_auditor`
- `medical_auditor`
- `governance_auditor`
- `conflict_finder`
- `template_suite`
- `alert`
- `calendar`

### 2. Run the Orchestrator (Process Tasks)

```bash
gemini agents:run
```

This command:
1. Scans `.gemini/agents/tasks/` for PENDING tasks
2. Selects the oldest task
3. Launches the appropriate agent
4. Results appear in `.gemini/agents/logs/{task_id}_report.txt`

---

## Workflow Example

### Step 1: Queue Task
```bash
cd D:\dev\librarian_open
gemini agents:start "gdpr_auditor" "Audit Employee_Handbook_2024.txt for GDPR compliance issues"
```

**Output**: Task is queued, task ID is generated

### Step 2: Check Task Queue
```bash
Get-ChildItem .gemini\agents\tasks\
```

You should see the task JSON file created.

### Step 3: Run Orchestrator
```bash
gemini agents:run
```

This launches the agent with the PENDING task.

### Step 4: Monitor Progress
```bash
# Watch for result file
Get-ChildItem .gemini\agents\logs\ | Sort-Object LastWriteTime -Descending | Select -First 1 | Get-Content

# Or continuously monitor
while ($true) {
    Clear-Host
    Write-Host "=== Task Results ===" -ForegroundColor Cyan
    Get-ChildItem .gemini\agents\logs\ | Sort-Object LastWriteTime -Descending | Select -First 1 | Get-Content
    Start-Sleep -Seconds 2
}
```

### Step 5: View Results
```bash
# View the latest report
$latest = Get-ChildItem .gemini\agents\logs\*.txt | Sort-Object LastWriteTime -Descending | Select -First 1
Get-Content $latest
```

---

## Complete Manual Test Workflow

```powershell
# 1. Navigate to project
cd D:\dev\librarian_open

# 2. Queue a task
Write-Host "Queuing GDPR audit task..." -ForegroundColor Cyan
gemini agents:start "gdpr_auditor" "Audit Employee_Handbook_2024.txt for GDPR compliance"

# 3. Wait a moment
Start-Sleep -Seconds 2

# 4. View task in queue
Write-Host "`nTasks in queue:" -ForegroundColor Cyan
Get-ChildItem .gemini\agents\tasks\

# 5. Run orchestrator
Write-Host "`nRunning orchestrator..." -ForegroundColor Cyan
gemini agents:run

# 6. Wait for completion
Write-Host "`nWaiting for results..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

# 7. View results
Write-Host "`nResults:" -ForegroundColor Cyan
$latest = Get-ChildItem .gemini\agents\logs\*.txt | Sort-Object LastWriteTime -Descending | Select -First 1
Get-Content $latest
```

---

## Batch Testing Multiple Documents

```powershell
$agents = @("gdpr_auditor", "legal_auditor", "hr_auditor")
$documents = @(
    "Employee_Handbook_2024.txt",
    "Data_Processing_Agreement_EU.txt",
    "Contractor_Agreement_US.txt"
)

foreach ($doc in $documents) {
    foreach ($agent in $agents) {
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Queuing: $agent → $doc" -ForegroundColor Green
        gemini agents:start "$agent" "Audit $doc for compliance"
        Start-Sleep -Seconds 1
    }
}

Write-Host "`nAll tasks queued. Running orchestrator..." -ForegroundColor Cyan
gemini agents:run

# Wait and collect results
Write-Host "`nWaiting for all results..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

Write-Host "`nResults:" -ForegroundColor Cyan
Get-ChildItem .gemini\agents\logs\*.txt | Sort-Object LastWriteTime -Descending | Get-Content
```

---

## Troubleshooting Manual Inquiries

### Issue: "Unknown command agents:start"
**Solution**: Ensure you're in the project root (`D:\dev\librarian_open`) where `.gemini/` is located

### Issue: "No matching agent found"
**Solution**: Verify agent name corresponds to an extension file in `.gemini/agents/extensions/` 
- Extension file: `gdpr_auditor.toml` → Agent name: `gdpr_auditor`
- Extension file: `legal_auditor.toml` → Agent name: `legal_auditor`

### Issue: Task created but not processed
**Solution**: Run orchestrator manually with `gemini agents:run`

### Issue: Results not appearing
**Solution**: 
```bash
# Check logs directory
Get-ChildItem .gemini\agents\logs\

# If empty, check task status
Get-ChildItem .gemini\agents\tasks\ | ForEach-Object { Get-Content $_ }
```

### Issue: "gemini: command not found"
**Solution**: Ensure Gemini CLI is in PATH or use full path

---

## Quick Commands Reference

```bash
# Queue a GDPR audit
gemini agents:start "gdpr_auditor" "Check all documents for GDPR compliance"

# Run orchestrator to process tasks
gemini agents:run

# View recent logs
Get-ChildItem .gemini\agents\logs\ | Sort-Object LastWriteTime -Descending | Select -First 1 | Get-Content

# Check pending tasks
Get-ChildItem .gemini\agents\tasks\ | ForEach-Object { 
    Write-Host "Task: $($_.BaseName)"
    Get-Content $_ | ConvertFrom-Json | Select-Object task_id, agent_name, status
}

# Clear all tasks (reset test state)
Remove-Item .gemini\agents\tasks\*.json
Remove-Item .gemini\agents\logs\*.txt

# View all agent extensions available
Get-ChildItem .gemini\agents\extensions\*.toml | ForEach-Object { 
    Write-Host $_.BaseName 
}
```

