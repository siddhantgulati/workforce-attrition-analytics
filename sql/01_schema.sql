-- ---------------------------------------------------------------------------
-- 01_schema.sql
-- Splits the flat staging table into a small relational model:
--
--   departments 1---* job_roles 1---* employees 1---1 engagement_survey
--
-- EmployeeCount, StandardHours and Over18 have a single value for every row
-- (1, 80 and 'Y'), so they carry no information and are left out.
-- DailyRate, HourlyRate and MonthlyRate don't reconcile with MonthlyIncome in
-- this data set, so only MonthlyIncome is kept as the pay measure.
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS engagement_survey;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS job_roles;
DROP TABLE IF EXISTS departments;

CREATE TABLE departments (
    department_id   INT PRIMARY KEY,
    department_name VARCHAR(30) NOT NULL
);

CREATE TABLE job_roles (
    job_role_id   INT PRIMARY KEY,
    job_role_name VARCHAR(30) NOT NULL,
    department_id INT NOT NULL,
    FOREIGN KEY (department_id) REFERENCES departments (department_id)
);

CREATE TABLE employees (
    employee_id                INT PRIMARY KEY,
    job_role_id                INT NOT NULL,
    age                        INT,
    gender                     VARCHAR(6),
    marital_status             VARCHAR(10),
    education_level            INT,          -- 1 Below College ... 5 Doctor
    education_field            VARCHAR(20),
    job_level                  INT,          -- 1 (entry) to 5 (senior)
    monthly_income             INT,
    overtime                   VARCHAR(3),
    business_travel            VARCHAR(20),
    distance_from_home         INT,
    total_working_years        INT,
    num_companies_worked       INT,
    years_at_company           INT,
    years_in_current_role      INT,
    years_since_last_promotion INT,
    years_with_curr_manager    INT,
    stock_option_level         INT,
    percent_salary_hike        INT,
    performance_rating         INT,
    training_times_last_year   INT,
    attrition                  VARCHAR(3),   -- 'Yes' = left the company
    FOREIGN KEY (job_role_id) REFERENCES job_roles (job_role_id)
);

-- Survey scores are 1 (low) to 4 (high)
CREATE TABLE engagement_survey (
    employee_id               INT PRIMARY KEY,
    job_satisfaction          INT,
    environment_satisfaction  INT,
    relationship_satisfaction INT,
    work_life_balance         INT,
    job_involvement           INT,
    FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
);

INSERT INTO departments (department_id, department_name)
SELECT ROW_NUMBER() OVER (ORDER BY Department), Department
FROM (SELECT DISTINCT Department FROM hr_raw) d;

-- A role name can sit in more than one department (e.g. Manager),
-- so a job role is the combination of role and department
INSERT INTO job_roles (job_role_id, job_role_name, department_id)
SELECT ROW_NUMBER() OVER (ORDER BY d.department_name, r.JobRole),
       r.JobRole,
       d.department_id
FROM (SELECT DISTINCT JobRole, Department FROM hr_raw) r
JOIN departments d ON d.department_name = r.Department;

INSERT INTO employees
SELECT h.EmployeeNumber, jr.job_role_id, h.Age, h.Gender, h.MaritalStatus,
       h.Education, h.EducationField, h.JobLevel, h.MonthlyIncome, h.OverTime,
       h.BusinessTravel, h.DistanceFromHome, h.TotalWorkingYears,
       h.NumCompaniesWorked, h.YearsAtCompany, h.YearsInCurrentRole,
       h.YearsSinceLastPromotion, h.YearsWithCurrManager, h.StockOptionLevel,
       h.PercentSalaryHike, h.PerformanceRating, h.TrainingTimesLastYear,
       h.Attrition
FROM hr_raw h
JOIN departments d ON d.department_name = h.Department
JOIN job_roles jr  ON jr.job_role_name = h.JobRole
                  AND jr.department_id = d.department_id;

INSERT INTO engagement_survey
SELECT EmployeeNumber, JobSatisfaction, EnvironmentSatisfaction,
       RelationshipSatisfaction, WorkLifeBalance, JobInvolvement
FROM hr_raw;

-- name: table_row_counts
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL SELECT 'job_roles', COUNT(*) FROM job_roles
UNION ALL SELECT 'employees', COUNT(*) FROM employees
UNION ALL SELECT 'engagement_survey', COUNT(*) FROM engagement_survey;
