The **Gold Layer** is the final consumption zone. Here, data is transformed into a high-performance, user-friendly format optimized for Business Intelligence (BI) tools and executive reporting.

### 4.1 Data Modeling Strategy

For this project, a **Star Schema** was implemented over a Snowflake Schema. And we implemented it using Views, not physical tables

- **Design Choice:** While Snowflake offers higher normalization and reduces redundancy, the **Star Schema** was selected to prioritize query performance and ease of use for Data Analysts.
- **Justification:** Given the dataset's manageable size, the slight increase in storage (denormalization) is a worthwhile trade-off for the drastic reduction in join complexity, making the model highly intuitive for dashboarding.
- **Views** - were used to implement RLS(metadata columns), are faster, less costly than physical tables, and more adaptable for analytics

### 4.2 Dimension Table Engineering

### **Customer Dimension (`dim_customer`)**

- **Enrichment & Conflict Resolution:** During the integration of multiple source tables, a "Source of Truth" hierarchy was established.
    - *Logic:* In instances where conflicting attributes existed (e.g., disparate gender values across CRM and secondary tables), the record was defaulted to the true source of truth aka master system identified by domain experts.
    - *Null Management:* Left joins were utilized to preserve all primary customer records; any resulting NULLs from enrichment tables were identified as missing source data rather than pipeline errors.
- **Column Prioritization:** Attributes were rearranged by business importance (e.g., Name/ID at the start, `created_date` and audit metadata at the end) to improve readability in BI tools.
- **Surrogate Keys (SK):** A system-generated Surrogate Key was implemented as the Primary Key. This decouples the analytical model from source system Natural Keys, which is critical for handling **Slowly Changing Dimensions (SCD)** where Natural Keys may repeat across historical versions.

### **Product Dimension (`dim_product`)**

- **Current State Logic:** To ensure the dashboard reflects the modern product catalog, a filter was applied to include only active records (End Date IS NULL). This ensures that legacy or retired product versions are excluded from current inventory reporting.
- **Hierarchical Integration:** The Product and Category tables were joined into a single flattened dimension to eliminate the need for analysts to perform manual joins on the product hierarchy.
- **Indexing:** An SK was generated to maintain model consistency.

---

### 4.3 Fact Table Construction

### **Sales Fact (`fact_sales`)**

The Fact table serves as the central hub for quantitative metrics.

- **Key Mapping:** A critical transformation step involved replacing all original source Natural Keys (Product ID, Customer ID) with the newly generated **Surrogate Keys** from the dimension tables.
- Column headings were also rearranged and renamed to be more user friendly

### 4.4 Data Governance & Analytics Enablement

To bridge the gap between engineering and insight, a **Data Catalog** was produced for the Gold Layer.

- **Purpose:** Since this is the only layer accessible to the Analytics team, the catalog provides a detailed map of all definitions, data types, and business logic.
- **Self-Service Support:** By documenting the relationships and column meanings, we minimize "data tribalism" and ensure all analysts are working from a unified version of the truth.

---

## Project Conclusion

The pipeline successfully moves data from a raw, unvalidated CSV state (**Bronze**) through a rigorous cleansing and standardization process (**Silver**), culminating in a highly optimized, governed, and performant analytical model (**Gold**).
