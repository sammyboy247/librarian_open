# Manual Gemini CLI Inquiry Guide

A reference for manually invoking audit agents and debugging the librarian_open system.

---

## Core Concepts

The librarian_open system works by:
1. Creating task JSON files in `.gemini/agents/tasks/`
2. Invoking Gemini CLI with agent prompts
3. Agents read documents and write results to `.gemini/agents/logs/`

---

## Recommended Manual Inquiry Commands

### Basic Format

```bash
gemini -i "You are the [AGENT-NAME]. Task: [DESCRIPTION]. Use the read_file tool to examine DOCUMENT_ROOT/[filename]. Report your findings."
```

### Quick Diagnostic

```bash
gemini -i "List all files in DOCUMENT_ROOT/ directory."
```

**Expected Output**: Lists all test documents in the DOCUMENT_ROOT folder.

---

## Agent-Specific Manual Inquiries

### 1. GDPR Auditor

```bash
gemini -i "You are the GDPR-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt for GDPR compliance violations. Report any findings."
```

**What it tests**: GDPR issues, data retention problems, privacy violations

**Look for in output**:
- References to "indefinite storage"
- "GDPR" or "privacy" concerns
- "data retention" issues

---

### 2. Legal Auditor

```bash
gemini -i "You are the Legal-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Data_Processing_Agreement_EU.txt for legal and labor law violations. Report findings."
```

**What it tests**: Legal compliance, labor law, contractual issues

**Look for in output**:
- "labor" or "employment" concerns
- "legal" violations
- "contract" or "liability" issues

---

### 3. HR Auditor

```bash
gemini -i "You are the HR-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Contractor_Agreement_US.txt for HR policy violations and labor law issues. Report findings."
```

**What it tests**: HR policies, employee rights, compensation issues

**Look for in output**:
- "overtime" or "compensation" concerns
- "employee" classification issues
- Policy inconsistencies

---

### 4. Governance Auditor

```bash
gemini -i "You are the Governance-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Onboarding_Policy_2019.txt for governance issues, obsolete content, or overdue reviews. Report findings."
```

**What it tests**: Review dates, policy age, governance compliance

**Look for in output**:
- "2019" or old dates
- "obsolete" or "outdated" references
- "review" date concerns

---

### 5. Medical Auditor

```bash
gemini -i "You are the Medical-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Patient_Data_Handling_Protocol.txt for medical data security and HIPAA concerns. Report findings."
```

**What it tests**: Medical data handling, HIPAA compliance, security protocols

**Look for in output**:
- "medical" or "patient" concerns
- "HIPAA" or "security" issues
- "data handling" problems

---

### 6. Conflict Finder

```bash
gemini -i "You are the Conflict-Finder-Agent. Compare DOCUMENT_ROOT/Employee_Handbook_2024.txt with DOCUMENT_ROOT/Legal_Data_Retention_Policy.txt and identify contradictions or conflicts. Report all inconsistencies."
```

**What it tests**: Cross-document consistency, policy conflicts

**Look for in output**:
- "contradiction"
- "conflict"
- "inconsistent"
- References to both documents

---

## Orchestrator Manual Execution

The orchestrator processes the task queue. To manually run it:

```bash
gemini -i "You are the Executive Orchestrator. 
1. Use list_directory to scan .gemini/agents/tasks/ 
2. Find files with status PENDING
3. Read the oldest one
4. Report what task you found"
```

---

## Testing a Full Task Flow Manually

### Step 1: Create Task File

Create a file `.gemini/agents/tasks/test123.json`:

```json
{
  "task_id": "test123",
  "agent_name": "GDPR-Auditor-Agent",
  "status": "PENDING",
  "description": "Audit Employee_Handbook_2024.txt for GDPR compliance",
  "timestamp": "2024-10-16T23:30:00Z"
}
```

### Step 2: Invoke Agent

```bash
gemini -i "You are the GDPR-Auditor-Agent. Your task is to audit DOCUMENT_ROOT/Employee_Handbook_2024.txt for GDPR compliance. Write your findings to .gemini/agents/logs/test123_report.txt. Be thorough and list all violations found."
```

### Step 3: Check Results

```bash
gemini -i "Read and display the contents of .gemini/agents/logs/test123_report.txt"
```

---

## Debugging Commands

### Check Task Queue

```bash
gemini -i "List all JSON files in .gemini/agents/tasks/ directory and show their status field."
```

### Check Logs

```bash
gemini -i "List all files in .gemini/agents/logs/ directory and show their file sizes."
```

### View Specific Log

```bash
gemini -i "Read and display the contents of .gemini/agents/logs/[TASK_ID]_report.txt"
```

### Verify Document Access

```bash
gemini -i "Read the first 500 characters of DOCUMENT_ROOT/Employee_Handbook_2024.txt"
```

---

## Advanced Manual Testing

### Test All Agents Against One Document

```bash
for agent in GDPR-Auditor-Agent Legal-Auditor-Agent HR-Auditor-Agent Governance-Auditor-Agent Medical-Auditor-Agent; do
  echo "Testing $agent..."
  gemini -i "You are the $agent. Read and analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt. List all issues you find."
done
```

### Compare Agent Outputs

```bash
# Run same document through two agents and compare
gemini -i "You are the GDPR-Auditor-Agent. Analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt and list issues."

gemini -i "You are the Legal-Auditor-Agent. Analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt and list issues."

# Compare the outputs for overlap or differences
```

---

## Key Gemini CLI Options

| Option | Purpose | Example |
|--------|---------|---------|
| `-i` | Interactive mode with prompt | `gemini -i "Your prompt here"` |
| `-p` | Non-interactive prompt | `gemini -p "Your prompt"` |
| `-d` | Debug mode | `gemini -d -i "Your prompt"` |
| `-e` | Use specific extensions | `gemini -e gdpr_auditor -i "Your prompt"` |
| `-o json` | JSON output format | `gemini -o json -i "Your prompt"` |

---

## Troubleshooting Manual Inquiries

### Issue: "Command not found: gemini"

**Solution**: Add Gemini CLI to PATH
```bash
$env:PATH += ";C:\path\to\gemini\bin"
```

### Issue: Agent can't read file

**Solution**: Use absolute paths or ensure working directory is correct
```bash
# Wrong (relative path may fail)
gemini -i "Read Employee_Handbook_2024.txt"

# Right (explicit path)
gemini -i "Read DOCUMENT_ROOT/Employee_Handbook_2024.txt"
```

### Issue: Tool access denied

**Solution**: Check agent extension permissions in `.gemini/agents/extensions/[agent].toml`

```toml
[tools]
include = ["read_file", "read_many_files"]  # What tools can this agent use?
```

### Issue: Results not appearing in logs

**Solution**: Verify the write_file instruction in your prompt
```bash
gemini -i "Write your findings to .gemini/agents/logs/myresult.txt using the write_file tool"
```

---

## Testing Workflow

1. **Verify system**: `gemini -i "List files in DOCUMENT_ROOT/"`
2. **Test one agent**: `gemini -i "You are GDPR-Auditor-Agent. Read DOCUMENT_ROOT/Employee_Handbook_2024.txt and report findings."`
3. **Check output**: `gemini -i "Read .gemini/agents/logs/latest_file.txt"`
4. **Compare agents**: Run same document through multiple agents
5. **Use test runner**: `.\test-runner-v2.ps1 -Verbose $true` when manual testing is complete

---

## Success Indicators

✅ Agent responds with document analysis
✅ Issues/findings are listed
✅ Results appear in appropriate logs directory
✅ No "permission denied" errors
✅ Output references specific document sections
✅ Different agents flag different issues

---

## Next Steps

1. **Try a manual inquiry**: Start with the Quick Diagnostic command
2. **Test an agent**: Pick one agent and run its manual inquiry
3. **Use the test runner**: `.\test-runner-v2.ps1 -TestMode quick`
4. **Review output**: Check `test-results/` for detailed logs

