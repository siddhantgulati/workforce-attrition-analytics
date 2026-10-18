-- ---------------------------------------------------------------------------
-- 00_load_mysql.sql
-- Creates the staging table and loads the raw CSV into MySQL 8.
--
-- Run from the project root so the relative file path resolves:
--   mysql --local-infile=1 -u root -p < sql/00_load_mysql.sql
-- If you get "Loading local data is disabled", run this once as admin:
--   SET GLOBAL local_infile = 1;
--
-- Not needed when using scripts/run_sql.py, which loads the same staging
-- table into SQLite.
-- ---------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS hr_analytics;
USE hr_analytics;

DROP TABLE IF EXISTS hr_raw;

CREATE TABLE hr_raw (
    Age                      INT,
    Attrition                VARCHAR(3),
    BusinessTravel           VARCHAR(20),
    DailyRate                INT,
    Department               VARCHAR(30),
    DistanceFromHome         INT,
    Education                INT,
    EducationField           VARCHAR(20),
    EmployeeCount            INT,
    EmployeeNumber           INT,
    EnvironmentSatisfaction  INT,
    Gender                   VARCHAR(6),
    HourlyRate               INT,
    JobInvolvement           INT,
    JobLevel                 INT,
    JobRole                  VARCHAR(30),
    JobSatisfaction          INT,
    MaritalStatus            VARCHAR(10),
    MonthlyIncome            INT,
    MonthlyRate              INT,
    NumCompaniesWorked       INT,
    Over18                   CHAR(1),
    OverTime                 VARCHAR(3),
    PercentSalaryHike        INT,
    PerformanceRating        INT,
    RelationshipSatisfaction INT,
    StandardHours            INT,
    StockOptionLevel         INT,
    TotalWorkingYears        INT,
    TrainingTimesLastYear    INT,
    WorkLifeBalance          INT,
    YearsAtCompany           INT,
    YearsInCurrentRole       INT,
    YearsSinceLastPromotion  INT,
    YearsWithCurrManager     INT
);

LOAD DATA LOCAL INFILE 'data/ibm_hr_attrition.csv'
INTO TABLE hr_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

SELECT COUNT(*) AS rows_loaded FROM hr_raw;   -- expect 1470
