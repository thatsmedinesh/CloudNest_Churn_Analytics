-- ============================================
-- KPI MASTER QUERY — CloudNest business health
-- ============================================
WITH kpi AS (
    SELECT
        (SELECT COUNT(*) FROM customers)          AS total_customers,
        COUNT(DISTINCT customer_id) FILTER (WHERE status = 'Active')   AS active_customers,
        COUNT(DISTINCT customer_id) FILTER (WHERE status = 'Churned')  AS churned_customers
    FROM subscriptions
),
mrr AS (
    SELECT ROUND(SUM(CASE WHEN s.billing_cycle = 'Monthly'
                          THEN p.monthly_price
                          ELSE p.annual_price / 12.0 END), 0) AS current_mrr
    FROM subscriptions s
    JOIN plans p ON p.plan_id = s.plan_id
    WHERE s.status = 'Active'
),
rev AS (
    SELECT SUM(amount_usd) AS total_revenue
    FROM payments
)
SELECT k.total_customers,
       k.active_customers,
       k.churned_customers,
       ROUND(100.0 * k.churned_customers / k.total_customers, 1) AS churn_rate_pct,
       m.current_mrr,
       r.total_revenue
FROM kpi k, mrr m, rev r;




-- ============================================
-- Query 02: Churn rate by plan
-- ============================================
SELECT p.plan_name,
       COUNT(*) AS customer_count,
       SUM(CASE WHEN s.status = 'Churned' THEN 1 ELSE 0 END) AS churned,
       ROUND(100.0 * SUM(CASE WHEN s.status = 'Churned' THEN 1 ELSE 0 END) / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions s
JOIN plans p ON p.plan_id = s.plan_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY p.plan_name
ORDER BY churn_rate_pct DESC;



-- ============================================
-- Query 03: Churn rate by billing cycle
-- ============================================
SELECT s.billing_cycle,
       COUNT(*) AS customer_count,
       COUNT(*) FILTER (WHERE s.status = 'Churned') AS churned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions s
WHERE s.status IN ('Active', 'Churned')
GROUP BY s.billing_cycle
ORDER BY churn_rate_pct DESC;


-- ============================================
-- Query 04: Churn rate by acquisition channel
-- ============================================
SELECT c.acquisition_channel,
       COUNT(*) AS customer_count,
       COUNT(*) FILTER (WHERE s.status = 'Churned') AS churned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY c.acquisition_channel
ORDER BY churn_rate_pct DESC;




-- ============================================
-- Query 05: Churn rate by region
-- ============================================
SELECT c.region,
       COUNT(*) AS customer_count,
       COUNT(*) FILTER (WHERE s.status = 'Churned') AS churned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY c.region
ORDER BY churn_rate_pct DESC;

-- ============================================
-- Query 06: Churn rate by industry
-- ============================================
SELECT c.industry,
       COUNT(*) AS customer_count,
       COUNT(*) FILTER (WHERE s.status = 'Churned') AS churned,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions s
JOIN customers c ON c.customer_id = s.customer_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY c.industry
ORDER BY churn_rate_pct DESC;



-- ============================================
-- Query 07: MRR by month (18-month trend)
-- ============================================
WITH months AS (
    SELECT date_trunc('month', gs)::date AS month_start,
           (date_trunc('month', gs) + interval '1 month' - interval '1 day')::date AS month_end
    FROM generate_series('2025-01-01'::date, '2026-06-01'::date, interval '1 month') gs
)
SELECT m.month_start AS month,
       COUNT(*) AS active_subs,
       ROUND(SUM(CASE WHEN s.billing_cycle = 'Monthly'
                      THEN p.monthly_price
                      ELSE p.annual_price / 12.0 END), 0) AS mrr
FROM months m
JOIN subscriptions s
     ON s.start_date <= m.month_end
    AND (s.end_date IS NULL OR s.end_date > m.month_end)
JOIN plans p ON p.plan_id = s.plan_id
GROUP BY m.month_start
ORDER BY m.month_start;


-- ============================================
-- Query 08: Revenue by plan + share %
-- ============================================
SELECT p.plan_name,
       SUM(pay.amount_usd) AS total_revenue,
       ROUND(100.0 * SUM(pay.amount_usd) / SUM(SUM(pay.amount_usd)) OVER (), 1) AS revenue_share_pct
FROM payments pay
JOIN subscriptions s ON s.subscription_id = pay.subscription_id
JOIN plans p ON p.plan_id = s.plan_id
GROUP BY p.plan_name
ORDER BY total_revenue DESC;


-- ============================================
-- Query 09: ARPU (Average Revenue Per User)
-- ============================================
SELECT ROUND(SUM(amount_usd) / (SELECT COUNT(*) FROM customers), 0) AS arpu
FROM payments;


-- ============================================
-- Query 10: Avg customer LTV (lifetime revenue) by plan
-- ============================================
WITH customer_revenue AS (
    SELECT s.customer_id,
           SUM(pay.amount_usd) AS lifetime_revenue
    FROM payments pay
    JOIN subscriptions s ON s.subscription_id = pay.subscription_id
    GROUP BY s.customer_id
)
SELECT p.plan_name,
       ROUND(AVG(cr.lifetime_revenue), 2) AS avg_ltv
FROM subscriptions s
JOIN plans p ON p.plan_id = s.plan_id
JOIN customer_revenue cr ON cr.customer_id = s.customer_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY p.plan_name
ORDER BY avg_ltv DESC;


-- ============================================
-- Query 11: Revenue by region
-- ============================================
SELECT c.region,
       SUM(pay.amount_usd) AS total_revenue
FROM payments pay
JOIN subscriptions s ON s.subscription_id = pay.subscription_id
JOIN customers c ON c.customer_id = s.customer_id
GROUP BY c.region
ORDER BY total_revenue DESC;


-- ============================================
-- Query 12: Cohort retention analysis
-- (signup month cohorts, retention at 1/3/6/12 months)
-- ============================================
WITH customer_churn AS (
    SELECT s.customer_id,
           MIN(ce.churn_date) AS churn_date
    FROM churn_events ce
    JOIN subscriptions s ON s.subscription_id = ce.subscription_id
    GROUP BY s.customer_id
),
base AS (
    SELECT c.customer_id,
           date_trunc('month', c.signup_date)::date AS cohort_month,
           c.signup_date,
           cc.churn_date
    FROM customers c
    LEFT JOIN customer_churn cc ON cc.customer_id = c.customer_id
)
SELECT to_char(cohort_month, 'YYYY-MM') AS cohort,
       COUNT(*) AS cohort_size,
       ROUND(CASE WHEN cohort_month + interval '1 month'  < '2026-07-01'
             THEN 100.0 * COUNT(*) FILTER (WHERE churn_date IS NULL OR churn_date >= signup_date + interval '1 month')  / COUNT(*) END, 1) AS m1_pct,
       ROUND(CASE WHEN cohort_month + interval '3 month'  < '2026-07-01'
             THEN 100.0 * COUNT(*) FILTER (WHERE churn_date IS NULL OR churn_date >= signup_date + interval '3 month')  / COUNT(*) END, 1) AS m3_pct,
       ROUND(CASE WHEN cohort_month + interval '6 month'  < '2026-07-01'
             THEN 100.0 * COUNT(*) FILTER (WHERE churn_date IS NULL OR churn_date >= signup_date + interval '6 month')  / COUNT(*) END, 1) AS m6_pct,
       ROUND(CASE WHEN cohort_month + interval '12 month' < '2026-07-01'
             THEN 100.0 * COUNT(*) FILTER (WHERE churn_date IS NULL OR churn_date >= signup_date + interval '12 month') / COUNT(*) END, 1) AS m12_pct
FROM base
GROUP BY cohort_month
ORDER BY cohort_month;



-- ============================================
-- Query 13: Churn reasons breakdown
-- ============================================
SELECT ce.churn_reason,
       COUNT(*) AS churn_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM churn_events ce
GROUP BY ce.churn_reason
ORDER BY churn_count DESC;



-- ============================================
-- Query 14: Pro plan deep-dive — why do Pro customers leave?
-- ============================================
SELECT ce.churn_reason,
       COUNT(*) AS churn_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM churn_events ce
JOIN subscriptions s ON s.subscription_id = ce.subscription_id
JOIN plans p ON p.plan_id = s.plan_id
WHERE p.plan_name = 'Pro'
GROUP BY ce.churn_reason
ORDER BY churn_count DESC;


-- ============================================
-- Query 15: 'Too Expensive' concentration by plan
-- ============================================
SELECT p.plan_name,
       COUNT(*) AS too_expensive_count
FROM churn_events ce
JOIN subscriptions s ON s.subscription_id = ce.subscription_id
JOIN plans p ON p.plan_id = s.plan_id
WHERE ce.churn_reason = 'Too Expensive'
GROUP BY p.plan_name
ORDER BY too_expensive_count DESC;




-- ============================================
-- Query 16: Reusable views for BI layer
-- ============================================
CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT COUNT(DISTINCT c.customer_id)                                          AS total_customers,
       COUNT(DISTINCT c.customer_id) FILTER (WHERE s.status = 'Active')      AS active_customers,
       COUNT(DISTINCT c.customer_id) FILTER (WHERE s.status = 'Churned')     AS churned_customers,
       ROUND(100.0 * COUNT(DISTINCT c.customer_id) FILTER (WHERE s.status = 'Churned')
             / COUNT(DISTINCT c.customer_id), 1)                             AS churn_rate_pct
FROM customers c
JOIN subscriptions s ON s.customer_id = c.customer_id
WHERE s.status IN ('Active', 'Churned');

CREATE OR REPLACE VIEW vw_churn_by_segment AS
SELECT 'Plan' AS segment_type, p.plan_name AS segment_value,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1) AS churn_rate_pct
FROM subscriptions s JOIN plans p ON p.plan_id = s.plan_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY p.plan_name
UNION ALL
SELECT 'Billing Cycle', s.billing_cycle, COUNT(*),
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1)
FROM subscriptions s
WHERE s.status IN ('Active', 'Churned')
GROUP BY s.billing_cycle
UNION ALL
SELECT 'Channel', c.acquisition_channel, COUNT(*),
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1)
FROM subscriptions s JOIN customers c ON c.customer_id = s.customer_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY c.acquisition_channel
UNION ALL
SELECT 'Region', c.region, COUNT(*),
       ROUND(100.0 * COUNT(*) FILTER (WHERE s.status = 'Churned') / COUNT(*), 1)
FROM subscriptions s JOIN customers c ON c.customer_id = s.customer_id
WHERE s.status IN ('Active', 'Churned')
GROUP BY c.region;



-- ============================================
-- Query 17: Top 10 customers by lifetime revenue (DENSE_RANK)
-- ============================================
WITH customer_ltv AS (
    SELECT s.customer_id,
           SUM(pay.amount_usd) AS lifetime_revenue
    FROM payments pay
    JOIN subscriptions s ON s.subscription_id = pay.subscription_id
    GROUP BY s.customer_id
)
SELECT DENSE_RANK() OVER (ORDER BY cl.lifetime_revenue DESC) AS ltv_rank,
       c.company_name,
       c.region,
       cl.lifetime_revenue
FROM customer_ltv cl
JOIN customers c ON c.customer_id = cl.customer_id
ORDER BY cl.lifetime_revenue DESC, c.company_name
LIMIT 10;


-- ============================================
-- Query 18: Monthly revenue + running total
-- ============================================
SELECT to_char(date_trunc('month', payment_date), 'YYYY-MM') AS month,
       SUM(amount_usd) AS monthly_revenue,
       SUM(SUM(amount_usd)) OVER (ORDER BY date_trunc('month', payment_date)) AS running_total
FROM payments
GROUP BY date_trunc('month', payment_date)
ORDER BY month;


SELECT * FROM vw_churn_by_segment;




SELECT * FROM vw_kpi_summary;
