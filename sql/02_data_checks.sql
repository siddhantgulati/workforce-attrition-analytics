-- ---------------------------------------------------------------------------
-- 02_data_checks.sql
-- Basic quality checks before any analysis. Every check should return the
-- value shown in the comment. Anything else means the load went wrong.
-- ---------------------------------------------------------------------------

-- name: check_summary
SELECT 'staging rows' AS check_name, COUNT(*) AS result, '1470' AS expected FROM hr_raw
UNION ALL
SELECT 'employees loaded', COUNT(*), '1470' FROM employees
UNION ALL
SELECT 'duplicate employee ids', COUNT(*) - COUNT(DISTINCT EmployeeNumber), '0' FROM hr_raw
UNION ALL
SELECT 'employees without a job role',
       COUNT(*), '0'
FROM employees e LEFT JOIN job_roles jr ON jr.job_role_id = e.job_role_id
WHERE jr.job_role_id IS NULL
UNION ALL
SELECT 'employees without survey', COUNT(*), '0'
FROM employees e LEFT JOIN engagement_survey s ON s.employee_id = e.employee_id
WHERE s.employee_id IS NULL
UNION ALL
SELECT 'missing income, age or attrition', COUNT(*), '0'
FROM employees
WHERE monthly_income IS NULL OR age IS NULL OR attrition IS NULL
UNION ALL
SELECT 'attrition values other than Yes/No', COUNT(*), '0'
FROM employees WHERE attrition NOT IN ('Yes', 'No')
UNION ALL
SELECT 'survey scores outside 1-4', COUNT(*), '0'
FROM engagement_survey
WHERE job_satisfaction NOT BETWEEN 1 AND 4
   OR environment_satisfaction NOT BETWEEN 1 AND 4
   OR work_life_balance NOT BETWEEN 1 AND 4
   OR job_involvement NOT BETWEEN 1 AND 4
UNION ALL
SELECT 'years at company > total working years', COUNT(*), '0'
FROM employees WHERE years_at_company > total_working_years
UNION ALL
SELECT 'distinct EmployeeCount values', COUNT(DISTINCT EmployeeCount), '1 (dropped)' FROM hr_raw
UNION ALL
SELECT 'distinct StandardHours values', COUNT(DISTINCT StandardHours), '1 (dropped)' FROM hr_raw
UNION ALL
SELECT 'distinct Over18 values', COUNT(DISTINCT Over18), '1 (dropped)' FROM hr_raw;

-- name: value_ranges
SELECT MIN(age) AS min_age, MAX(age) AS max_age,
       MIN(monthly_income) AS min_income, MAX(monthly_income) AS max_income,
       MIN(years_at_company) AS min_tenure, MAX(years_at_company) AS max_tenure
FROM employees;
