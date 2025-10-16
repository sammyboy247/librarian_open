# **DOCUMENT MANAGER: MULTI-AGENT ORCHESTRATION SYSTEM**

## **1\. SYSTEM DEFINITION**

* **System Type:** Prompt-driven Multi-Agent Orchestration System.  
* **Platform:** Gemini Command Line Interface (CLI).  
* **Function:** Specialized document management via highly guardrailed auditors.  
* **Core Pattern:** Filesystem-as-State (Workflow state managed via structured file directories).  
* **Benefit:** Eliminates requirement for custom process management code.

## **2\. REQUIRED FILE STRUCTURE**

### **2.1. Directory Structure**

The following directory paths are mandatory for system operation:

* **.gemini/commands:** Location for TOML files defining all orchestration commands (e.g., /agents:start).  
* **.gemini/agents/tasks:** Task queue directory. Stores serialized JSON files detailing pending agent tasks.  
* **.gemini/agents/plans:** Reserved for long-term execution context or multi-step plans. (Operational Status: Future Use).  
* **.gemini/agents/logs:** Stores raw output, audit reports, and execution logs from completed agent runs.  
* **.gemini/agents/workspace:** Scratchpad directory for file access, creation, or modification during task execution.

### **2.2. Agents (Extensions)**

Agents are defined as specialized Gemini CLI extensions (.toml files) with restricted tool access.

| Agent Name | Specialization | Role and Guardrails | File |
| :---- | :---- | :---- | :---- |
| **HR-Auditor-Agent** | Human Resources (HR) | Read-Only Audit. Focus on HR policy, labor law, and internal consistency. **Tool Access:** Limited exclusively to read\_file. | hr-agent.toml |
| Legal-Auditor-Agent | Contract Law, Liability | (Status: To be defined) |  |
| GDPR-Auditor-Agent | Data Privacy | (Status: To be defined) |  |
| Compliance-Agent | Regulatory Requirements | (Status: To be defined) |  |

## **3\. SYSTEM WORKFLOW COMMANDS**

The system is controlled via two primary custom commands located in .gemini/commands/:

1. **/agents:start \<agent\_name\> \<task\_description\>:**  
   * **Function:** Task initialization and queueing.  
   * **Action:** Command prompt instructs core AI to serialize user request into a JSON object and write the file into the ./agents/tasks/ directory.  
2. **/agents:run:**  
   * **Function:** Orchestration and execution engine.  
   * **Action:** Command prompt instructs core AI to select a pending task, update its status, and launch the designated sub-agent instance with the requisite identity and task parameters.