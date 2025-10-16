# librarian_open Testing Framework

A comprehensive, Gemini CLI-aware testing framework for validating the multi-agent document manager's audit capabilities.

---

## 1. Overview

The testing framework is designed to validate the librarian_open system's ability to:
- Correctly identify compliance, governance, and privacy issues in documents
- Route tasks to appropriate specialized agents
- Maintain accuracy in detection (minimize false positives)
- Execute tasks asynchronously through the Gemini CLI environment

### Key Design Principles

1. **Gemini CLI Native**: All testing integrates with Gemini CLI's native commands (`/agents:start`, `/agents:run`)
2. **Red Team Approach**: Uses deliberately flawed test documents to validate audit detection
3. **Non-Blocking**: Tests run asynchronously and monitor completion via file system
4. **Repeatable**: Fully automated, can run multiple times with consistent results
5. **Measurable**: Provides quantitative metrics on coverage and accuracy

---

## 2. Architecture

### 2.1 Test Execution Flow

```
Test Runner (PowerShell)
    ↓
Parse Test Documents & Configuration
    ↓
For Each Document:
    ├─ Create Task via .gemini/agents/tasks/
    ├─ Invoke /agents:run (Orchestrator)
    ├─ Poll for Completion
    ├─ Parse Results from .gemini/agents/logs/
    ├─ Validate Against Expected Issues
    └─ Record Metrics
    ↓
Generate Report
```

### 2.2 Key Components

**Task Creation**: Test runner generates task JSON files in `.gemini/agents/tasks/`

**Orchestration**: `/agents:run` command processes tasks and launches agents

**Result Polling**: Monitors `.gemini/agents/logs/` for completion

**Validation**: Compares agent output against expected issues

---

## 3. Test Execution Modes

### 3.1 Quick Mode
```powershell
.\test-runner.ps1 -TestMode quick
```
- Runs only documents with expected issues
- Skips negative test cases
- Typical duration: 2-3 minutes per document

### 3.2 Full Mode (Default)
```powershell
.\test-runner.ps1 -TestMode all
```
- Tests all documents including false positive checks
- Validates negative cases
- Typical duration: 5-10 minutes

### 3.3 Agent-Specific Mode
```powershell
.\test-runner.ps1 -TestMode agent -AgentName "GDPR-Auditor-Agent"
```
- Tests only a specific audit agent
- Useful for agent-level debugging

### 3.4 Document-Specific Mode
```powershell
.\test-runner.ps1 -TestMode document -DocumentName "Employee_Handbook_2024.txt"
```
- Tests a single document

---

## 4. Test Execution Details

### 4.1 Task Creation

Test runner creates JSON task files in `.gemini/agents/tasks/`:

```json
{
  "task_id": "a1b2c3d4",
  "agent_name": "GDPR-Auditor-Agent",
  "status": "PENDING",
  "description": "Audit document: Employee_Handbook_2024.txt for compliance issues",
  "timestamp": "2024-10-16T23:30:00Z"
}
```

### 4.2 Orchestrator Invocation

The test runner invokes: `gemini -c "/agents:run"`

The orchestrator then:
1. Scans `.gemini/agents/tasks/` for PENDING tasks
2. Selects the oldest task
3. Updates status to RUNNING
4. Launches the specified agent
5. Agent writes results to `.gemini/agents/logs/{task_id}_report.txt`

### 4.3 Result Polling

```powershell
Poll interval: 2 seconds
Max timeout: 120 seconds (configurable)
Target file: .gemini/agents/logs/{task_id}_report.txt
```

---

## 5. Result Validation

### 5.1 Issue Extraction

Agent output is parsed for keywords: `issue`, `violation`, `flag`, `error`, `concern`

### 5.2 Coverage Calculation

```
Coverage Rate = (Issues Found / Expected Issues) × 100
```

### 5.3 Pass/Fail Criteria

**For documents with expected issues**:
- ✓ PASS if: Coverage ≥ 80% AND No false positives
- ✗ FAIL if: Coverage < 80% OR False positives detected

**For clean documents**:
- ✓ PASS if: No issues flagged
- ✗ FAIL if: Any issues flagged (false positives)

---

## 6. Running Tests

### 6.1 Basic Execution

```powershell
cd D:\dev\librarian_open

# Run all tests
.\test-runner.ps1

# Run with verbose output
.\test-runner.ps1 -Verbose $true

# Clean logs before running
.\test-runner.ps1 -CleanupLogs $true

# Increase timeout to 180 seconds
.\test-runner.ps1 -TimeoutSeconds 180
```

### 6.2 Specific Test Runs

```powershell
# Test only GDPR agent
.\test-runner.ps1 -TestMode agent -AgentName "GDPR-Auditor-Agent"

# Test only Employee Handbook
.\test-runner.ps1 -TestMode document -DocumentName "Employee_Handbook_2024.txt"

# Quick mode (only issue-containing docs)
.\test-runner.ps1 -TestMode quick
```

---

## 7. Result Files

Results are saved in `test-results/` directory:

```
test-results/
├── test-run-2024-10-16.log          (Session log)
└── test-report-2024-10-16-230500.json (Detailed metrics)
```

**Viewing results**:
```powershell
# View latest report
$latest = Get-ChildItem test-results/*.json | Sort-Object LastWriteTime -Descending | Select -First 1
Get-Content $latest | ConvertFrom-Json | Format-Table
```

---

## 8. Debugging Failed Tests

### 8.1 Task Not Created

**Diagnosis**:
```powershell
# Verify .gemini/agents/tasks/ directory exists
Get-ChildItem .gemini/agents/tasks/

# Check task JSON files
Get-ChildItem .gemini/agents/tasks/*.json
```

### 8.2 Task Timeout

**Diagnosis**:
```powershell
# Check for agent processes
Get-Process | Where-Object {$_.ProcessName -like "*gemini*"}

# View latest logs
Get-ChildItem .gemini/logs/ | Sort-Object LastWriteTime -Descending | Select -First 1 | Get-Content
```

**Solution**: Increase timeout or run orchestrator manually

### 8.3 Low Coverage

**Diagnosis**:
```powershell
# View agent output
Get-Content .gemini/logs/{task_id}_report.txt

# Check agent definition
Get-Content .gemini/agents/extensions/{agent_name}.toml
```

---

## 9. Key Files

| File | Purpose |
|------|---------|
| `test-runner.ps1` | Main test orchestrator |
| `TESTING_FRAMEWORK.md` | This documentation |
| `TEST_QUICK_START.md` | Quick reference guide |
| `testDocIndex.md` | Test document definitions |
| `AUDIT_TEST_PLAN.md` | Test strategy overview |
| `.gemini/agents/extensions/` | Agent definitions |
| `DOCUMENT_ROOT/` | Test documents |
| `test-results/` | Test output |

---

## 10. Success Criteria

The testing framework is successful when:

- ✅ 95%+ of deliberately introduced issues are detected
- ✅ False positive rate remains below 5%
- ✅ All test modes execute without hangs or crashes
- ✅ Results are reproducible across multiple runs
- ✅ New documents can be added easily

