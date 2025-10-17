# ============================================================================
# librarian_open Test Runner (v2 - Enhanced Verbose)
# ============================================================================
# A comprehensive, verbose testing framework for the multi-agent document manager
# with detailed Gemini CLI interaction logging
# ============================================================================

param(
    [string]$TestMode = "all",
    [string]$AgentName = $null,
    [string]$DocumentName = $null,
    [switch]$Verbose = $true,
    [switch]$CleanupLogs = $false,
    [int]$TimeoutSeconds = 120,
    [switch]$DryRun = $false
)

# ============================================================================
# Configuration
# ============================================================================
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommandPath
$GeminiDir = Join-Path $ProjectRoot ".gemini"
$DocumentRoot = Join-Path $ProjectRoot "DOCUMENT_ROOT"
$LogsDir = Join-Path $GeminiDir "logs"
$TasksDir = Join-Path $GeminiDir "agents" "tasks"
$ExtensionsDir = Join-Path $GeminiDir "agents" "extensions"
$TestResultsDir = Join-Path $ProjectRoot "test-results"
$TestIndexFile = Join-Path $ProjectRoot "testDocIndex.md"

# Create directories
@($TestResultsDir, $TasksDir, $LogsDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# ============================================================================
# Logging Functions - ENHANCED VERBOSE OUTPUT
# ============================================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug", "Trace")]
        [string]$Level = "Info",
        [string]$Component = "TestRunner"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss.fff"
    $logMessage = "[$timestamp] [$Component] [$Level] $Message"
    
    switch ($Level) {
        "Success" { Write-Host $logMessage -ForegroundColor Green }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Error" { Write-Host $logMessage -ForegroundColor Red }
        "Debug" { Write-Host $logMessage -ForegroundColor Gray }
        "Trace" { if ($Verbose) { Write-Host $logMessage -ForegroundColor DarkGray } }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
    
    Add-Content -Path (Join-Path $TestResultsDir "verbose-$(Get-Date -Format 'yyyy-MM-dd').log") -Value $logMessage
}

function Write-Divider {
    Write-Host "━" * 100 -ForegroundColor Magenta
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Divider
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Divider
}

function Show-CommandPreview {
    param(
        [string]$Description,
        [string]$Command
    )
    Write-Host ""
    Write-Host "📋 $Description" -ForegroundColor Cyan
    Write-Host "   Command: " -ForegroundColor Gray -NoNewline
    Write-Host "$Command" -ForegroundColor White
    Write-Host ""
}

# ============================================================================
# System Diagnostics
# ============================================================================
function Test-SystemRequirements {
    Write-Section "System Requirements Check"
    
    # Check Gemini CLI
    Write-Log "Checking Gemini CLI availability..." "Debug"
    try {
        $geminiVersion = & gemini --version 2>&1
        Write-Log "✓ Gemini CLI found: $geminiVersion" "Success"
    }
    catch {
        Write-Log "✗ Gemini CLI NOT found in PATH" "Error"
        Write-Log "  Fix: Add Gemini CLI to PATH or use full path" "Warning"
        return $false
    }
    
    # Check directory structure
    Write-Log "Checking .gemini directory structure..." "Debug"
    $requiredDirs = @($TasksDir, $LogsDir, $ExtensionsDir)
    $allExist = $true
    
    foreach ($dir in $requiredDirs) {
        if (Test-Path $dir) {
            Write-Log "✓ $(Split-Path -Leaf $dir) exists" "Success"
        } else {
            Write-Log "✗ $(Split-Path -Leaf $dir) missing" "Error"
            $allExist = $false
        }
    }
    
    # Check test documents
    Write-Log "Checking test documents..." "Debug"
    $docs = Get-ChildItem -Path $DocumentRoot -Filter "*.txt" -ErrorAction SilentlyContinue
    Write-Log "✓ Found $($docs.Count) test documents" "Success"
    foreach ($doc in $docs) {
        Write-Log "  - $($doc.Name)" "Trace"
    }
    
    # List available extensions (agents)
    Write-Log "Checking available agents..." "Debug"
    $agents = Get-ChildItem -Path $ExtensionsDir -Filter "*.toml" -ErrorAction SilentlyContinue
    Write-Log "✓ Found $($agents.Count) agent definitions" "Success"
    foreach ($agent in $agents) {
        $agentName = $agent.BaseName
        Write-Log "  - $agentName" "Trace"
    }
    
    return $allExist
}

# ============================================================================
# Test Document Management
# ============================================================================
class TestDocument {
    [string]$Filename
    [string]$Purpose
    [string[]]$ExpectedAgents
    [string[]]$ExpectedIssues
    [string]$Status = "Pending"
    [string[]]$FlaggedIssues = @()
    [string[]]$FalsePositives = @()
    [string]$TaskId = $null
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
    [string[]]$DebugLog = @()
}

function Get-TestDocuments {
    Write-Log "Loading test document definitions..." "Debug"
    
    $testDocs = @()
    
    $testDocs += [TestDocument]@{
        Filename = "Employee_Handbook_2024.txt"
        Purpose = "Test policy contradictions and GDPR violations"
        ExpectedAgents = @("Policy-Auditor-Agent", "Legal-Auditor-Agent", "GDPR-Auditor-Agent")
        ExpectedIssues = @("Contradictory", "GDPR", "storage")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Legal_Data_Retention_Policy.txt"
        Purpose = "Baseline correct policy"
        ExpectedAgents = @()
        ExpectedIssues = @()
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Data_Processing_Agreement_EU.txt"
        Purpose = "Test overdue review, GDPR and labor law violations"
        ExpectedAgents = @("Governance-Auditor-Agent", "Legal-Auditor-Agent")
        ExpectedIssues = @("Review", "GDPR", "Labor")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Onboarding_Policy_2019.txt"
        Purpose = "Test obsolete policies and overdue reviews"
        ExpectedAgents = @("Policy-Auditor-Agent", "Governance-Auditor-Agent")
        ExpectedIssues = @("Obsolete", "Review")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Contractor_Agreement_US.txt"
        Purpose = "Test labor law violations"
        ExpectedAgents = @("Legal-Auditor-Agent", "HR-Auditor-Agent")
        ExpectedIssues = @("Labor", "Overtime")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Patient_Data_Handling_Protocol.txt"
        Purpose = "Test medical data compliance"
        ExpectedAgents = @("Medical-Auditor-Agent")
        ExpectedIssues = @("Medical", "data")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Marketing_Campaign_Brief.txt"
        Purpose = "Negative test - should have no issues"
        ExpectedAgents = @()
        ExpectedIssues = @()
    }
    
    Write-Log "Loaded $($testDocs.Count) test document definitions" "Success"
    return $testDocs
}

# ============================================================================
# Gemini CLI Interaction - VERBOSE WITH DEBUGGING
# ============================================================================
function New-AuditTask {
    param(
        [string]$DocumentName,
        [string]$AgentName,
        [TestResult]$TestResult
    )
    
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    Write-Log "CREATING NEW AUDIT TASK" "Debug"
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    
    Write-Log "Document: $DocumentName" "Debug"
    Write-Log "Agent: $AgentName" "Debug"
    
    try {
        # Generate task ID
        $taskId = -join ((48..57) + (97..122) | Get-Random -Count 8 | % {[char]$_})
        Write-Log "Generated Task ID: $taskId" "Debug"
        
        # Create task JSON
        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        $taskJson = @{
            task_id = $taskId
            agent_name = $AgentName
            status = "PENDING"
            description = "Audit document: $DocumentName for compliance issues"
            timestamp = $timestamp
            document_path = (Join-Path $DocumentRoot $DocumentName)
        } | ConvertTo-Json
        
        Write-Log "Task JSON:" "Trace"
        Write-Log "$taskJson" "Trace"
        
        # Write task file
        $taskFile = Join-Path $TasksDir "$taskId.json"
        Write-Log "Writing task file: $taskFile" "Debug"
        
        Set-Content -Path $taskFile -Value $taskJson
        
        if (Test-Path $taskFile) {
            $fileSize = (Get-Item $taskFile).Length
            Write-Log "✓ Task file created successfully ($fileSize bytes)" "Success"
            $TestResult.DebugLog += "✓ Task file created: $taskFile"
        } else {
            Write-Log "✗ Failed to create task file" "Error"
            $TestResult.DebugLog += "✗ Task file creation failed"
            return $null
        }
        
        # Verify file content
        $content = Get-Content $taskFile -Raw
        Write-Log "Task file content verified: $($content.Length) characters" "Debug"
        
        Write-Log "Task created successfully with ID: $taskId" "Success"
        $TestResult.DebugLog += "Task created: $taskId"
        
        return $taskId
    }
    catch {
        Write-Log "✗ Exception creating task: $_" "Error"
        $TestResult.DebugLog += "Exception: $_"
        return $null
    }
}

function Invoke-Orchestrator {
    param([TestResult]$TestResult)
    
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    Write-Log "INVOKING ORCHESTRATOR" "Debug"
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    
    # Check task queue before running
    Write-Log "Checking task queue before orchestrator run..." "Debug"
    $pendingTasks = Get-ChildItem -Path $TasksDir -Filter "*.json"
    Write-Log "Pending tasks in queue: $($pendingTasks.Count)" "Debug"
    
    foreach ($task in $pendingTasks) {
        $taskContent = Get-Content $task.FullName | ConvertFrom-Json
        Write-Log "  - $($task.Name): $($taskContent.agent_name)" "Trace"
        $TestResult.DebugLog += "Pending task: $($taskContent.agent_name)"
    }
    
    # Show what the orchestrator command should do
    Show-CommandPreview -Description "ORCHESTRATOR EXECUTION" -Command "gemini -i `"You are the Executive Orchestrator. Process the oldest PENDING task in .gemini/agents/tasks/`""
    
    Write-Log "Attempting to invoke orchestrator via Gemini CLI..." "Info"
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would execute: gemini -i \"Process pending tasks\"" "Warning"
        $TestResult.DebugLog += "DRY RUN: Orchestrator not invoked"
        return $null
    }
    
    try {
        # Try to invoke orchestrator
        $orchestratorOutput = & gemini -i "You are the Executive Orchestrator running in .gemini/ directory. Scan .gemini/agents/tasks/ for PENDING tasks. If found, update status to RUNNING and launch the agent. Report what you did." 2>&1 | Out-String
        
        Write-Log "Orchestrator output received ($($orchestratorOutput.Length) characters)" "Debug"
        Write-Log "Output: $($orchestratorOutput.Substring(0, [Math]::Min(500, $orchestratorOutput.Length)))..." "Trace"
        
        $TestResult.DebugLog += "Orchestrator executed, output: $($orchestratorOutput.Length) chars"
        
        return $orchestratorOutput
    }
    catch {
        Write-Log "✗ Orchestrator invocation failed: $_" "Error"
        $TestResult.DebugLog += "Orchestrator error: $_"
        return $null
    }
}

function Wait-TaskCompletion {
    param(
        [string]$TaskId,
        [int]$TimeoutSeconds = 120,
        [TestResult]$TestResult
    )
    
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    Write-Log "WAITING FOR TASK COMPLETION" "Debug"
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    Write-Log "Task ID: $TaskId" "Debug"
    Write-Log "Timeout: $TimeoutSeconds seconds" "Debug"
    Write-Log "Monitoring: $LogsDir" "Debug"
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $pollInterval = 2
    $pollCount = 0
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $pollCount++
        $resultFile = Join-Path $LogsDir "${TaskId}_report.txt"
        
        Write-Log "Poll #$pollCount (${elapsed}s elapsed): Checking for $resultFile" "Trace" | % { $_ -replace '{elapsed}', [math]::Round($stopwatch.Elapsed.TotalSeconds, 1) }
        
        if (Test-Path $resultFile) {
            $fileSize = (Get-Item $resultFile).Length
            Write-Log "✓ Result file found! ($fileSize bytes)" "Success"
            Write-Log "Reading task result..." "Debug"
            
            $resultContent = Get-Content $resultFile -Raw
            Write-Log "Result content: $($resultContent.Substring(0, [Math]::Min(500, $resultContent.Length)))..." "Trace"
            
            $TestResult.DebugLog += "Task completed, result file: $fileSize bytes"
            return $resultContent
        }
        
        # List files in logs directory for debugging
        $filesInLogs = Get-ChildItem -Path $LogsDir -Filter "*.txt" -ErrorAction SilentlyContinue
        Write-Log "Files in logs dir: $($filesInLogs.Count)" "Trace"
        
        Start-Sleep -Seconds $pollInterval
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
    
    Write-Host "" # newline
    $elapsedSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
    Write-Log "✗ Task $TaskId TIMED OUT after $elapsedSeconds seconds" "Error"
    Write-Log "Total polls attempted: $pollCount" "Warning"
    
    $TestResult.DebugLog += "TIMEOUT: Task did not complete within $TimeoutSeconds seconds after $pollCount polls"
    
    # List tasks and logs for debugging
    Write-Log "Tasks in queue: $(Get-ChildItem $TasksDir -Filter '*.json' | Measure-Object | Select -ExpandProperty Count)" "Debug"
    Write-Log "Logs created: $(Get-ChildItem $LogsDir -Filter '*.txt' | Measure-Object | Select -ExpandProperty Count)" "Debug"
    
    return $null
}

# ============================================================================
# Result Parsing and Validation
# ============================================================================
function Parse-AuditResult {
    param(
        [string]$ResultContent,
        [TestDocument]$TestDoc,
        [TestResult]$TestResult
    )
    
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    Write-Log "PARSING AUDIT RESULT" "Debug"
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    
    $issues = @()
    
    if (-not $ResultContent) {
        Write-Log "No result content to parse" "Warning"
        $TestResult.DebugLog += "No result content"
        return $issues
    }
    
    Write-Log "Result length: $($ResultContent.Length) characters" "Debug"
    $TestResult.DebugLog += "Parsing result: $($ResultContent.Length) chars"
    
    $lines = $ResultContent -split "`n"
    Write-Log "Lines in result: $($lines.Count)" "Debug"
    
    $issueKeywords = @("issue", "violation", "flag", "error", "concern", "problem", "risk")
    $matchCount = 0
    
    foreach ($line in $lines) {
        foreach ($keyword in $issueKeywords) {
            if ($line -match $keyword -and $line.Length -gt 5) {
                $matchCount++
                Write-Log "Found issue line: $($line.Substring(0, [Math]::Min(80, $line.Length)))" "Debug"
                $issues += $line.Trim()
                break
            }
        }
    }
    
    Write-Log "Extracted $($issues.Count) issues from $matchCount keyword matches" "Success"
    $TestResult.DebugLog += "Extracted $($issues.Count) issues"
    
    return $issues
}

function Test-AuditResult {
    param(
        [TestDocument]$TestDoc,
        [string[]]$IdentifiedIssues,
        [TestResult]$TestResult
    )
    
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    Write-Log "VALIDATING AUDIT RESULT" "Debug"
    Write-Log "═══════════════════════════════════════════════════════════════" "Debug"
    
    Write-Log "Expected issues: $($TestDoc.ExpectedIssues -join ', ')" "Debug"
    Write-Log "Identified issues: $($IdentifiedIssues -join ', ')" "Debug"
    
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
                Write-Log "✓ Matched: $expected" "Debug"
                break
            }
        }
    }
    
    if ($TestDoc.ExpectedIssues.Count -gt 0) {
        $result.CoverageRate = [math]::Round(($matchCount / $TestDoc.ExpectedIssues.Count) * 100, 2)
        Write-Log "Coverage: $matchCount / $($TestDoc.ExpectedIssues.Count) = $($result.CoverageRate)%" "Info"
    } else {
        $result.CoverageRate = if ($IdentifiedIssues.Count -eq 0) { 100 } else { 0 }
        $result.FalsePositives = $IdentifiedIssues
        if ($result.FalsePositives.Count -gt 0) {
            Write-Log "False positives detected: $($result.FalsePositives.Count)" "Warning"
        }
    }
    
    $result.Pass = ($result.CoverageRate -ge 80) -and ($result.FalsePositives.Count -eq 0)
    
    Write-Log "Result: $(if ($result.Pass) { 'PASS' } else { 'FAIL' })" $(if ($result.Pass) { "Success" } else { "Warning" })
    $TestResult.DebugLog += "Validation: $($result.CoverageRate)% coverage, Pass: $($result.Pass)"
    
    return $result
}

# ============================================================================
# Main Test Execution
# ============================================================================
function Invoke-DocumentTest {
    param(
        [TestDocument]$TestDoc,
        [string]$AgentName
    )
    
    Write-Section "TEST: $($TestDoc.Filename) with $AgentName"
    
    $testResult = [TestResult]@{
        DocumentName = $TestDoc.Filename
        AgentName = $AgentName
        StartTime = Get-Date
        Status = "Running"
        DebugLog = @()
    }
    
    try {
        Write-Log "Starting test..." "Info"
        
        # Step 1: Create task
        $taskId = New-AuditTask -DocumentName $TestDoc.Filename -AgentName $AgentName -TestResult $testResult
        
        if (-not $taskId) {
            $testResult.Status = "Failed"
            Write-Log "Failed to create task - aborting test" "Error"
            $testResult.EndTime = Get-Date
            $testResult.Duration = $testResult.EndTime - $testResult.StartTime
            return $testResult
        }
        
        $testResult.TaskId = $taskId
        
        # Step 2: Invoke orchestrator
        Write-Host ""
        Invoke-Orchestrator -TestResult $testResult | Out-Null
        
        # Step 3: Wait for completion
        Write-Host ""
        Write-Log "Polling for task completion..." "Info"
        $resultContent = Wait-TaskCompletion -TaskId $taskId -TimeoutSeconds $TimeoutSeconds -TestResult $testResult
        
        Write-Host ""
        
        if ($resultContent) {
            $testResult.RawOutput = $resultContent
            $testResult.Issues = Parse-AuditResult -ResultContent $resultContent -TestDoc $TestDoc -TestResult $testResult
            $testResult.Status = "Completed"
            
            $validation = Test-AuditResult -TestDoc $TestDoc -IdentifiedIssues $testResult.Issues -TestResult $testResult
            $testResult.Metrics = $validation
            
            Write-Log "TEST RESULT: $(if ($validation.Pass) { '✓ PASS' } else { '✗ FAIL' }) - Coverage: $($validation.CoverageRate)%" $(if ($validation.Pass) { "Success" } else { "Warning" })
        } else {
            $testResult.Status = "Failed"
            Write-Log "No result received - test FAILED" "Error"
        }
    }
    catch {
        $testResult.Status = "Failed"
        Write-Log "Exception during test: $_" "Error"
        $testResult.DebugLog += "Exception: $_"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = $testResult.EndTime - $testResult.StartTime
    
    Write-Log "Test duration: $($testResult.Duration.TotalSeconds) seconds" "Info"
    
    return $testResult
}

# ============================================================================
# Results Publishing
# ============================================================================
function Publish-TestResults {
    param([TestResult[]]$Results)
    
    Write-Section "FINAL TEST RESULTS"
    
    Write-Log "Total tests run: $($Results.Count)" "Info"
    
    $passed = @($Results | Where-Object { $_.Metrics.Pass -eq $true }).Count
    $failed = @($Results | Where-Object { $_.Metrics.Pass -eq $false }).Count
    
    if ($Results.Count -gt 0) {
        $passRate = [math]::Round(($passed / $Results.Count) * 100, 2)
        Write-Log "PASSED: $passed | FAILED: $failed | PASS RATE: $passRate%" $(if ($failed -eq 0) { "Success" } else { "Warning" })
    }
    
    Write-Host ""
    Write-Host "Detailed Results:" -ForegroundColor Cyan
    foreach ($result in $Results) {
        $status = if ($result.Metrics.Pass) { "✓ PASS" } else { "✗ FAIL" }
        $coverage = $result.Metrics.CoverageRate
        Write-Host "$status | $($result.DocumentName) | Agent: $($result.AgentName) | Coverage: $coverage% | Duration: $($result.Duration.TotalSeconds)s"
    }
    
    # Save detailed report
    $reportPath = Join-Path $TestResultsDir "test-report-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').json"
    $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath
    Write-Log "Detailed report saved: $reportPath" "Success"
    
    # Save debug logs
    $debugPath = Join-Path $TestResultsDir "debug-log-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').txt"
    $Results | ForEach-Object {
        "=== $($_.DocumentName) with $($_.AgentName) ===" | Out-File $debugPath -Append
        $_.DebugLog | Out-File $debugPath -Append
    } | Out-Null
    Write-Log "Debug log saved: $debugPath" "Success"
}

# ============================================================================
# Main Execution
# ============================================================================
function Main {
    Write-Divider
    Write-Host "   librarian_open TEST RUNNER (v2 - VERBOSE)" -ForegroundColor Magenta
    Write-Divider
    
    $runStartTime = Get-Date
    Write-Log "Test run started at $runStartTime" "Info"
    Write-Log "Test mode: $TestMode" "Info"
    Write-Log "Timeout: $TimeoutSeconds seconds" "Info"
    if ($DryRun) { Write-Log "DRY RUN MODE - No actual commands will execute" "Warning" }
    
    # Check requirements
    if (-not (Test-SystemRequirements)) {
        Write-Log "System requirements not met - aborting" "Error"
        return
    }
    
    # Show manual inquiry example
    Write-Section "MANUAL INQUIRY EXAMPLE"
    Show-CommandPreview -Description "To manually start an inquiry (GDPR audit)" -Command 'gemini -i "You are the GDPR-Auditor-Agent. Read DOCUMENT_ROOT/Employee_Handbook_2024.txt and check for GDPR violations."'
    
    # Get test documents
    $testDocs = Get-TestDocuments
    $allResults = @()
    
    # Filter and run tests
    if ($DocumentName) {
        $testDocs = $testDocs | Where-Object { $_.Filename -eq $DocumentName }
        if ($testDocs.Count -eq 0) {
            Write-Log "No test document found: $DocumentName" "Error"
            return
        }
    }
    
    foreach ($testDoc in $testDocs) {
        $agentsToTest = $testDoc.ExpectedAgents
        
        if ($AgentName) {
            $agentsToTest = $agentsToTest | Where-Object { $_ -eq $AgentName }
        }
        
        if ($TestMode -eq "quick" -and $agentsToTest.Count -eq 0) {
            continue
        }
        
        if ($agentsToTest.Count -eq 0) {
            $agentsToTest = @("Governance-Auditor-Agent")
        }
        
        foreach ($agent in $agentsToTest) {
            $result = Invoke-DocumentTest -TestDoc $testDoc -AgentName $agent
            $allResults += $result
            
            Start-Sleep -Milliseconds 500
        }
    }
    
    # Cleanup logs if requested
    if ($CleanupLogs -and -not $DryRun) {
        Write-Log "Cleaning up old logs..." "Debug"
        Get-ChildItem -Path $LogsDir -Filter "*.txt" -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    
    # Publish results
    Publish-TestResults -Results $allResults
    
    $runEndTime = Get-Date
    $totalDuration = $runEndTime - $runStartTime
    Write-Log "Total test run duration: $($totalDuration.TotalSeconds) seconds" "Success"
    Write-Log "Test run completed at $runEndTime" "Success"
    
    Write-Divider
}

# Run main execution
Main
