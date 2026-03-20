/*
===============================================================================
Master Script: Load Bronze Layer
===============================================================================
Script Purpose:
    This script loads data into the flattened bronze tables from CSV files.
    - Truncates tables before loading to ensure no duplicate data.
    - Uses 'LOAD DATA LOCAL INFILE' for high-speed ingestion.
===============================================================================
*/

-- ----------------------------------------------------------------------------
-- 1. Setup Environment
-- ----------------------------------------------------------------------------
SET GLOBAL local_infile = 1;
USE DataWarehouse;

-- ----------------------------------------------------------------------------
-- 2. CRM Tables Ingestion
-- ----------------------------------------------------------------------------
SELECT '>> Starting CRM Tables Ingestion...' AS Log;

-- Table: bronze_crm_cust_info
SELECT '>> Loading: bronze_crm_cust_info' AS Status;
TRUNCATE TABLE bronze_crm_cust_info;
LOAD DATA LOCAL INFILE '/Users/ethanroelf/Desktop/sql-data-warehouse-project/datasets/source_crm/cust_info.csv'
INTO TABLE bronze_crm_cust_info
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Table: bronze_crm_prd_info
SELECT '>> Loading: bronze_crm_prd_info' AS Status;
TRUNCATE TABLE bronze_crm_prd_info;
LOAD DATA LOCAL INFILE '/Users/ethanroelf/Desktop/sql-data-warehouse-project/datasets/source_crm/prd_info.csv'
INTO TABLE bronze_crm_prd_info
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Table: bronze_crm_sales_details
SELECT '>> Loading: bronze_crm_sales_details' AS Status;
TRUNCATE TABLE bronze_crm_sales_details;
LOAD DATA LOCAL INFILE '/Users/ethanroelf/Desktop/sql-data-warehouse-project/datasets/source_crm/sales_details.csv'
INTO TABLE bronze_crm_sales_details
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- ----------------------------------------------------------------------------
-- 3. ERP Tables Ingestion
-- ----------------------------------------------------------------------------
SELECT '>> Starting ERP Tables Ingestion...' AS Log;

-- Table: bronze_erp_loc_a101
SELECT '>> Loading: bronze_erp_loc_a101' AS Status;
TRUNCATE TABLE bronze_erp_loc_a101;
LOAD DATA LOCAL INFILE '/Users/ethanroelf/Desktop/sql-data-warehouse-project/datasets/source_erp/LOC_A101.csv'
INTO TABLE bronze_erp_loc_a101
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Table: bronze_erp_cust_az12
SELECT '>> Loading: bronze_erp_cust_az12' AS Status;
TRUNCATE TABLE bronze_erp_cust_az12;
LOAD DATA LOCAL INFILE '/Users/ethanroelf/Desktop/sql-data-warehouse-project/datasets/source_erp/CUST_AZ12.csv'
INTO TABLE bronze_erp_cust_az12
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Table: bronze_erp_px_cat_g1v2
SELECT '>> Loading: bronze_erp_px_cat_g1v2' AS Status;
TRUNCATE TABLE bronze_erp_px_cat_g1v2;
LOAD DATA LOCAL INFILE '/Users/ethanroelf/Desktop/sql-data-warehouse-project/datasets/source_erp/PX_CAT_G1V2.csv'
INTO TABLE bronze_erp_px_cat_g1v2
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- ----------------------------------------------------------------------------
-- 4. Final Verification
-- ----------------------------------------------------------------------------
SELECT '==========================================' AS Message;
SELECT 'Bronze Layer Load Complete!' AS Status;
SELECT '==========================================' AS Message;

-- Check record counts to ensure data was actually loaded
SELECT 'Record Counts:' AS Info;
SELECT 'crm_cust_info' AS tbl, COUNT(*) FROM bronze_crm_cust_info
UNION ALL
SELECT 'crm_prd_info', COUNT(*) FROM bronze_crm_prd_info
UNION ALL
SELECT 'crm_sales_details', COUNT(*) FROM bronze_crm_sales_details
UNION ALL
SELECT 'erp_loc_a101', COUNT(*) FROM bronze_erp_loc_a101
UNION ALL
SELECT 'erp_cust_az12', COUNT(*) FROM bronze_erp_cust_az12
UNION ALL
SELECT 'erp_px_cat_g1v2', COUNT(*) FROM bronze_erp_px_cat_g1v2;