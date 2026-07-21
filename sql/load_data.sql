COPY plans          FROM 'C:/cloudnest_data/plans.csv'          WITH (FORMAT csv, HEADER true);
COPY customers      FROM 'C:/cloudnest_data/customers.csv'      WITH (FORMAT csv, HEADER true);
COPY subscriptions  FROM 'C:/cloudnest_data/subscriptions.csv'  WITH (FORMAT csv, HEADER true, NULL '');
COPY payments       FROM 'C:/cloudnest_data/payments.csv'       WITH (FORMAT csv, HEADER true);
COPY churn_events   FROM 'C:/cloudnest_data/churn_events.csv'   WITH (FORMAT csv, HEADER true);