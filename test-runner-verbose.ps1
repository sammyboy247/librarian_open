# ============================================================================
# librarian_open Test Runner - VERBOSE Edition (CORRECTED CLI SYNTAX)
# ============================================================================
# A comprehensive testing framework for the multi-agent document manager
# with extensive debugging and logging for troubleshooting
# Uses correct Gemini CLI syntax: gemini agents:start "agent_name" "description"
# ============================================================================

param(
    [string]$TestMode = "all",
    [string]$AgentName = $null,
    [string]$DocumentName = $null,
    [switch]$Verbose = $true,
    [switch]$CleanupLogs = $false,
    [int]$TimeoutSeconds = 120,
    [switch]$StopOnFirstFailure = $false
)

# ============================================================================
# Configuration
# ============================================================================
$ProjectRoot = $PSScriptRoot
$GeminiDir = Join-Path $ProjectRoot ".gemini"
$DocumentRoot = Join-Path $ProjectRoot "DOCUMENT_ROOT"
$LogsDir = Join-Path $GeminiDir "logs"
$TasksDir = Join-Path $GeminiDir "agents" "tasks"
$ExtensionsDir = Join-Path $GeminiDir "agents" "extensions"
$TestResultsDir = Join-Path $ProjectRoot "test-results"

if (-not (Test-Path $TestResultsDir)) {
    New-Item -ItemType Directory -Path $TestResultsDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$SessionLogFile = Join-Path $TestResultsDir "test-session-$timestamp.log"

# ============================================================================
# Logging Functions
# ============================================================================
function Write-TestLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG", "VERBOSE")]
        [string]$Level = "INFO"
    )
    
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logMessage = "[$time] [$Level] $Message"
    
    switch ($Level) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "DEBUG" { if ($Verbose) { Write-Host $logMessage -ForegroundColor DarkGray } }
        "VERBOSE" { if ($Verbose) { Write-Host $logMessage -ForegroundColor Gray } }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
    
    Add-Content -Path $SessionLogFile -Value $logMessage
}

function Write-Divider {
    $line = "━" * 100
    Write-Host $line -ForegroundColor Magenta
    Add-Content -Path $SessionLogFile -Value $line
}

function Write-SectionHeader {
    param([string]$Title)
    Write-Divider
    $msg = " $Title "
    $padding = [math]::Floor((100 - $msg.Length) / 2)
    $header = ("━" * $padding) + $msg + ("━" * $padding)
    Write-Host $header -ForegroundColor Magenta
    Add-Content -Path $SessionLogFile -Value $header
    Write-Divider
}

# ============================================================================
# Pre-Flight Checks
# ============================================================================
function Test-Prerequisites {
    Write-TestLog "Starting pre-flight checks..." "INFO"
    
    $allGood = $true
    
    # Check Gemini CLI
    Write-TestLog "  Checking Gemini CLI availability..." "VERBOSE"
    try {
        $geminiVersion = & gemini --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestLog "  ✓ Gemini CLI found: $geminiVersion" "SUCCESS"
        } else {
            Write-TestLog "  ✗ Gemini CLI check failed with exit code: $LASTEXITCODE" "ERROR"
            $allGood = $false
        }
    }
    catch {
        Write-TestLog "  ✗ Gemini CLI not found or not in PATH" "ERROR"
        $allGood = $false
    }
    
    # Check directory structure
    Write-TestLog "  Checking directory structure..." "VERBOSE"
    $requiredDirs = @($GeminiDir, $TasksDir, $LogsDir, $DocumentRoot, $ExtensionsDir)
    
    foreach ($dir in $requiredDirs) {
        if (Test-Path $dir) {
            Write-TestLog "    ✓ Found: $dir" "VERBOSE"
        } else {
            Write-TestLog "    ✗ Missing: $dir" "ERROR"
            $allGood = $false
        }
    }
    
    # Check test documents
    Write-TestLog "  Checking test documents..." "VERBOSE"
    $docCount = (Get-ChildItem -Path $DocumentRoot -Filter "*.txt" -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-TestLog "    Found $docCount test documents" "INFO"
    
    # Check agent extensions
    Write-TestLog "  Checking agent extensions..." "VERBOSE"
    $agentCount = (Get-ChildItem -Path $ExtensionsDir -Filter "*.toml" -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-TestLog "    Found $agentCount agent extensions" "INFO"
    
    if ($allGood) {
        Write-TestLog "Pre-flight checks: ALL PASSED ✓" "SUCCESS"
    } else {
        Write-TestLog "Pre-flight checks: FAILED ✗" "ERROR"
        return $false
    }
    
    return $true
}

# ============================================================================
# File System Diagnostics
# ============================================================================
function Show-FileSystemState {
    Write-TestLog "Task Queue (.gemini/agents/tasks/):" "INFO"
    $taskFiles = Get-ChildItem -Path $TasksDir -Filter "*.json" -ErrorAction SilentlyContinue
    if ($taskFiles.Count -gt 0) {
        foreach ($file in $taskFiles) {
            $content = Get-Content $file -Raw | ConvertFrom-Json
            Write-TestLog "  File: $($file.Name)" "DEBUG"
            Write-TestLog "    Task ID: $($content.task_id)" "DEBUG"
            Write-TestLog "    Agent: $($content.agent_name)" "DEBUG"
            Write-TestLog "    Status: $($content.status)" "DEBUG"
        }
    } else {
        Write-TestLog "  (empty)" "VERBOSE"
    }
    
    Write-TestLog "Logs (.gemini/agents/logs/):" "INFO"
    $logFiles = Get-ChildItem -Path $LogsDir -Filter "*.txt" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($logFiles.Count -gt 0) {
        foreach ($file in $logFiles | Select-Object -First 5) {
            Write-TestLog "  $($file.Name) - Modified: $($file.LastWriteTime)" "DEBUG"
        }
    } else {
        Write-TestLog "  (empty)" "VERBOSE"
    }
}

# ============================================================================
# Test Data Structure
# ============================================================================
class TestDocument {
    [string]$Filename
    [string]$Purpose
    [string[]]$ExpectedAgents
    [string[]]$ExpectedIssues
}

class TestResult {
    [string]$DocumentName
    [string]$AgentName
    [datetime]$StartTime
    [datetime]$EndTime
    [timespan]$Duration
    [string]$Status = "Pending"
    [string]$TaskId = $null
    [string[]]$Issues = @()
    [string]$RawOutput = ""
    [hashtable]$Metrics = @{}
}

# ============================================================================
# Get Test Documents
# ============================================================================
function Get-TestDocuments {
    Write-TestLog "Parsing test documents..." "INFO"
    
    $testDocs = @()
    
    $testDocs += [TestDocument]@{
        Filename = "Employee_Handbook_2024.txt"
        Purpose = "Policy contradictions and GDPR violations"
        ExpectedAgents = @("gdpr_auditor", "legal_auditor")
        ExpectedIssues = @("Contradictory", "GDPR")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Data_Processing_Agreement_EU.txt"
        Purpose = "Overdue review, GDPR and labor law violations"
        ExpectedAgents = @("governance_auditor", "legal_auditor")
        ExpectedIssues = @("Overdue", "GDPR", "Labor Law")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Onboarding_Policy_2019.txt"
        Purpose = "Obsolete policies and overdue reviews"
        ExpectedAgents = @("governance_auditor")
        ExpectedIssues = @("Obsolete", "Overdue")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Contractor_Agreement_US.txt"
        Purpose = "Labor law violations"
        ExpectedAgents = @("legal_auditor", "hr_auditor")
        ExpectedIssues = @("Labor Law", "Inconsistency")
    }
    
    Write-TestLog "Loaded $($testDocs.Count) test documents" "SUCCESS"
    return $testDocs
}

# ============================================================================
# Queue Task with Gemini CLI (CORRECTED SYNTAX)
# ============================================================================
function New-AuditTask {
    param(
        [string]$DocumentName,
        [string]$AgentName
    )
    
    Write-TestLog "Creating audit task via Gemini CLI..." "INFO"
    Write-TestLog "  Document: $DocumentName" "VERBOSE"
    Write-TestLog "  Agent: $AgentName" "VERBOSE"
    
    try {
        $description = "Audit document: $DocumentName for compliance issues"
        
        # Execute gemini CLI command with correct syntax
        # Format: gemini agents:start "agent_name" "description"
        Write-TestLog "  Executing: gemini agents:start '$AgentName' '$description'" "DEBUG"
        Push-Location $ProjectRoot
        
        $cliOutput = & gemini agents:start "$AgentName" "$description" 2>&1
        $exitCode = $LASTEXITCODE
        
        Pop-Location
        
        Write-TestLog "  CLI exit code: $exitCode" "DEBUG"
        
        if ($cliOutput) {
            Write-TestLog "  CLI output:" "VERBOSE"
            foreach ($line in $cliOutput) {
                if ($line) {
                    Write-TestLog "    $line" "DEBUG"
                }
            }
        }
        
        # Check if task was created in queue
        Write-TestLog "  Checking for newly created task..." "VERBOSE"
        Start-Sleep -Milliseconds 500
        
        $taskFiles = Get-ChildItem -Path $TasksDir -Filter "*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        
        if ($taskFiles.Count -gt 0) {
            $latestTaskFile = $taskFiles[0]
            $taskJson = Get-Content $latestTaskFile -Raw | ConvertFrom-Json
            $taskId = $taskJson.task_id
            
            Write-TestLog "  ✓ Task created with ID: $taskId" "SUCCESS"
            Write-TestLog "    Task file: $($latestTaskFile.Name)" "DEBUG"
            Write-TestLog "    Status: $($taskJson.status)" "DEBUG"
            Write-TestLog "    Timestamp: $($taskJson.timestamp)" "DEBUG"
            
            return $taskId
        } else {
            Write-TestLog "  ✗ No task files found in queue" "WARNING"
            Write-TestLog "    Task may not have been created" "WARNING"
            return $null
        }
    }
    catch {
        Write-TestLog "Failed to create audit task: $_" "ERROR"
        Write-TestLog "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $null
    }
}

# ============================================================================
# Execute Orchestrator
# ============================================================================
function Invoke-Orchestrator {
    Write-TestLog "Invoking Orchestrator (gemini agents:run)..." "INFO"
    Write-TestLog "  Working directory: $GeminiDir" "VERBOSE"
    
    try {
        Write-TestLog "  Task queue before orchestrator:" "VERBOSE"
        $taskBefore = Get-ChildItem -Path $TasksDir -Filter "*.json" -ErrorAction SilentlyContinue
        Write-TestLog "    Pending tasks: $($taskBefore.Count)" "DEBUG"
        
        Write-TestLog "  Executing: gemini agents:run" "DEBUG"
        Push-Location $GeminiDir
        $orchestratorOutput = & gemini agents:run 2>&1
        Pop-Location
        
        Write-TestLog "  Orchestrator exit code: $LASTEXITCODE" "DEBUG"
        
        if ($orchestratorOutput) {
            Write-TestLog "  Orchestrator output:" "VERBOSE"
            foreach ($line in $orchestratorOutput) {
                if ($line) {
                    Write-TestLog "    $line" "DEBUG"
                }
            }
        }
        
        Write-TestLog "  Task queue after orchestrator:" "VERBOSE"
        $taskAfter = Get-ChildItem -Path $TasksDir -Filter "*.json" -ErrorAction SilentlyContinue
        Write-TestLog "    Remaining tasks: $($taskAfter.Count)" "DEBUG"
        
        Write-TestLog "Orchestrator executed" "SUCCESS"
        return $orchestratorOutput
    }
    catch {
        Write-TestLog "Failed to invoke orchestrator: $_" "ERROR"
        Write-TestLog "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
        return $null
    }
}

# ============================================================================
# Monitor Task Completion
# ============================================================================
function Wait-TaskCompletion {
    param(
        [string]$TaskId,
        [int]$TimeoutSeconds = 120
    )
    
    Write-TestLog "Monitoring task completion..." "INFO"
    Write-TestLog "  Task ID: $TaskId" "VERBOSE"
    Write-TestLog "  Timeout: ${TimeoutSeconds}s" "VERBOSE"
    Write-TestLog "  Polling interval: 2s" "VERBOSE"
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $pollInterval = 2
    $pollCount = 0
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $pollCount++
        $resultFile = Join-Path $LogsDir "${TaskId}_report.txt"
        
        Write-TestLog "  Poll #$pollCount @ $(Get-Date -Format 'HH:mm:ss'): checking for result..." "VERBOSE"
        
        if (Test-Path $resultFile) {
            Write-TestLog "  ✓ Result file found!" "SUCCESS"
            $content = Get-Content $resultFile -Raw
            Write-TestLog "  File size: $($content.Length) bytes" "DEBUG"
            return $content
        }
        
        Start-Sleep -Seconds $pollInterval
    }
    
    Write-TestLog "✗ Task timed out after $TimeoutSeconds seconds" "WARNING"
    Write-TestLog "  Elapsed: $([math]::Round($stopwatch.Elapsed.TotalSeconds))s" "DEBUG"
    Write-TestLog "  Polls completed: $pollCount" "DEBUG"
    
    return $null
}

# ============================================================================
# Parse Audit Result
# ============================================================================
function Parse-AuditResult {
    param(
        [string]$ResultContent,
        [TestDocument]$TestDoc
    )
    
    Write-TestLog "Parsing audit result..." "INFO"
    
    if (-not $ResultContent) {
        Write-TestLog "  Result content is empty" "WARNING"
        return @()
    }
    
    Write-TestLog "  Content length: $($ResultContent.Length) bytes" "DEBUG"
    
    $issues = @()
    $lines = $ResultContent -split "`n"
    Write-TestLog "  Scanning $($lines.Count) lines for issues..." "VERBOSE"
    
    $issuePatterns = @("issue", "violation", "flag", "error", "concern", "problem", "finding")
    
    foreach ($line in $lines) {
        if ($line.Length -gt 3) {
            foreach ($pattern in $issuePatterns) {
                if ($line -match $pattern) {
                    Write-TestLog "    Found ($pattern): $($line.Substring(0, [math]::Min(80, $line.Length)))" "DEBUG"
                    $issues += $line.Trim()
                    break
                }
            }
        }
    }
    
    Write-TestLog "  Issues extracted: $($issues.Count)" "SUCCESS"
    return $issues
}

# ============================================================================
# Validate Test Results
# ============================================================================
function Test-AuditResult {
    param(
        [TestDocument]$TestDoc,
        [string[]]$IdentifiedIssues
    )
    
    Write-TestLog "Validating test result..." "INFO"
    Write-TestLog "  Expected issues: $($TestDoc.ExpectedIssues.Count)" "VERBOSE"
    Write-TestLog "  Identified issues: $($IdentifiedIssues.Count)" "VERBOSE"
    
    $result = @{
        DocumentName = $TestDoc.Filename
        Expected = $TestDoc.ExpectedIssues
        Identified = $IdentifiedIssues
        Pass = $false
        CoverageRate = 0
        FalsePositives = @()
    }
    
    $matchCount = 0
    foreach ($expected in $TestDoc.ExpectedIssues) {
        foreach ($identified in $IdentifiedIssues) {
            if ($identified -match [regex]::Escape($expected)) {
                $matchCount++
                break
            }
        }
    }
    
    if ($TestDoc.ExpectedIssues.Count -gt 0) {
        $result.CoverageRate = [math]::Round(($matchCount / $TestDoc.ExpectedIssues.Count) * 100, 2)
    } else {
        $result.CoverageRate = if ($IdentifiedIssues.Count -eq 0) { 100 } else { 0 }
        $result.FalsePositives = $IdentifiedIssues
    }
    
    $result.Pass = ($result.CoverageRate -ge 80) -and ($result.FalsePositives.Count -eq 0)
    
    Write-TestLog "  Coverage rate: $($result.CoverageRate)%" "INFO"
    Write-TestLog "  Pass: $($result.Pass)" $(if ($result.Pass) { "SUCCESS" } else { "WARNING" })
    
    return $result
}

# ============================================================================
# Run Single Document Test
# ============================================================================
function Invoke-DocumentTest {
    param(
        [TestDocument]$TestDoc,
        [string]$AgentName
    )
    
    Write-SectionHeader "TESTING: $($TestDoc.Filename)"
    Write-TestLog "Purpose: $($TestDoc.Purpose)" "INFO"
    Write-TestLog "Agent: $AgentName" "INFO"
    
    $testResult = [TestResult]@{
        DocumentName = $TestDoc.Filename
        AgentName = $AgentName
        StartTime = Get-Date
        Status = "Running"
    }
    
    try {
        Write-TestLog "STEP 1: Creating task" "INFO"
        $taskId = New-AuditTask -DocumentName $TestDoc.Filename -AgentName $AgentName
        
        if (-not $taskId) {
            $testResult.Status = "Failed"
            Write-TestLog "RESULT: FAILED - Could not create task" "ERROR"
            return $testResult
        }
        
        $testResult.TaskId = $taskId
        
        Write-TestLog "STEP 2: Running orchestrator" "INFO"
        Invoke-Orchestrator | Out-Null
        
        Write-TestLog "STEP 3: Waiting for task completion" "INFO"
        $resultContent = Wait-TaskCompletion -TaskId $taskId -TimeoutSeconds $TimeoutSeconds
        
        if ($resultContent) {
            Write-TestLog "STEP 4: Parsing results" "INFO"
            $testResult.RawOutput = $resultContent
            $testResult.Issues = Parse-AuditResult -ResultContent $resultContent -TestDoc $TestDoc
            $testResult.Status = "Completed"
            
            Write-TestLog "STEP 5: Validating results" "INFO"
            $validation = Test-AuditResult -TestDoc $TestDoc -IdentifiedIssues $testResult.Issues
            $testResult.Metrics = $validation
            
            Write-TestLog "RESULT: $(if ($validation.Pass) { 'PASSED ✓' } else { 'FAILED ✗' })" $(if ($validation.Pass) { "SUCCESS" } else { "WARNING" })
        } else {
            $testResult.Status = "Failed"
            Write-TestLog "RESULT: FAILED - No result received (timeout)" "ERROR"
        }
    }
    catch {
        $testResult.Status = "Failed"
        Write-TestLog "Test failed with exception: $_" "ERROR"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = $testResult.EndTime - $testResult.StartTime
    
    Write-TestLog "Duration: $($testResult.Duration.TotalSeconds)s" "INFO"
    
    if ($StopOnFirstFailure -and -not $testResult.Metrics.Pass) {
        Write-TestLog "Stopping due to test failure" "WARNING"
        exit 1
    }
    
    return $testResult
}

# ============================================================================
# Run Test Suite
# ============================================================================
function Invoke-TestSuite {
    param(
        [string]$Mode = "all",
        [string]$SpecificAgent = $null,
        [string]$SpecificDocument = $null
    )
    
    Write-SectionHeader "LIBRARIAN_OPEN TEST SUITE - VERBOSE MODE"
    
    Write-TestLog "Session started: $(Get-Date)" "INFO"
    Write-TestLog "Test Mode: $Mode" "INFO"
    Write-TestLog "Timeout: ${TimeoutSeconds}s" "INFO"
    Write-TestLog "Session log: $SessionLogFile" "INFO"
    
    if (-not (Test-Prerequisites)) {
        Write-TestLog "Pre-flight checks failed. Aborting." "ERROR"
        return
    }
    
    $testDocs = Get-TestDocuments
    $allResults = @()
    
    if ($SpecificDocument) {
        $testDocs = $testDocs | Where-Object { $_.Filename -eq $SpecificDocument }
    }
    
    Write-SectionHeader "EXECUTING TESTS"
    
    foreach ($testDoc in $testDocs) {
        $agentsToTest = $testDoc.ExpectedAgents
        
        if ($SpecificAgent) {
            $agentsToTest = $agentsToTest | Where-Object { $_ -eq $SpecificAgent }
        }
        
        if ($agentsToTest.Count -eq 0 -and $Mode -eq "quick") {
            continue
        }
        
        if ($agentsToTest.Count -eq 0) {
            $agentsToTest = @("governance_auditor")
        }
        
        foreach ($agent in $agentsToTest) {
            $result = Invoke-DocumentTest -TestDoc $testDoc -AgentName $agent
            $allResults += $result
            Start-Sleep -Milliseconds 500
        }
    }
    
    Write-SectionHeader "TEST RESULTS"
    Publish-TestResults -Results $allResults
}

# ============================================================================
# Publish Results
# ============================================================================
function Publish-TestResults {
    param([TestResult[]]$Results)
    
    Write-TestLog "Total tests run: $($Results.Count)" "INFO"
    
    if ($Results.Count -eq 0) {
        Write-TestLog "No tests were run" "WARNING"
        return
    }
    
    $passed = @($Results | Where-Object { $_.Metrics.Pass -eq $true }).Count
    $failed = @($Results | Where-Object { $_.Metrics.Pass -eq $false }).Count
    $passRate = [math]::Round(($passed / $Results.Count) * 100, 2)
    
    Write-TestLog "Passed: $passed | Failed: $failed | Pass rate: $passRate%" $(if ($failed -eq 0) { "SUCCESS" } else { "WARNING" })
    
    Write-Host "`nDetailed Results:" -ForegroundColor Cyan
    foreach ($result in $Results) {
        $status = if ($result.Metrics.Pass) { "✓ PASS" } else { "✗ FAIL" }
        Write-Host "$status | $($result.DocumentName) | $($result.AgentName) | Coverage: $($result.Metrics.CoverageRate)% | $([math]::Round($result.Duration.TotalSeconds))s"
    }
    
    $reportPath = Join-Path $TestResultsDir "test-report-$timestamp.json"
    $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath
    Write-TestLog "Report saved: $reportPath" "SUCCESS"
}

# ============================================================================
# Main Execution
# ============================================================================
Write-SectionHeader "INITIALIZATION"
Write-TestLog "Test runner starting" "INFO"
Write-TestLog "Project root: $ProjectRoot" "VERBOSE"

Invoke-TestSuite -Mode $TestMode -SpecificAgent $AgentName -SpecificDocument $DocumentName

Write-SectionHeader "SESSION COMPLETE"
Write-TestLog "Session ended: $(Get-Date)" "SUCCESS"
Write-Divider
