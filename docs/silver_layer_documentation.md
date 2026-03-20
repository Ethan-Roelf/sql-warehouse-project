The **Silver Layer** represents the cleansed and transformed version of the raw data. The goal of this layer is to provide a reliable, query-ready foundation for downstream analytics and the Gold layer.

### 2.1 Schema Evolution & Naming Conventions

The Silver tables were designed to maintain schema consistency with the source while introducing architectural improvements.

- **DDL Strategy:** Silver tables mirror the Bronze structure but include a mandatory metadata column.
- **Metadata Integration:** A `created_date` column was added to every record. This is crucial for **Slowly Changing Dimensions (SCD)**, allowing us to track when records were ingested into the refined layer and manage versioning.
- **Naming Standards:** All tables follow the project’s strict naming conventions to ensure discoverability across the data platform.

### 2.2 The Data Quality (DQ) Gate

A core principle of this pipeline is: **"Never assume data is clean."** Before the Silver load scripts were finalized, the Bronze layer underwent a rigorous DQ audit to identify and resolve issues at the source.

**Standard Checks Included:**

| **Check Category** | **Description** | **Implementation** |
| --- | --- | --- |
| **Uniqueness** | Identify null or duplicate Primary Keys (PKs). | `DISTINCT` counts vs. `ROW_NUMBER()` |
| **String Integrity** | Remove leading/trailing whitespaces. | `TRIM()` comparison |
| **Standardization** | Aligning categorical values (e.g., Gender). | `CASE` statements / Mapping tables |
| **Temporal Logic** | Validate date ranges and chronological order. | Logical comparison ($Date_{End} > Date_{Start}$) |
| **Referential Integrity** | Ensure orphans do not exist between related sets. | Left Anti-Joins |

---

### 2.3 Table-Specific Transformation Logic

### **CRM (Customer Relationship Management)**

- **Deduplication:** Addressed duplicate `cid` (Customer ID) entries. To handle versioning, the `ROW_NUMBER()` window function was used (partitioned by `cid`, ordered by `created_date`) to isolate the most recent record.
- **Whitespace Removal:** Evaluated string fields where `Field != TRIM(Field)`. All identified unwanted spaces were removed to ensure search reliability.
- **Categorical Normalization:** Performed `DISTINCT` checks on gender columns. Values like 'M' and 'F' were mapped to 'Male' and 'Female' to improve end-user readability.
- **Validation:** Post-load DQ checks on the Silver CRM table confirmed a 0% error rate, successfully resolving all issues found in Bronze.

### **PRD (Products)**

- **Key Derivation:** Used `SUBSTRING` to extract a 5-character Category ID from the `prd_key`.
- **Standardization:** Resolved a delimiter mismatch between the Product and Category tables. The `REPLACE` function was used to convert dashes () to underscores (`_`), enabling successful joins.
- **Financial Logic:** Product costs were audited for negatives or NULLs; NULL values were defaulted to `0`.
- **Business Mapping:** Replaced cryptic "PRD line codes" with business-friendly terminology based on stakeholder definitions.
- **Interval Integrity:** Used the `LEAD()` window function to ensure that a record's `end_date` matches the `start_date` of the subsequent record, preventing overlapping timelines.

### **Sales Details**

- **Type Casting:** 8-digit integers (YYYYMMDD) were validated for length and cast into proper `DATE` types.
- **Invalid Value Handling:** Logically incorrect `0` values were converted to `NULL` via `NULLIF` before casting.
- **Business Rule Enforcement:** Verified the formula $Sales = Quantity \times Price$. For records with NULL sales values, the field was programmatically recalculated using the available quantity and price variables.

### **Customer AZ**

- **Outlier Detection:** Implemented age-range filters to flag "impossible" data, specifically identifying individuals with a calculated age > 100 or birthdates occurring in the future.

---

### 2.4 Transition Status

The Silver layer is now fully populated, validated, and optimized for performance. It serves as the "Gold-ready" source for business logic and aggregations.
