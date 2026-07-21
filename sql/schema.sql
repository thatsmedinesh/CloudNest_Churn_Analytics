-- ============================================================
-- CloudNest — SaaS Subscription & Churn Analytics
-- schema.sql — Database schema (PostgreSQL)
-- 5 tables: plans, customers, subscriptions, payments, churn_events
-- Run this in the `cloudnest` database BEFORE loading any CSVs.
-- ============================================================

-- Drop in reverse dependency order
DROP TABLE IF EXISTS churn_events;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS plans;

-- 1. Subscription plans (reference table)
CREATE TABLE plans (
    plan_id        INT PRIMARY KEY,
    plan_name      VARCHAR(20)  NOT NULL UNIQUE,
    monthly_price  NUMERIC(8,2) NOT NULL CHECK (monthly_price > 0),
    annual_price   NUMERIC(8,2) NOT NULL CHECK (annual_price > 0)
);

-- 2. Customers (one row per company)
CREATE TABLE customers (
    customer_id          VARCHAR(10) PRIMARY KEY,
    company_name         VARCHAR(100) NOT NULL,
    industry             VARCHAR(50)  NOT NULL,
    company_size         VARCHAR(10)  NOT NULL,
    city                 VARCHAR(50)  NOT NULL,
    state                CHAR(2)      NOT NULL,
    region               VARCHAR(10)  NOT NULL
        CHECK (region IN ('West', 'East', 'South', 'Midwest')),
    signup_date          DATE         NOT NULL,
    acquisition_channel  VARCHAR(20)  NOT NULL
);

-- 3. Subscriptions (fact table — one row per subscription period)
--    status: 'Active'  = currently running (end_date is NULL)
--            'Churned' = customer cancelled (end_date = churn date)
--            'Upgraded'= replaced by a higher-plan subscription


CREATE TABLE subscriptions (
    subscription_id  VARCHAR(10) PRIMARY KEY,
    customer_id      VARCHAR(10) NOT NULL REFERENCES customers (customer_id),
    plan_id          INT         NOT NULL REFERENCES plans (plan_id),
    billing_cycle    VARCHAR(10) NOT NULL
        CHECK (billing_cycle IN ('Monthly', 'Annual')),
    start_date       DATE        NOT NULL,
    end_date         DATE,
    status           VARCHAR(10) NOT NULL
        CHECK (status IN ('Active', 'Churned', 'Upgraded')),
    CHECK (end_date IS NULL OR end_date >= start_date)
);

-- 4. Payments (one row per successful charge)

CREATE TABLE payments (
    payment_id       VARCHAR(10)  PRIMARY KEY,
    subscription_id  VARCHAR(10)  NOT NULL REFERENCES subscriptions (subscription_id),
    payment_date     DATE         NOT NULL,
    amount_usd       NUMERIC(10,2) NOT NULL CHECK (amount_usd > 0),
    payment_method   VARCHAR(20)  NOT NULL
        CHECK (payment_method IN ('Card', 'PayPal', 'Apple Pay', 'Bank Transfer'))
);

-- 5. Churn events (one row per cancellation, with reason)

CREATE TABLE churn_events (
    churn_id         VARCHAR(10) PRIMARY KEY,
    subscription_id  VARCHAR(10) NOT NULL UNIQUE REFERENCES subscriptions (subscription_id),
    churn_date       DATE        NOT NULL,
    churn_reason     VARCHAR(30) NOT NULL
        CHECK (churn_reason IN ('Too Expensive', 'Missing Features',
                                'Switched to Competitor', 'Poor Support',
                                'Business Closed'))
);

-- indexes for analysis joins

CREATE INDEX idx_subscriptions_customer ON subscriptions (customer_id);
CREATE INDEX idx_subscriptions_plan     ON subscriptions (plan_id);
CREATE INDEX idx_payments_subscription  ON payments (subscription_id);
CREATE INDEX idx_payments_date          ON payments (payment_date);
CREATE INDEX idx_churn_events_sub       ON churn_events (subscription_id);
