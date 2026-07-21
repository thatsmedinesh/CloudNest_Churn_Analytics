SELECT 'plans'         AS table_name, COUNT(*) AS row_count FROM plans
UNION ALL
SELECT 'customers',     COUNT(*) FROM customers
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'payments',      COUNT(*) FROM payments
UNION ALL
SELECT 'churn_events',  COUNT(*) FROM churn_events
ORDER BY table_name;