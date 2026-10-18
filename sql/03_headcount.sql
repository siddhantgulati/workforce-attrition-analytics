-- ---------------------------------------------------------------------------
-- 03_headcount.sql
-- Workforce profile: who works here. Headcount counts everyone in the data
-- set (current employees and leavers); "active" excludes leavers.
-- ---------------------------------------------------------------------------

-- name: headcount_by_department
SELECT d.department_name,
       COUNT(*)                                             AS headcount,
       SUM(CASE WHEN e.attrition = 'No' THEN 1 ELSE 0 END)  AS active,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_of_total,
       ROUND(AVG(e.monthly_income), 0)                      AS avg_monthly_income,
       ROUND(AVG(e.years_at_company), 1)                    AS avg_tenure_years
FROM employees e
JOIN job_roles jr  ON jr.job_role_id = e.job_role_id
JOIN departments d ON d.department_id = jr.department_id
GROUP BY d.department_name
ORDER BY headcount DESC;

-- name: headcount_by_role
SELECT d.department_name,
       jr.job_role_name,
       COUNT(*) AS headcount,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY d.department_name), 1) AS pct_of_department
FROM employees e
JOIN job_roles jr  ON jr.job_role_id = e.job_role_id
JOIN departments d ON d.department_id = jr.department_id
GROUP BY d.department_name, jr.job_role_name
ORDER BY d.department_name, headcount DESC;

-- name: headcount_by_level
SELECT job_level,
       COUNT(*) AS headcount,
       ROUND(AVG(monthly_income), 0) AS avg_monthly_income,
       MIN(monthly_income) AS min_income,
       MAX(monthly_income) AS max_income
FROM employees
GROUP BY job_level
ORDER BY job_level;

-- name: gender_mix_by_department
SELECT d.department_name,
       SUM(CASE WHEN e.gender = 'Female' THEN 1 ELSE 0 END) AS female,
       SUM(CASE WHEN e.gender = 'Male' THEN 1 ELSE 0 END)   AS male,
       ROUND(100.0 * SUM(CASE WHEN e.gender = 'Female' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_female
FROM employees e
JOIN job_roles jr  ON jr.job_role_id = e.job_role_id
JOIN departments d ON d.department_id = jr.department_id
GROUP BY d.department_name
ORDER BY d.department_name;
