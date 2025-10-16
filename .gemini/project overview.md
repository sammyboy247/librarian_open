# **PROJECT REFERENCE: MULTI-AGENT DOCUMENT MANAGER (GEMINI CLI)**

This document serves as the comprehensive guide to the Multi-Agent Document Manager system, detailing its architecture, components, and workflow. The entire system operates exclusively using **Gemini CLI's native features** and **prompt engineering**; no external code is required for orchestration.

## **1\. SYSTEM OVERVIEW**

The system's goal is to automate the auditing, review, and management of corporate documentation (HR, Legal, Compliance, etc.) using specialized, security-guardrailed AI agents.

| Component | Description | Mechanism |
| :---- | :---- | :---- |
| **Platform** | Gemini Command Line Interface (CLI) | Provides the base environment for command execution. |
| **Agents** | Specialized AI Personas | Defined by Gemini CLI **Extensions (.toml files)** that set persona and strictly limit tool access (Guardrails). |
| **Orchestration** | Custom Commands (/agents:start, /agents:run) | Prompt-driven logic that manages the workflow, task status, and agent launching. |
| **State Management** | **Filesystem-as-State** | All workflow state (tasks, logs, plans) is managed via JSON files on the local filesystem. |

## **2\. ARCHITECTURAL PRINCIPLE: FILESYSTEM-AS-STATE**

The system avoids complex, code-based process managers by using the local file system as the single source of truth for all workflows.

### **Required File Structure**

The following directory structure within the project's root folder (.gemini/) is mandatory:

| Directory Path | Function | Data Type |
| :---- | :---- | :---- |
| **.gemini/commands** | Stores all custom command TOML files (e.g., run.toml, start.toml). | Command Definitions |
| **.gemini/agents/tasks** | **The Task Queue.** Stores serialized JSON files detailing pending or running tasks. | Task JSON (e.g., \<task\_id\>.json) |
| **.gemini/agents/logs** | Stores raw agent output and final audit reports upon task completion. | Text Logs (e.g., \<task\_id\>\_report.txt) |
| **.gemini/agents/plans** | Reserved for agents to maintain long-term context, such as the document review calendar. | JSON/Text |
| **.gemini/agents/workspace** | Scratchpad for temporary file reading/writing during agent execution. | Varies |

## **3\. AGENT HIERARCHY AND ROLES (LINE MANAGEMENT)**

Agents are categorized by their function and tool access. **Level 2 Auditor Agents are strictly read-only by extension definition.**

### **Level 0: Executive Orchestrator (The Engine)**

* **Role:** Workflow Controller (/agents:run).  
* **Responsibility:** Reads the task queue, manages task status (PENDING \-\> RUNNING), and constructs the launch command for Level 1/2 Agents.  
* **Tool Access:** Requires broad access (shell, files) to execute the orchestration logic.

### **Level 1: Management Agents (Cross-Cutting Supervisors)**

These agents handle tasks requiring analysis across multiple specialized domains or system maintenance.

* **Conflict-Finder-Agent:** Audits multiple documents for conflicting statements or inconsistent terminology. (Read-Only)  
* **Template-Suite-Agent:** Generates new documents from templates based on variable inputs (e.g., new location, new staff). (Read/Write)  
* **Alert-Agent / Calendar-Agent:** Maintenance roles that monitor and update the document review schedule. (Read/Write)

### **Level 2: Specialized Auditor Agents (Domain Experts)**

These agents are the primary auditors, specialized in single corporate domains.

* **HR-Auditor-Agent:** Focuses on labor law, internal HR policy, and compensation compliance. **Guardrail: Strictly limited to read\_file tool.**  
* **Legal-Auditor-Agent:** Focuses on contractual terms, liability, and jurisdiction validity.  
* **GDPR-Auditor-Agent:** Focuses on data privacy, retention schedules, and international privacy law adherence.  
* **Medical-Auditor-Agent:** Focuses on medical data handling and security protocols.  
* **Governance-Auditor-Agent:** Focuses on corporate bylaws, policy consistency, and structural compliance.

## **4\. CORE ORCHESTRATION COMMANDS**

The entire system's logic is encapsulated in the prompts of two custom commands located in .gemini/commands/.

### **4.1. The Queueing Command: /agents:start.toml**

**Function:** Initializes a new task and queues it for the designated agent.

**Prompt Logic Summary:**

1. **Extract Arguments:** Takes agent\_name and task\_description from user input.  
2. **Generate ID:** Creates a unique 8-character task\_id.  
3. **Construct JSON:** Creates a Task JSON object with mandatory fields: task\_id, agent\_name, status: "PENDING", description, and timestamp.  
4. **Write File:** Uses the write\_file tool to save the JSON object to the queue: .gemini/agents/tasks/\<task\_id\>.json.

### **4.2. The Executive Orchestrator: /agents:run.toml**

**Function:** The central engine that selects a task, locks it, and launches the sub-agent process.

**Prompt Logic Summary (Based on current agents/run.toml):**

1. **Read Queue:** Uses list\_files to see all files in .gemini/agents/tasks/.  
2. **Select Task:** Selects the PENDING task with the oldest timestamp (First-In, First-Out logic).  
3. **Lock Task:** Updates the selected task's JSON file, setting the **status** field from PENDING to **RUNNING**.  
4. **Launch Sub-Agent (CRITICAL STEP):** Constructs and executes a precise shell command using the shell tool.  
   * This command launches a new, separate Gemini CLI process: gemini \-e \<agent\_name\> ...  
   * **IDENTITY FIX:** The command includes a critical identity-setting prompt: "You are the \<agent\_name\>. Your Task ID is \<task\_id\>. Your task is to: \<description\>." This prevents the sub-agent from entering a recursive loop.  
   * **OUTPUT MANDATE:** The launched agent is instructed to write its final status (COMPLETED) to the task file and write its final report **ONLY** to the logs directory: .gemini/agents/logs/\<task\_id\>\_report.txt.

This architecture ensures separation of concerns, strict guardrails on specialized agents, and a robust, transparent workflow managed entirely through file manipulation.