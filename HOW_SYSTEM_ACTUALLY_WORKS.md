# How the Gemini CLI Agent System Actually Works

## Key Findings from Live Testing

After testing the actual Gemini CLI, here's how the system **really** works:

### 1. **Agent Tool Limitations**

Each agent has **limited tools** defined in its extension TOML:

```toml
# .gemini/agents/extensions/gdpr_auditor.toml
[tools]
include = ["read_file", "read_many_files"]
```

**This means:**
- ✓ Agents CAN read documents
- ✓ Agents CAN read multiple files
- ✗ Agents CANNOT write files directly
- ✗ Agents CANNOT run shell commands
- ✗ Agents CANNOT create report files

### 2. **The Correct Process Flow**

```
STEP 1: You create task JSON
  ↓ (manually or via gemini agents:start)
  .gemini/agents/tasks/{taskId}.json (PENDING)

STEP 2: You run orchestrator
  ↓ (gemini agents:run)

STEP 3: Orchestrator reads tasks
  ↓
  Finds oldest PENDING task

STEP 4: Orchestrator launches agent with special prompt
  ↓ (runs: gemini -e agent_name --prompt "...")
  Prompt includes instructions to write report

STEP 5: Agent processes documents
  ↓
  Generates findings (text output)

STEP 6: Orchestrator captures output
  ↓
  Writes to .gemini/agents/logs/{taskId}_report.txt

STEP 7: Orchestrator updates task status to COMPLETED
  ↓
  Updates .gemini/agents/tasks/{taskId}.json
```

### 3. **Manual Task Creation**

Create a PowerShell script or manually write JSON:

```powershell
$taskId = "gdpr$(Get-Random -Minimum 10000 -Maximum 99999)"
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

$taskJson = @{
    task_id = $taskId
    agent_name = "gdpr_auditor"
    status = "PENDING"
    description = "Audit all documents for GDPR compliance"
    timestamp = $timestamp
} | ConvertTo-Json

$taskJson | Out-File -Path ".gemini\agents\tasks\$taskId.json"
```

### 4. **The `gemini agents:start` Command**

When you run:
```bash
gemini agents:start "gdpr_auditor" "Audit all documents"
```

The **Claude LLM in Gemini CLI** is supposed to:
1. Read the `.gemini/commands/start.toml` prompt
2. Understand it needs to create a task JSON file
3. Use available tools to write that file

**However**, Claude (the agent prompt) in this context doesn't have `write_file` tool, so it fails.

### 5. **Working Approach**

**Option A: Create tasks manually via PowerShell**
```powershell
# Use create-task.ps1
.\create-task.ps1

# Or manually with specific task ID
$taskJson | Out-File -Path ".gemini\agents\tasks\mytask.json"
```

**Option B: Let the test runner create tasks**
The test runner can create task JSON files directly (we're not restricted by Claude's tools)

### 6. **Running the Orchestrator**

Once you have a task in the queue:

```bash
gemini agents:run
```

The orchestrator will:
1. Scan `.gemini/agents/tasks/`
2. Find the oldest PENDING task
3. Read its details (agent_name, task_id, description)
4. Launch the agent with a prompt like:
   ```
   gemini -e gdpr_auditor --prompt "You are GDPR Auditor. Task ID: gdpr92558. 
   Audit all documents for GDPR compliance. 
   Write report to .gemini/agents/logs/gdpr92558_report.txt"
   ```
5. Capture the agent's output
6. Write it to the logs directory

### 7. **Why Tests Were Timing Out**

**The chain of events:**
1. ✓ Task JSON created successfully
2. ✓ Orchestrator runs: `gemini agents:run`
3. ✓ Orchestrator finds task
4. ✓ Orchestrator launches agent with special prompt
5. ✓ Agent starts processing
6. ✗ **Agent's special prompt instructs it to write file**
7. ✗ **But agent only has read_file tools, not write_file**
8. ✗ **Agent can't complete the write instruction**
9. ✗ **No report file created**
10. ✗ **Test polling times out looking for report**

### 8. **The Solution**

The **orchestrator itself** must be responsible for capturing output and writing files, not the agent.

**Current setup assumes:**
- Agent: Reads documents, generates findings (as text output)
- Orchestrator: Captures that output, writes to logs

**But the run.toml prompt tells agent to write file**, which it can't do.

### 9. **How to Fix the Test Framework**

Update the agent extensions to give them necessary tools:

```toml
# .gemini/agents/extensions/gdpr_auditor.toml
[tools]
include = ["read_file", "read_many_files", "write_file"]
```

OR

Update the orchestrator to:
1. Capture agent output directly
2. Write it to logs itself
3. Not expect agent to write files

### 10. **What Actually Works Right Now**

✅ Creating tasks manually
✅ Running orchestrator
✅ Agents reading documents
✗ Agents writing reports (need file tools or different approach)

## Quick Test

```powershell
# 1. Create task
cd D:\dev\librarian_open
.\create-task.ps1

# 2. View task
Get-ChildItem .gemini\agents\tasks\

# 3. Run orchestrator
gemini agents:run

# 4. Wait 5 seconds
Start-Sleep -Seconds 5

# 5. Check for results
Get-ChildItem .gemini\agents\logs\
Get-Content .gemini\agents\logs\*.txt 2>/dev/null | Select-Object -First 100
```

## Recommendations

1. **Add write_file tool to all agents** that need to create reports
2. **Or modify orchestrator** to be responsible for output capture
3. **Or use stdout/stdout redirection** to capture agent output
4. **Document the agent tool permissions** in each extension file

