-- ---------------------------------------------------------------------------
-- 04_attrition_drivers.sql
-- Attrition rate = leavers / headcount for each group.
-- Bands for tenure, age and income are defined once in a CTE so every query
-- uses the same cut-offs.
-- ---------------------------------------------------------------------------

-- name: overall_attrition
SELECT COUNT(*) AS headcount,
       SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM employees;

-- name: attrition_by_department
SELECT d.department_name,
       COUNT(*) AS headcount,
       SUM(CASE WHEN e.attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN e.attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM employees e
JOIN job_roles jr  ON jr.job_role_id = e.job_role_id
JOIN departments d ON d.department_id = jr.department_id
GROUP BY d.department_name
ORDER BY attrition_pct DESC;

-- name: attrition_by_role_ranked
WITH role_stats AS (
    SELECT jr.job_role_name,
           COUNT(*) AS headcount,
           SUM(CASE WHEN e.attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers
    FROM employees e
    JOIN job_roles jr ON jr.job_role_id = e.job_role_id
    GROUP BY jr.job_role_name
)
SELECT job_role_name,
       headcount,
       leavers,
       ROUND(100.0 * leavers / headcount, 1) AS attrition_pct,
       RANK() OVER (ORDER BY 1.0 * leavers / headcount DESC) AS risk_rank,
       ROUND(100.0 * leavers / SUM(leavers) OVER (), 1) AS pct_of_all_leavers
FROM role_stats
ORDER BY risk_rank;

-- name: attrition_overtime_by_department
SELECT d.department_name,
       e.overtime,
       COUNT(*) AS headcount,
       ROUND(100.0 * SUM(CASE WHEN e.attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM employees e
JOIN job_roles jr  ON jr.job_role_id = e.job_role_id
JOIN departments d ON d.department_id = jr.department_id
GROUP BY d.department_name, e.overtime
ORDER BY d.department_name, e.overtime;

-- name: attrition_by_band
WITH banded AS (
    SELECT attrition,
           CASE WHEN years_at_company <= 1 THEN '1. 0-1 yrs'
                WHEN years_at_company <= 3 THEN '2. 2-3 yrs'
                WHEN years_at_company <= 5 THEN '3. 4-5 yrs'
                WHEN years_at_company <= 10 THEN '4. 6-10 yrs'
                ELSE '5. 10+ yrs' END AS tenure_band,
           CASE WHEN age <= 25 THEN '1. 18-25'
                WHEN age <= 35 THEN '2. 26-35'
                WHEN age <= 45 THEN '3. 36-45'
                ELSE '4. 46-60' END AS age_band,
           CASE WHEN monthly_income < 2500 THEN '1. under 2.5k'
                WHEN monthly_income < 5000 THEN '2. 2.5k-5k'
                WHEN monthly_income < 10000 THEN '3. 5k-10k'
                ELSE '4. 10k+' END AS income_band
    FROM employees
),
long_form AS (
    SELECT 'Tenure' AS dimension, tenure_band AS band, attrition FROM banded
    UNION ALL
    SELECT 'Age', age_band, attrition FROM banded
    UNION ALL
    SELECT 'Monthly income', income_band, attrition FROM banded
)
SELECT dimension,
       band,
       COUNT(*) AS headcount,
       ROUND(100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM long_form
GROUP BY dimension, band
ORDER BY dimension, band;

-- name: attrition_by_work_factor
WITH factors AS (
    SELECT 'Overtime' AS factor, overtime AS value, attrition FROM employees
    UNION ALL
    SELECT 'Business travel', business_travel, attrition FROM employees
    UNION ALL
    SELECT 'Marital status', marital_status, attrition FROM employees
    UNION ALL
    SELECT 'Job level', CAST(job_level AS CHAR(2)), attrition FROM employees
    UNION ALL
    SELECT 'Stock option level', CAST(stock_option_level AS CHAR(2)), attrition FROM employees
)
SELECT factor,
       value,
       COUNT(*) AS headcount,
       ROUND(100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM factors
GROUP BY factor, value
ORDER BY factor, value;

-- name: attrition_by_survey_score
WITH scores AS (
    SELECT 'Job satisfaction' AS measure, s.job_satisfaction AS score, e.attrition
    FROM employees e JOIN engagement_survey s ON s.employee_id = e.employee_id
    UNION ALL
    SELECT 'Environment satisfaction', s.environment_satisfaction, e.attrition
    FROM employees e JOIN engagement_survey s ON s.employee_id = e.employee_id
    UNION ALL
    SELECT 'Work-life balance', s.work_life_balance, e.attrition
    FROM employees e JOIN engagement_survey s ON s.employee_id = e.employee_id
    UNION ALL
    SELECT 'Job involvement', s.job_involvement, e.attrition
    FROM employees e JOIN engagement_survey s ON s.employee_id = e.employee_id
)
SELECT measure,
       score,
       COUNT(*) AS headcount,
       ROUND(100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM scores
GROUP BY measure, score
ORDER BY measure, score;

-- name: leavers_vs_stayers
SELECT attrition,
       COUNT(*) AS employees,
       ROUND(AVG(monthly_income), 0)             AS avg_monthly_income,
       ROUND(AVG(age), 1)                        AS avg_age,
       ROUND(AVG(years_at_company), 1)           AS avg_tenure,
       ROUND(AVG(total_working_years), 1)        AS avg_experience,
       ROUND(AVG(distance_from_home), 1)         AS avg_distance_km,
       ROUND(AVG(years_since_last_promotion), 1) AS avg_yrs_since_promotion
FROM employees
GROUP BY attrition;
