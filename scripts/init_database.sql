/*
=============================================================
Create Database
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouse'. 
    If the database exists, it is dropped and recreated. 
    
WARNING:
    Running this script will drop the entire 'DataWarehouse' 
    database. All data will be permanently deleted.
=============================================================
*/

-- If the database exists, it is dropped and recreated. 
DROP DATABASE IF EXISTS DataWarehouse;

-- Create the database
CREATE DATABASE DataWarehouse;

-- Switch to the new database context
USE DataWarehouse;
