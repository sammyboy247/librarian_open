# Testing Quick Start Guide

## Installation & Setup

```powershell
# Navigate to project
cd D:\dev\librarian_open

# Ensure Gemini CLI is available
gemini --version
```

## Common Test Commands

### Run All Tests
```powershell
.\test-runner.ps1
```
Takes 5-10 minutes, tests all documents and agents.

### Quick Test (Fast Validation)
```powershell
.\test-runner.ps1 -TestMode quick
```
Takes 2-3 minutes, skips negative test cases.

### Test Specific Agent
```powershell
.\test-runner.ps1 -TestMode agent -AgentName "GDPR-Auditor-Agent"
```

### Test Specific Document
```powershell
.\test-runner.ps1 -TestMode document -DocumentName "Employee_Handbook_2024.txt"
```

### Verbose Output
```powershell
.\test-runner.ps1 -Verbose $true
```

### Increase Timeout
```powershell
.\test-runner.ps1 -TimeoutSeconds 180
```

## Understanding Results

### Success Indicators
- ✓ **PASS** displayed after each test
- Coverage rate ≥ 80%
- No false positives on clean documents
- All tasks complete within timeout

### Result Files
```
test-results/
├── test-run-{date}.log              # Session log
└── test-report-{date-time}.json     # Detailed metrics
```

View latest report:
```powershell
$latest = Get-ChildItem test-results/*.json | Sort-Object LastWriteTime -Descending | Select -First 1
Get-Content $latest | ConvertFrom-Json | Format-Table
```

## Debugging

### Check Last Test Log
```powershell
Get-Content "test-results/test-run-$(Get-Date -Format 'yyyy-MM-dd').log"
```

### Check Agent Output Directly
```powershell
Get-ChildItem .gemini/logs/ | Sort-Object LastWriteTime -Descending | Select -First 1 | Get-Content
```

### Verify Task Queue
```powershell
Get-ChildItem .gemini/agents/tasks/
```

### Manual Orchestrator Run
```powershell
gemini -c "/agents:run"
```

## Troubleshooting

### "gemini: command not found"
```powershell
# Test if Gemini CLI is available
Get-Command gemini

# If not found, add to PATH
```

### Tests Timing Out
```powershell
# Increase timeout to 3 minutes
.\test-runner.ps1 -TimeoutSeconds 180

# Or check if orchestrator needs to run manually
gemini -c "/agents:run"
```

### Low Coverage
```powershell
# Run with specific agent to debug
.\test-runner.ps1 -TestMode agent -AgentName "GDPR-Auditor-Agent" -Verbose $true
```

## Typical Workflow

1. **Run quick test**
   ```powershell
   .\test-runner.ps1 -TestMode quick
   ```

2. **Check results**
   ```powershell
   Get-Content "test-results/test-run-$(Get-Date -Format 'yyyy-MM-dd').log" | tail -20
   ```

3. **If failures, debug specific agent**
   ```powershell
   .\test-runner.ps1 -TestMode agent -AgentName "GDPR-Auditor-Agent"
   ```

4. **Run full suite when satisfied**
   ```powershell
   .\test-runner.ps1 -TestMode all
   ```

---

For detailed documentation, see `TESTING_FRAMEWORK.md`
