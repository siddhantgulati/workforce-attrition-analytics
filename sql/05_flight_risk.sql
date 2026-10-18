-- ---------------------------------------------------------------------------
-- 05_flight_risk.sql
-- A simple, explainable flight-risk score. Each employee gets one point for
-- each of the seven factors below. On its own, each factor is linked to at
-- least 1.5x the attrition rate of the rest of the workforce
-- (see 04_attrition_drivers.sql).
--
--   overtime = Yes             job level = 1          tenure <= 2 years
--   single                     no stock options       travels frequently
--   job or environment satisfaction = 1 (lowest)
--
-- A score of 4 or more is treated as high risk. The score is checked against
-- people who actually left (backtest), then applied to current employees to
-- give HR a watch list.
-- ---------------------------------------------------------------------------

DROP VIEW IF EXISTS employee_risk;

CREATE VIEW employee_risk AS
SELECT e.employee_id,
       d.department_name,
       jr.job_role_name,
       e.job_level,
       e.years_at_company,
       e.overtime,
       e.attrition,
       CASE WHEN e.overtime = 'Yes' THEN 1 ELSE 0 END                         AS f_overtime,
       CASE WHEN e.job_level = 1 THEN 1 ELSE 0 END                            AS f_entry_level,
       CASE WHEN e.years_at_company <= 2 THEN 1 ELSE 0 END                    AS f_new_joiner,
       CASE WHEN e.marital_status = 'Single' THEN 1 ELSE 0 END                AS f_single,
       CASE WHEN e.stock_option_level = 0 THEN 1 ELSE 0 END                   AS f_no_stock,
       CASE WHEN e.business_travel = 'Travel_Frequently' THEN 1 ELSE 0 END    AS f_frequent_travel,
       CASE WHEN s.job_satisfaction = 1 OR s.environment_satisfaction = 1
            THEN 1 ELSE 0 END                                                 AS f_low_satisfaction
FROM employees e
JOIN engagement_survey s ON s.employee_id = e.employee_id
JOIN job_roles jr        ON jr.job_role_id = e.job_role_id
JOIN departments d       ON d.department_id = jr.department_id;

-- name: factor_check
-- How much more likely to leave is someone with each factor?
WITH f AS (
    SELECT 'Overtime' AS factor, f_overtime AS flag, attrition FROM employee_risk
    UNION ALL SELECT 'Job level 1', f_entry_level, attrition FROM employee_risk
    UNION ALL SELECT 'Tenure 2 years or less', f_new_joiner, attrition FROM employee_risk
    UNION ALL SELECT 'Single', f_single, attrition FROM employee_risk
    UNION ALL SELECT 'No stock options', f_no_stock, attrition FROM employee_risk
    UNION ALL SELECT 'Travels frequently', f_frequent_travel, attrition FROM employee_risk
    UNION ALL SELECT 'Lowest job or environment satisfaction', f_low_satisfaction, attrition FROM employee_risk
),
rates AS (
    SELECT factor,
           SUM(flag) AS employees_with_factor,
           100.0 * SUM(CASE WHEN flag = 1 AND attrition = 'Yes' THEN 1 ELSE 0 END) / SUM(flag) AS pct_with,
           100.0 * SUM(CASE WHEN flag = 0 AND attrition = 'Yes' THEN 1 ELSE 0 END) / SUM(1 - flag) AS pct_without
    FROM f
    GROUP BY factor
)
SELECT factor,
       employees_with_factor,
       ROUND(pct_with, 1)               AS attrition_pct_with,
       ROUND(pct_without, 1)            AS attrition_pct_without,
       ROUND(pct_with / pct_without, 1) AS times_more_likely
FROM rates
ORDER BY times_more_likely DESC;

-- name: risk_score_backtest
WITH scored AS (
    SELECT attrition,
           f_overtime + f_entry_level + f_new_joiner + f_single
         + f_no_stock + f_frequent_travel + f_low_satisfaction AS risk_score
    FROM employee_risk
)
SELECT risk_score,
       COUNT(*) AS headcount,
       SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct
FROM scored
GROUP BY risk_score
ORDER BY risk_score;

-- name: high_risk_vs_rest
WITH scored AS (
    SELECT attrition,
           CASE WHEN f_overtime + f_entry_level + f_new_joiner + f_single
                   + f_no_stock + f_frequent_travel + f_low_satisfaction >= 4
                THEN 'High (4+)' ELSE 'Low / medium (0-3)' END AS risk_group
    FROM employee_risk
)
SELECT risk_group,
       COUNT(*) AS headcount,
       SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) AS leavers,
       ROUND(100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS attrition_pct,
       ROUND(100.0 * SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END)
             / SUM(SUM(CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END)) OVER (), 1) AS pct_of_all_leavers
FROM scored
GROUP BY risk_group
ORDER BY risk_group;

-- name: watchlist_by_department_role
WITH scored AS (
    SELECT department_name,
           job_role_name,
           f_overtime + f_entry_level + f_new_joiner + f_single
         + f_no_stock + f_frequent_travel + f_low_satisfaction AS risk_score
    FROM employee_risk
    WHERE attrition = 'No'
)
SELECT department_name,
       job_role_name,
       COUNT(*) AS active_employees,
       SUM(CASE WHEN risk_score >= 4 THEN 1 ELSE 0 END) AS high_risk,
       ROUND(100.0 * SUM(CASE WHEN risk_score >= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_high_risk
FROM scored
GROUP BY department_name, job_role_name
HAVING SUM(CASE WHEN risk_score >= 4 THEN 1 ELSE 0 END) > 0
ORDER BY high_risk DESC, pct_high_risk DESC;

-- name: watchlist_employees
WITH scored AS (
    SELECT employee_id, department_name, job_role_name, job_level,
           years_at_company, overtime,
           f_overtime + f_entry_level + f_new_joiner + f_single
         + f_no_stock + f_frequent_travel + f_low_satisfaction AS risk_score
    FROM employee_risk
    WHERE attrition = 'No'
)
SELECT employee_id, department_name, job_role_name, job_level,
       years_at_company, overtime, risk_score,
       ROW_NUMBER() OVER (PARTITION BY department_name
                          ORDER BY risk_score DESC, years_at_company, employee_id) AS priority_in_department
FROM scored
WHERE risk_score >= 4
ORDER BY department_name, priority_in_department;
