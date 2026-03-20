The **Bronze Layer** acts as the initial landing zone for raw data. The primary objective here is high-fidelity ingestion: capturing source data exactly as it exists to ensure a reliable "checkpoint" before any transformation occurs.

### 3.1 Ingestion Strategy

For this pipeline, a **Pull-based Ingestion** model was selected to handle incoming flat files.

- **Source Format:** CSV (Comma Separated Values).
- **Extraction Type:** **Full Extraction.** Given the current data volume is manageable, a full refresh was chosen over incremental loading to reduce pipeline complexity and ensure data consistency.
- **Data Integrity (Ingestion):** All columns were ingested as `VARCHAR`. This "Schema-on-Read" approach prevents pipeline failures due to data type mismatches or corrupted formatting in the source files, deferring casting logic to the Silver layer.

### 3.2 Storage & Schema Design

The Bronze layer is designed for simplicity and ease of maintenance.

- **SCD Strategy:** **Slowly Changing Dimension (SCD) Type 1.** Data is overwritten during each load. This keeps the storage footprint small and simplifies the architecture by removing the need to track historical state at the raw level.
- **DDL Implementation:** Tables are initialized using `DROP TABLE IF EXISTS` followed by a `CREATE` statement to ensure a clean state for the SCD Type 1 logic.

### 3.3 Technical Constraints & Architecture

During development, several platform-specific constraints in **MySQL** informed the final architecture:

- **Stored Procedures:** While modularity was a goal, MySQL’s limitation regarding external file reading within stored procedures required the ingestion logic to reside in external scripts.
- **Access Control:** The lack of traditional "Schema" support in MySQL (for RBAC) required a flat database structure, emphasizing the importance of strict naming conventions for organizational clarity.
- **Error Handling:** Despite the stored procedure limitation, manual error handling was prioritized to ensure pipeline stability during failures.

---

### 3.4 Exploratory Data Analysis (EDA) & Discovery

Once the data was landed, a thorough inspection was conducted to map out the journey to the Silver layer.

| **Action** | **Findings / Results** |
| --- | --- |
| **Row Count Validation** | Executed `SELECT COUNT(*)` across all tables to verify 1:1 parity between source files and Bronze tables. |
| **Data Inspection** | Used `SELECT * LIMIT 100` to identify patterns. Discovered products with identical names but different IDs and prices across different years. |
| **Relationship Mapping** | Identified common join keys across disparate tables to enable relational analysis. |
| **Schema Gap Analysis** | Identified the need for a derived `category_id` in the `prd` table to facilitate joins with the Category reference data in the Silver layer. |

### 3.5 Design Reflections

- **Upsert vs. Overwrite:** While `DROP/CREATE` was used for simplicity in this iteration, industry best practice for production environments typically favors an **UPSERT** (Update-if-exists, Insert-if-not) pattern. This prevents data downtime.
