/*
===============================================================================
Stored Procedure: load_silver_layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    Standardizes, cleanses, and validates data from the Bronze layer 
    before loading it into the Silver layer.
===============================================================================
*/

DROP PROCEDURE IF EXISTS load_silver_layer;

DELIMITER //

CREATE PROCEDURE load_silver_layer()
BEGIN
    -- 1. DECLARE VARIABLES FIRST
    -- These variables track execution metadata for performance auditing.
    DECLARE start_time DATETIME;
    DECLARE end_time DATETIME;
    DECLARE batch_start_time DATETIME;
    DECLARE batch_end_time DATETIME;

    -- 2. DECLARE HANDLERS SECOND
    -- This block ensures that if a 'Fatal Error' occurs, the transaction is 
    -- rolled back and detailed error metadata is returned to the user.
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @sqlstate = RETURNED_SQLSTATE, 
        @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
        SELECT '==========================================' AS Message;
        SELECT 'FATAL ERROR DURING LOADING SILVER LAYER' AS Error;
        SELECT CONCAT('Error Number: ', @errno) AS ErrorNo;
        SELECT CONCAT('Error Message: ', @text) AS ErrorMsg;
        SELECT '==========================================' AS Message;
    END;

    -- DATA STANDARDIZATION: We relax SQL_MODE to handle "0000-00-00" dates 
    -- which are common in legacy systems but invalid in standard MySQL.
    SET SESSION sql_mode = REPLACE(REPLACE(@@sql_mode, 'STRICT_TRANS_TABLES', ''), 'NO_ZERO_DATE', '');
    SET batch_start_time = NOW();
    
    SELECT '>> Starting Final Silver Layer Load...' AS Status;

    -- [Table: silver_crm_cust_info]
    -- Purpose: Cleanse Customer profile data and remove historical duplicates.
    SET start_time = NOW();
    TRUNCATE TABLE silver_crm_cust_info;
    INSERT INTO silver_crm_cust_info (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
    SELECT 
        cst_id, 
        cst_key, 
        TRIM(cst_firstname), -- Handling unwanted spaces
        TRIM(cst_lastname),  -- Handling unwanted spaces
        -- DATA STANDARDIZATION: Mapping abbreviations to full descriptive terms
        CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single' 
             WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married' 
             ELSE 'n/a' END,
        CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female' 
             WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male' 
             ELSE 'n/a' END,
        -- DATA CLEANSING: Converting 'Zero-Dates' to NULL for integrity
        NULLIF(cst_create_date, '0000-00-00')
    FROM (
        -- DEDUPLICATION LOGIC: Use a window function to identify the most 
        -- recent record per customer ID based on the creation date.
        SELECT *, ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze_crm_cust_info WHERE cst_id IS NOT NULL AND cst_id != ''
    ) t WHERE flag_last = 1;

    -- [Table: silver_crm_prd_info]
    -- Purpose: Extract product metadata and compute product life-cycles.
    TRUNCATE TABLE silver_crm_prd_info;
    INSERT INTO silver_crm_prd_info (prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
    SELECT 
        prd_id, 
        -- DATA EXTRACTION: Splitting a composite key ('CAT-ID') into discrete components
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_'), 
        SUBSTRING(prd_key, 7), 
        prd_nm, 
        IFNULL(prd_cost, 0), -- Handling missing data by defaulting to 0
        CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain' 
             WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road' 
             WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales' 
             WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring' 
             ELSE 'n/a' END,
        CAST(NULLIF(prd_start_dt, '0000-00-00') AS DATE),
        -- DATA MODELING: Use LEAD() to find the next start date and subtract one day
        -- to determine the 'Effective End Date' for the current product version.
        DATE_SUB(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt), INTERVAL 1 DAY)
    FROM bronze_crm_prd_info;

    -- [Table: silver_crm_sales_details]
    -- Purpose: Validate financial transactions and fix calculation errors.
    TRUNCATE TABLE silver_crm_sales_details;
    INSERT INTO silver_crm_sales_details (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price)
    SELECT 
        sls_ord_num, 
        sls_prd_key, 
        sls_cust_id,
        -- CASTING DATA TYPES: Converting integer-style dates (20230101) to actual DATE objects
        STR_TO_DATE(NULLIF(CAST(sls_order_dt AS CHAR), '0'), '%Y%m%d'),
        STR_TO_DATE(NULLIF(CAST(sls_ship_dt AS CHAR), '0'), '%Y%m%d'),
        STR_TO_DATE(NULLIF(CAST(sls_due_dt AS CHAR), '0'), '%Y%m%d'),
        -- DATA VALIDATION: If Sales Amount is missing or mathematically impossible, 
        -- we recalculate it as (Quantity * Price) to maintain financial integrity.
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
             THEN sls_quantity * ABS(sls_price) 
             ELSE sls_sales END,
        sls_quantity,
        -- DATA ENRICHMENT: Derive missing unit price by dividing sales by quantity.
        CASE WHEN sls_price IS NULL OR sls_price <= 0 
             THEN sls_sales / NULLIF(sls_quantity, 0) 
             ELSE sls_price END
    FROM bronze_crm_sales_details;

    -- [Table: silver_erp_cust_az12]
    -- Purpose: Cleanse secondary ERP customer data and validate biological dates.
    TRUNCATE TABLE silver_erp_cust_az12;
    INSERT INTO silver_erp_cust_az12 (cid, bdate, gen)
    SELECT
        -- DATA CLEANSING: Removing system-specific prefixes ('NAS') to enable cross-source joins
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4) ELSE cid END, 
        -- DATA VALIDATION: Nullifying future birthdates (impossible data)
        CASE WHEN bdate IS NULL OR bdate = '0000-00-00' OR bdate > NOW() THEN NULL ELSE bdate END,
        CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female' 
             WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male' 
             ELSE 'n/a' END
    FROM bronze_erp_cust_az12;

    -- [Table: silver_erp_loc_a101]
    -- Purpose: Standardize geographic data for unified reporting.
    TRUNCATE TABLE silver_erp_loc_a101;
    INSERT INTO silver_erp_loc_a101 (cid, cntry)
    SELECT 
        REPLACE(cid, '-', ''), -- Normalizing IDs by removing delimiters
        -- DATA STANDARDIZATION: Mapping ISO codes and various spelling to a single standard
        CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany' 
             WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States' 
             WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a' 
             ELSE TRIM(cntry) END
    FROM bronze_erp_loc_a101;
    
    -- [Table: silver_erp_px_cat_g1v2]
    -- Purpose: Direct mapping of Product Categories.
    TRUNCATE TABLE silver_erp_px_cat_g1v2;
    INSERT INTO silver_erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    SELECT id, cat, subcat, maintenance FROM bronze_erp_px_cat_g1v2;

    SET batch_end_time = NOW();
    SELECT '==========================================' AS Message;
    SELECT 'Loading Silver Layer is Completed' AS Status;
    SELECT CONCAT('Total Duration: ', TIMESTAMPDIFF(SECOND, batch_start_time, batch_end_time), ' seconds') AS Total;
    SELECT '==========================================' AS Message;
    
    COMMIT;
END //

DELIMITER ;