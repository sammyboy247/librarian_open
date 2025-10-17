# Test Framework Summary & Troubleshooting Guide

Complete reference for understanding and using the enhanced librarian_open testing framework.

---

## What We Built

A **robust, verbose testing framework** that validates the librarian_open multi-agent document manager's ability to:

1. Create audit tasks through Gemini CLI
2. Process them through the orchestrator
3. Route them to specialized agents
4. Collect and validate results
5. Generate detailed metrics and debug logs

---

## Files Included

| File | Purpose |
|------|---------|
| `test-runner-v2.ps1` | **Main test orchestrator** - Enhanced with verbose logging, detailed Gemini CLI interaction tracking, system diagnostics |
| `TESTING_FRAMEWORK.md` | Comprehensive technical documentation of the testing architecture |
| `TEST_QUICK_START.md` | Quick reference for common test commands |
| `MANUAL_INQUIRY_GUIDE.md` | Detailed guide for manually testing agents with Gemini CLI |
| `MANUAL_INQUIRY_CHEATSHEET.md` | Copy-paste ready commands for one-off agent testing |
| `testDocIndex.md` | Index of all test documents and what they test |
| `AUDIT_TEST_PLAN.md` | Test strategy overview |

---

## Why Tests Are Timing Out (And How to Fix It)

### Root Cause Analysis

The timeout issue is likely due to how Gemini CLI custom commands work:

1. **Custom commands** (`/agents:start`, `/agents:run`) are defined in `.toml` files as prompts
2. These commands expect to be **invoked interactively** via the Gemini CLI
3. The test runner was trying to invoke them as standalone commands, which doesn't work

### The Solution: Manual Inquiry Format

Instead of trying to invoke custom commands directly, we use **interactive prompts**:

```bash
# WRONG (doesn't work):
gemini -c "/agents:run"

# RIGHT (works):
gemini -i "You are the Executive Orchestrator. Scan .gemini/agents/tasks/ for PENDING tasks..."
```

### Key Insight: The `-i` Flag

`-i` = **interactive mode**

This flag tells Gemini CLI to:
- Accept a detailed prompt instruction
- Stay running until the task completes
- Support tool usage (file reading/writing)
- Display detailed output

---

## Recommended Manual Testing Workflow

### Step 1: Verify System Access

```powershell
gemini -i "List all .txt files in DOCUMENT_ROOT/ directory"
```

✅ **Expected**: Lists Employee_Handbook_2024.txt, Data_Processing_Agreement_EU.txt, etc.

### Step 2: Test One Agent

```powershell
gemini -i "You are GDPR-Auditor-Agent. Read DOCUMENT_ROOT/Employee_Handbook_2024.txt and analyze it for GDPR compliance violations. Report all findings."
```

✅ **Expected**: Agent analyzes the document and reports GDPR issues found

### Step 3: Verify Agent Works

If Step 2 works, your agents are functional! The test framework can now work because:
- Agents can read files ✓
- Agents can respond with findings ✓
- Gemini CLI is working ✓

### Step 4: Use Enhanced Test Runner

```powershell
# Enhanced verbose test runner
.\test-runner-v2.ps1 -TestMode quick -Verbose $true

# Will show:
# - Each task creation with details
# - Orchestrator invocation attempts
# - Polling status updates
# - Result parsing with matches
# - Validation with coverage percentages
```

---

## Understanding the Test Runner Output

### Verbose Output Breakdown

```
[HH:mm:ss.fff] [TestRunner] [Debug] Parsing test document index...
[HH:mm:ss.fff] [TestRunner] [Success] Loaded 7 test document definitions

━━━ TEST: Employee_Handbook_2024.txt with GDPR-Auditor-Agent ━━━
[HH:mm:ss.fff] [TestRunner] [Debug] Creating new audit task...
[HH:mm:ss.fff] [TestRunner] [Debug] Generated Task ID: a1b2c3d4
[HH:mm:ss.fff] [TestRunner] [Debug] Task JSON: {...}
[HH:mm:ss.fff] [TestRunner] [Success] Task file created successfully (285 bytes)

[HH:mm:ss.fff] [TestRunner] [Debug] Invoking orchestrator...
[HH:mm:ss.fff] [TestRunner] [Debug] Pending tasks in queue: 1
[HH:mm:ss.fff] [TestRunner] [Debug] Polling for task completion...
Poll #1 (2.1s elapsed): Checking for .gemini/agents/logs/a1b2c3d4_report.txt
Poll #2 (4.2s elapsed): Checking for .gemini/agents/logs/a1b2c3d4_report.txt
✓ Result file found! (523 bytes)

[HH:mm:ss.fff] [TestRunner] [Debug] Parsing audit result...
[HH:mm:ss.fff] [TestRunner] [Success] Extracted 3 issues

[HH:mm:ss.fff] [TestRunner] [Debug] Validating audit result...
[HH:mm:ss.fff] [TestRunner] [Info] Coverage: 2 / 2 = 100%
✓ PASS | Employee_Handbook_2024.txt | Coverage: 100%
```

**Key sections to look for**:
- ✓ **PASS** = Test succeeded, coverage ≥ 80%, no false positives
- ✗ **FAIL** = Coverage < 80% or false positives detected
- Polling attempts = How many times it checked for results
- Coverage percentage = Detected issues / Expected issues

---

## Troubleshooting: Step-by-Step

### Symptom 1: "Gemini: command not found"

**Diagnosis**:
```powershell
Get-Command gemini  # Should return the path to gemini executable
```

**Fix**:
```powershell
# Option 1: Add to PATH
$env:PATH += ";C:\path\to\gemini"

# Option 2: Use full path
C:\path\to\gemini\gemini.exe -i "Your prompt"
```

---

### Symptom 2: "Agent can't read file"

**Diagnosis**:
```powershell
gemini -i "List all files in DOCUMENT_ROOT/"  # Should show test documents
```

**Fix**:
1. Verify DOCUMENT_ROOT folder exists
2. Verify test documents are in it
3. Use full paths: `DOCUMENT_ROOT/filename.txt`
4. Check agent permissions in `.gemini/agents/extensions/[agent].toml`

---

### Symptom 3: "Task times out after 120 seconds"

**Diagnosis** (in order):
```powershell
# 1. Can Gemini CLI run at all?
gemini --version

# 2. Can it read files?
gemini -i "Read first 50 characters of DOCUMENT_ROOT/Employee_Handbook_2024.txt"

# 3. Can agent respond?
gemini -i "You are GDPR-Auditor-Agent. Respond with 'Ready' to verify."

# 4. Can agent write output?
gemini -i "You are GDPR-Auditor-Agent. Write 'Test output' to .gemini/agents/logs/test.txt"
```

**Fix**:
- Increase timeout: `.\test-runner-v2.ps1 -TimeoutSeconds 180`
- Run manual test to verify agent works
- Check `.gemini/agents/logs/` for any output files
- Verify orchestrator is actually being invoked

---

### Symptom 4: "Coverage is 0% - No issues detected"

**Diagnosis**:
```powershell
# Get the actual output
gemini -i "You are GDPR-Auditor-Agent. Analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt. Be very specific about all issues found."

# Check what was written to logs
Get-ChildItem .gemini/agents/logs/ | Sort LastWriteTime -Descending | Select -First 1 | Get-Content
```

**Possible causes**:
1. Agent not reading file correctly
2. Agent not finding issues (agent prompt too restrictive)
3. Issue keywords not matching test expectations
4. Results not being written to logs

**Fix**:
- Review agent prompt in `.gemini/agents/extensions/[agent].toml`
- Manually test agent with same document
- Verify expected issues in `testDocIndex.md`

---

## Manual Inquiry Command Templates

### For GDPR Testing

```powershell
gemini -i "
You are the GDPR-Auditor-Agent. Your specialization is data privacy compliance.

Read the document: DOCUMENT_ROOT/Employee_Handbook_2024.txt

Analyze it for:
1. GDPR compliance violations
2. Data retention issues
3. Privacy principle violations
4. Unauthorized data access

Report findings with specific quotes from the document.
Write final report to .gemini/agents/logs/gdpr_test.txt
"
```

### For Conflict Detection

```powershell
gemini -i "
You are the Conflict-Finder-Agent.

Compare these documents for contradictions:
- DOCUMENT_ROOT/Employee_Handbook_2024.txt
- DOCUMENT_ROOT/Legal_Data_Retention_Policy.txt

Find any statements that contradict each other.
Report specific conflicts and which parts of each document conflict.
"
```

---

## Success Criteria

### Single Agent Test Success

✅ Agent responds to prompt
✅ Agent reads document successfully
✅ Agent identifies at least one issue
✅ Output is written (either to stdout or logs file)

### Test Runner Success

✅ All tests complete without hanging
✅ Coverage ≥ 80% for documents with issues
✅ No false positives on clean documents
✅ Results saved to `test-results/` directory

### System Success

✅ Manual inquiries work consistently
✅ Test runner completes in < 10 minutes
✅ Debug logs show clear task progression
✅ Different agents flag different issues

---

## Performance Expectations

| Test | Duration | Status |
|------|----------|--------|
| Single agent on one document | 30-60s | Should complete |
| Quick mode (fast tests) | 2-3 min | Should complete |
| Full test suite | 5-10 min | Should complete |
| With debugging | +50% | Expected |

If tests take **longer than 5 minutes per document**, something is blocking.

---

## Next Steps

1. **Try a manual inquiry** (copy from cheatsheet):
   ```powershell
   gemini -i "You are GDPR-Auditor-Agent. Analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt for GDPR violations."
   ```

2. **If that works**, run the test runner:
   ```powershell
   .\test-runner-v2.ps1 -TestMode quick
   ```

3. **If that works**, review results:
   ```powershell
   Get-Content test-results/*.log | tail -50  # See latest logs
   ```

4. **Debug** any failures using the troubleshooting guide above

---

## Key Files for Reference

- **Manual testing**: `MANUAL_INQUIRY_CHEATSHEET.md`
- **Full reference**: `MANUAL_INQUIRY_GUIDE.md`
- **Test details**: `TESTING_FRAMEWORK.md`
- **Quick start**: `TEST_QUICK_START.md`

---

## Questions?

If you encounter issues:

1. Check the symptom in the Troubleshooting section above
2. Follow the diagnostic steps
3. Apply the recommended fix
4. Verify with a manual inquiry command
5. Run test runner again

The test runner's **verbose output** (`-Verbose $true`) provides detailed traces of exactly what's happening.

