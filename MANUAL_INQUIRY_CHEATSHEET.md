# Quick Manual Inquiry Cheat Sheet

Copy and paste these commands directly into PowerShell to manually test agents.

---

## One-Liners for Quick Testing

### Test GDPR Agent
```powershell
gemini -i "You are GDPR-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt for GDPR compliance violations. Report all findings with line numbers or section references."
```

### Test Legal Agent  
```powershell
gemini -i "You are Legal-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Data_Processing_Agreement_EU.txt for legal violations, labor law issues, and contractual problems. Be specific about violations."
```

### Test HR Agent
```powershell
gemini -i "You are HR-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Contractor_Agreement_US.txt for labor law violations, compensation issues, and employment classification problems."
```

### Test Governance Agent
```powershell
gemini -i "You are Governance-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Onboarding_Policy_2019.txt for outdated content, review date violations, and governance issues."
```

### Test Medical Agent
```powershell
gemini -i "You are Medical-Auditor-Agent. Read and analyze DOCUMENT_ROOT/Patient_Data_Handling_Protocol.txt for HIPAA violations and medical data security concerns."
```

### Verify Clean Document (Should Find Nothing)
```powershell
gemini -i "You are any-auditor. Read DOCUMENT_ROOT/Legal_Data_Retention_Policy.txt and report any compliance issues. If none found, explicitly state 'No issues found'."
```

---

## Orchestrator Manual Run

### Check Task Queue Status
```powershell
gemini -i "Analyze the .gemini/agents/tasks/ directory. List all JSON files and report their status field. How many are PENDING, RUNNING, or COMPLETED?"
```

### Process Queue Manually
```powershell
gemini -i "You are Executive Orchestrator. 
1. Use list_directory on .gemini/agents/tasks/
2. Find all PENDING tasks
3. For the oldest one, read it and report: task_id, agent_name, and description
4. Suggest how it should be launched"
```

---

## Debugging Commands

### List All Test Documents
```powershell
gemini -i "List all .txt files in DOCUMENT_ROOT/ directory with their file sizes."
```

### Check Log Directory
```powershell
gemini -i "List all .txt files in .gemini/agents/logs/ directory and report their sizes and modification times."
```

### View Latest Log
```powershell
gemini -i "Find the most recently modified file in .gemini/agents/logs/ and read its contents."
```

### Test File Access
```powershell
gemini -i "Read the first 200 characters of DOCUMENT_ROOT/Employee_Handbook_2024.txt to verify file access."
```

---

## Multi-Agent Comparison

### Compare Two Agents on Same Document
```powershell
# First agent
gemini -i "You are GDPR-Auditor-Agent. Analyze DOCUMENT_ROOT/Data_Processing_Agreement_EU.txt. List all findings in a numbered list."

# Second agent (copy output from first)
gemini -i "You are Legal-Auditor-Agent. Analyze DOCUMENT_ROOT/Data_Processing_Agreement_EU.txt. List all findings in a numbered list."

# Compare: GDPR agent should find privacy issues, Legal agent should find labor law issues
```

### Test Conflict Detection
```powershell
gemini -i "You are Conflict-Finder-Agent. Compare these two documents:
1. DOCUMENT_ROOT/Employee_Handbook_2024.txt 
2. DOCUMENT_ROOT/Legal_Data_Retention_Policy.txt
Find contradictions between them. Specifically look for differences in data storage policies."
```

---

## Best Practices

✅ **Always include context**: "You are [AGENT-NAME]. Analyze [FILE]. Report [WHAT]."

✅ **Be specific**: Ask for specific issue types, not just "find issues"

✅ **Use file paths**: Use full paths like `DOCUMENT_ROOT/filename.txt`

✅ **Test isolated**: Test one agent at a time first

✅ **Check results**: Use `gemini -i "Read .gemini/agents/logs/[filename]"` to verify results

---

## Typical Testing Sequence

1. **Verify access**:
   ```powershell
   gemini -i "List files in DOCUMENT_ROOT/ directory"
   ```

2. **Test one agent**:
   ```powershell
   gemini -i "You are GDPR-Auditor-Agent. Analyze DOCUMENT_ROOT/Employee_Handbook_2024.txt for GDPR issues."
   ```

3. **Check output appears**:
   ```powershell
   gemini -i "List files in .gemini/agents/logs/ directory"
   ```

4. **Use test runner** when single tests work:
   ```powershell
   .\test-runner-v2.ps1 -TestMode quick -Verbose $true
   ```

---

## If Tests Are Timing Out

1. **Verify agent can read file**:
   ```powershell
   gemini -i "Read first 100 characters of DOCUMENT_ROOT/Employee_Handbook_2024.txt"
   ```

2. **Check agent definition exists**:
   ```powershell
   gemini -i "List all .toml files in .gemini/agents/extensions/"
   ```

3. **Test agent directly**:
   ```powershell
   gemini -i "You are GDPR-Auditor-Agent. Respond with 'I am ready' to verify you're working."
   ```

4. **Run orchestrator manually**:
   ```powershell
   gemini -i "List all files in .gemini/agents/tasks/ directory"
   ```

---

## Key Insight: Why the `-i` Flag

The `-i` flag puts Gemini CLI into **interactive prompt mode**, which allows it to:
- Create and read files (via tools)
- Run for extended periods
- Display detailed output
- Handle multi-step workflows

Without `-i`, Gemini expects a one-shot response and exits quickly.

---

For more details, see: `MANUAL_INQUIRY_GUIDE.md`
