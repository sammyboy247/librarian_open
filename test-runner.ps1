# ============================================================================
# librarian_open Test Runner
# ============================================================================
# A comprehensive testing framework for the multi-agent document manager
# that interacts with Gemini CLI and validates audit results
# ============================================================================

param(
    [string]$TestMode = "all",           # all, quick, agent, document
    [string]$AgentName = $null,          # Specific agent to test
    [string]$DocumentName = $null,       # Specific document to test
    [switch]$Verbose = $false,
    [switch]$CleanupLogs = $false,
    [int]$TimeoutSeconds = 120
)

# ============================================================================
# Configuration
# ============================================================================
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommandPath
$GeminiDir = Join-Path $ProjectRoot ".gemini"
$DocumentRoot = Join-Path $ProjectRoot "DOCUMENT_ROOT"
$LogsDir = Join-Path $GeminiDir "logs"
$TasksDir = Join-Path $GeminiDir "agents" "tasks"
$TestResultsDir = Join-Path $ProjectRoot "test-results"
$TestIndexFile = Join-Path $ProjectRoot "testDocIndex.md"

# Create test results directory if it doesn't exist
if (-not (Test-Path $TestResultsDir)) {
    New-Item -ItemType Directory -Path $TestResultsDir | Out-Null
}

# ============================================================================
# Logging Functions
# ============================================================================
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "Success" { Write-Host $logMessage -ForegroundColor Green }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Error" { Write-Host $logMessage -ForegroundColor Red }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
    
    Add-Content -Path (Join-Path $TestResultsDir "test-run-$(Get-Date -Format 'yyyy-MM-dd').log") -Value $logMessage
}

function Write-Divider {
    Write-Host "━" * 80 -ForegroundColor Magenta
}

# ============================================================================
# Test Data Structure
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
    [string]$Status = "Pending"  # Pending, Running, Completed, Failed
    [string]$TaskId = $null
    [string[]]$Issues = @()
    [string]$RawOutput = ""
    [hashtable]$Metrics = @{}
}

# ============================================================================
# Parse Test Document Index
# ============================================================================
function Get-TestDocuments {
    Write-Log "Parsing test document index..."
    
    $testDocs = @()
    
    # Define test documents based on testDocIndex.md structure
    $testDocs += [TestDocument]@{
        Filename = "Employee_Handbook_2024.txt"
        Purpose = "Test policy contradictions and GDPR violations"
        ExpectedAgents = @("Policy-Auditor-Agent", "Legal-Auditor-Agent", "GDPR-Auditor-Agent")
        ExpectedIssues = @("Contradictory Policy", "GDPR Violation")
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
        ExpectedAgents = @("Governance-Auditor-Agent", "Legal-Auditor-Agent", "GDPR-Auditor-Agent")
        ExpectedIssues = @("Overdue Review", "GDPR Violation", "Labor Law Violation")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Onboarding_Policy_2019.txt"
        Purpose = "Test obsolete policies and overdue reviews"
        ExpectedAgents = @("Policy-Auditor-Agent", "Governance-Auditor-Agent")
        ExpectedIssues = @("Obsolete Policy", "Overdue Review")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Contractor_Agreement_US.txt"
        Purpose = "Test labor law violations and inconsistencies"
        ExpectedAgents = @("Legal-Auditor-Agent", "HR-Auditor-Agent")
        ExpectedIssues = @("Labor Law Violation", "Governance Inconsistency")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Patient_Data_Handling_Protocol.txt"
        Purpose = "Test HIPAA and medical data compliance"
        ExpectedAgents = @("Medical-Auditor-Agent", "GDPR-Auditor-Agent")
        ExpectedIssues = @("Medical data handling")
    }
    
    $testDocs += [TestDocument]@{
        Filename = "Marketing_Campaign_Brief.txt"
        Purpose = "Test for non-compliance issues (negative test)"
        ExpectedAgents = @()
        ExpectedIssues = @()
    }
    
    Write-Log "Loaded $($testDocs.Count) test documents" "Success"
    return $testDocs
}

# ============================================================================
# Queue Task with Gemini CLI
# ============================================================================
function New-AuditTask {
    param(
        [string]$DocumentName,
        [string]$AgentName
    )
    
    Write-Log "Creating audit task for $DocumentName with $AgentName..."
    
    try {
        # Generate task ID
        $taskId = -join ((48..57) + (97..122) | Get-Random -Count 8 | % {[char]$_})
        
        # Create task JSON
        $taskJson = @{
            task_id = $taskId
            agent_name = $AgentName
            status = "PENDING"
            description = "Audit document: $DocumentName for compliance issues"
            timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        } | ConvertTo-Json
        
        # Write task file
        $taskFile = Join-Path $TasksDir "$taskId.json"
        Set-Content -Path $taskFile -Value $taskJson
        
        Write-Log "Task created with ID: $taskId" "Success"
        return $taskId
    }
    catch {
        Write-Log "Failed to create audit task: $_" "Error"
        return $null
    }
}

# ============================================================================
# Execute Orchestrator
# ============================================================================
function Invoke-Orchestrator {
    Write-Log "Invoking Executive Orchestrator..."
    
    try {
        $orchestratorOutput = & gemini -c "/agents:run" 2>&1
        Write-Log "Orchestrator executed" "Success"
        return $orchestratorOutput
    }
    catch {
        Write-Log "Failed to invoke orchestrator: $_" "Error"
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
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $pollInterval = 2
    
    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $resultFile = Join-Path $LogsDir "${TaskId}_report.txt"
        
        if (Test-Path $resultFile) {
            Write-Log "Task $TaskId completed" "Success"
            return (Get-Content $resultFile -Raw)
        }
        
        Start-Sleep -Seconds $pollInterval
        Write-Host "." -NoNewline
    }
    
    Write-Log "Task $TaskId timed out after $TimeoutSeconds seconds" "Warning"
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
    
    $issues = @()
    
    if (-not $ResultContent) {
        return $issues
    }
    
    $lines = $ResultContent -split "`n"
    foreach ($line in $lines) {
        if ($line -match "issue|violation|flag|error|concern" -and $line.Length -gt 3) {
            $issues += $line.Trim()
        }
    }
    
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
    
    Write-Log "━ Testing document: $($TestDoc.Filename)"
    Write-Log "  Purpose: $($TestDoc.Purpose)"
    
    $testResult = [TestResult]@{
        DocumentName = $TestDoc.Filename
        AgentName = $AgentName
        StartTime = Get-Date
        Status = "Running"
    }
    
    try {
        $taskId = New-AuditTask -DocumentName $TestDoc.Filename -AgentName $AgentName
        
        if (-not $taskId) {
            $testResult.Status = "Failed"
            Write-Log "Failed to create task for $($TestDoc.Filename)" "Error"
            return $testResult
        }
        
        $testResult.TaskId = $taskId
        
        Invoke-Orchestrator | Out-Null
        
        $resultContent = Wait-TaskCompletion -TaskId $taskId -TimeoutSeconds $TimeoutSeconds
        
        if ($resultContent) {
            $testResult.RawOutput = $resultContent
            $testResult.Issues = Parse-AuditResult -ResultContent $resultContent -TestDoc $TestDoc
            $testResult.Status = "Completed"
            
            $validation = Test-AuditResult -TestDoc $TestDoc -IdentifiedIssues $testResult.Issues
            $testResult.Metrics = $validation
            
            Write-Log "  Coverage: $($validation.CoverageRate)% | Pass: $($validation.Pass)" $(if ($validation.Pass) { "Success" } else { "Warning" })
        } else {
            $testResult.Status = "Failed"
            Write-Log "No result received for $($TestDoc.Filename)" "Error"
        }
    }
    catch {
        $testResult.Status = "Failed"
        Write-Log "Test failed with error: $_" "Error"
    }
    
    $testResult.EndTime = Get-Date
    $testResult.Duration = $testResult.EndTime - $testResult.StartTime
    
    return $testResult
}

# ============================================================================
# Run All Tests
# ============================================================================
function Invoke-TestSuite {
    param(
        [string]$Mode = "all",
        [string]$SpecificAgent = $null,
        [string]$SpecificDocument = $null
    )
    
    Write-Divider
    Write-Host "   librarian_open Test Suite" -ForegroundColor Magenta
    Write-Divider
    
    Write-Log "Starting test run in mode: $Mode"
    Write-Log "Project root: $ProjectRoot"
    Write-Log "Document root: $DocumentRoot"
    
    $testDocs = Get-TestDocuments
    $allResults = @()
    
    if ($SpecificDocument) {
        $testDocs = $testDocs | Where-Object { $_.Filename -eq $SpecificDocument }
        if ($testDocs.Count -eq 0) {
            Write-Log "No test document found matching: $SpecificDocument" "Error"
            return
        }
    }
    
    foreach ($testDoc in $testDocs) {
        $agentsToTest = $testDoc.ExpectedAgents
        
        if ($SpecificAgent) {
            $agentsToTest = $agentsToTest | Where-Object { $_ -eq $SpecificAgent }
        }
        
        if ($Mode -eq "quick" -and $agentsToTest.Count -eq 0) {
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
    
    if ($CleanupLogs) {
        Write-Log "Cleaning up old logs..."
        Get-ChildItem -Path $LogsDir -Filter "*.txt" -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    
    Write-Divider
    Publish-TestResults -Results $allResults
}

# ============================================================================
# Publish Test Results
# ============================================================================
function Publish-TestResults {
    param(
        [TestResult[]]$Results
    )
    
    Write-Log "━ Test Results Summary" "Info"
    Write-Log "Total tests run: $($Results.Count)"
    
    $passed = @($Results | Where-Object { $_.Metrics.Pass -eq $true }).Count
    $failed = @($Results | Where-Object { $_.Metrics.Pass -eq $false }).Count
    
    if ($Results.Count -gt 0) {
        $passRate = [math]::Round(($passed / $Results.Count) * 100, 2)
        Write-Log "Passed: $passed | Failed: $failed | Pass rate: $passRate%" $(if ($failed -eq 0) { "Success" } else { "Warning" })
    }
    
    Write-Host "`nDetailed Results:"
    foreach ($result in $Results) {
        $status = if ($result.Metrics.Pass) { "✓ PASS" } else { "✗ FAIL" }
        Write-Host "$status | $($result.DocumentName) | Coverage: $($result.Metrics.CoverageRate)%"
    }
    
    $reportPath = Join-Path $TestResultsDir "test-report-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').json"
    $Results | ConvertTo-Json -Depth 5 | Out-File -FilePath $reportPath
    Write-Log "Detailed report saved to: $reportPath" "Success"
}

# ============================================================================
# Main Execution
# ============================================================================
Write-Log "Test runner starting with mode: $TestMode"

if ($CleanupLogs) {
    Write-Log "Cleanup flag detected - old logs will be removed after tests"
}

Invoke-TestSuite -Mode $TestMode -SpecificAgent $AgentName -SpecificDocument $DocumentName

Write-Log "Test run completed" "Success"
Write-Divider
