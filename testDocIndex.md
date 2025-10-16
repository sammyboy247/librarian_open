# Test Document Index

This document provides an index of all test documents located in the `DOCUMENT_ROOT` directory. Each entry outlines the document's filename, its purpose within the test suite, the agents expected to flag it, and the specific issues it contains.

---

### 1. Employee_Handbook_2024.txt
- **Purpose:** To test for policy contradictions and GDPR violations.
- **Agents to Flag:** `Policy Agent`, `Legal Agent`.
- **Specific Issues:**
    - **Contradictory Policy:** States that employee data will be stored "indefinitely," which directly contradicts the `Legal_Data_Retention_Policy.txt` (2-year limit).
    - **GDPR Violation:** Indefinite storage of personal data is a violation of GDPR's data minimization and storage limitation principles.

---

### 2. Legal_Data_Retention_Policy.txt
- **Purpose:** To serve as the baseline "correct" data retention policy for identifying contradictions.
- **Agents to Flag:** None.
- **Specific Issues:** This document is intended to be compliant and should not be flagged.

---

### 3. Data_Processing_Agreement_EU.txt
- **Purpose:** To test for overdue review dates, GDPR violations, and labor law violations.
- **Agents to Flag:** `Governance Agent`, `Legal Agent`, `Policy Agent`.
- **Specific Issues:**
    - **Overdue Review Date:** `last_reviewed` date is `2023-11-01`.
    - **GDPR Violation:** Specifies a 5-year data storage period, which may be excessive and contradicts the "minimum period necessary" principle.
    - **Labor Law Violation:** Includes a clause requiring employees to work a minimum of 50 hours per week, which is a potential violation of EU labor laws.
    - **Governance Inconsistency:** The labor law clause is out of place in a data processing agreement.

---

### 4. Onboarding_Policy_2019.txt
- **Purpose:** To test for obsolete policies and overdue review dates.
- **Agents to Flag:** `Policy Agent`, `Governance Agent`.
- **Specific Issues:**
    - **Obsolete Policy:** The document is from 2019 and references outdated technology ("CD-ROMs").
    - **Overdue Review Date:** `last_reviewed` date is `2019-05-20`.

---

### 5. Contractor_Agreement_US.txt
- **Purpose:** To test for labor law violations and governance inconsistencies.
- **Agents to Flag:** `Legal Agent`, `Policy Agent`.
- **Specific Issues:**
    - **Labor Law Violation:** Denies overtime pay to contractors, which could be illegal under certain circumstances (e.g., employee misclassification).
    - **Governance Inconsistency:** The document is for contractors but contains a clause referring to "employees" ("All employees are required to work a minimum of 50 hours per week").

---

### 6. Patient_Data_Handling_Protocol.txt
- **Purpose:** To test for medical/HIPAA data privacy violations.
- **Agents to Flag:** `Legal Agent`.
- **Specific Issues:**
    - **HIPAA Violation:** Allows patient records to be stored on a shared drive accessible by all employees.
    - **HIPAA Violation:** Explicitly permits the use of patient names in published research, a severe breach of patient confidentiality.

---

### 7. Marketing_Campaign_Brief.txt
- **Purpose:** To test for missing metadata.
- **Agents to Flag:** `Governance Agent`.
- **Specific Issues:**
    - **Missing Metadata:** The front matter is missing the required `last_reviewed` field.