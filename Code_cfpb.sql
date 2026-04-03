-- CREATE TABLE `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw AS
-- SELECT *
-- FROM `bigquery-public-data.cfpb_complaints.complaint_database`;

SELECT COUNT(*) AS total_rows
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw;

-- Monthly Complaint Volume Trends
SELECT 
  FORMAT_DATE('%Y-%m', DATE(date_received)) AS complaint_month,
  COUNT(*) AS total_complaints
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw
WHERE date_received IS NOT NULL
GROUP BY complaint_month
ORDER BY complaint_month;

-- Resolution Rate by Company (Top 20)
SELECT 
  company_name,
  COUNT(*) AS total_complaints,
  ROUND(COUNTIF(timely_response = TRUE) * 100.0 / COUNT(*), 2) AS timely_response_pct,
  ROUND(COUNTIF(consumer_disputed = TRUE) * 100.0 / COUNT(*), 2) AS dispute_rate_pct
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw
WHERE company_name IS NOT NULL
GROUP BY company_name
HAVING total_complaints > 1000
ORDER BY total_complaints DESC
LIMIT 20;

-- Top Products by Complaint Volume
SELECT 
  product,
  COUNT(*) AS total_complaints,
  ROUND(COUNTIF(timely_response = TRUE) * 100.0 / COUNT(*), 2) AS timely_response_pct,
  ROUND(COUNTIF(consumer_disputed = TRUE) * 100.0 / COUNT(*), 2) AS dispute_rate_pct
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw
WHERE product IS NOT NULL
GROUP BY product
ORDER BY total_complaints DESC
LIMIT 3;

-- State Level Complaint Volume
SELECT 
  state,
  COUNT(*) AS total_complaints,
  ROUND(COUNTIF(timely_response = TRUE) * 100.0 / COUNT(*), 2) AS timely_response_pct,
  ROUND(COUNTIF(consumer_disputed = TRUE) * 100.0 / COUNT(*), 2) AS dispute_rate_pct,
  COUNT(DISTINCT company_name) AS unique_companies
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw
WHERE state IS NOT NULL
GROUP BY state
ORDER BY total_complaints DESC
LIMIT 5;

-- Yearly Dispute Trend by Product
SELECT 
  EXTRACT(YEAR FROM date_received) AS complaint_year,
  product,
  COUNT(*) AS total_complaints,
  ROUND(COUNTIF(consumer_disputed = TRUE) * 100.0 / COUNT(*), 2) AS dispute_rate_pct
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw
WHERE date_received IS NOT NULL
  AND product IN (
    'Mortgage',
    'Debt collection',
    'Credit card',
    'Bank account or service',
    'Consumer Loan'
  )
GROUP BY complaint_year, product
ORDER BY complaint_year, total_complaints DESC;


-- VIEW_1: Base metrics (foundation layer for the composite risk scoring model)
-- Purpose: To Establish a baseline risk signals per company by aggregating complaint volume, resolution quality, operational compliance, and exposure breadth.

-- Key Metrics:
--   total_complaints     : Volume signal
--   response_failure_pct : Operational compliance signal  
--   dispute_rate_pct     : Resolution quality signal
--   products_affected    : Breadth of product risk
--   states_affected      : Geographic exposure

CREATE OR REPLACE VIEW `zinc-silicon-478503-m3`.cfpb_complaints.vw_company_base_metrics AS
SELECT 
  company_name,
  COUNT(*) AS total_complaints,
  ROUND(COUNTIF(timely_response = FALSE) * 100.0 / COUNT(*), 2) AS response_failure_pct,
  ROUND(COUNTIF(consumer_disputed = TRUE) * 100.0 / COUNT(*), 2) AS dispute_rate_pct,
  COUNT(DISTINCT product) AS products_affected,
  COUNT(DISTINCT state) AS states_affected
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw
WHERE company_name IS NOT NULL
GROUP BY company_name
HAVING COUNT(*) >= 100
ORDER BY total_complaints DESC;

SELECT *
FROM `zinc-silicon-478503-m3`.cfpb_complaints.vw_company_base_metrics
LIMIT 10;


-- VIEW_2: Trend Score: is the company getting better or worse over time?
CREATE OR REPLACE VIEW `zinc-silicon-478503-m3`.cfpb_complaints.vw_company_trend AS
SELECT
  company_name,
  COUNTIF(EXTRACT(YEAR FROM date_received) = 2014) AS complaints_2014,
  COUNTIF(EXTRACT(YEAR FROM date_received) = 2015) AS complaints_2015,
  COUNTIF(EXTRACT(YEAR FROM date_received) = 2016) AS complaints_2016,
  ROUND(
    (COUNTIF(EXTRACT(YEAR FROM date_received) = 2016) - 
     COUNTIF(EXTRACT(YEAR FROM date_received) = 2014)) * 100.0 /
    NULLIF(COUNTIF(EXTRACT(YEAR FROM date_received) = 2014), 0)
  , 2) AS complaint_growth_pct
FROM `zinc-silicon-478503-m3`.cfpb_complaints.cfpb_complaints_raw
WHERE company_name IS NOT NULL
  AND date_received IS NOT NULL
GROUP BY company_name
HAVING complaints_2014 >= 50
ORDER BY complaint_growth_pct DESC;

SELECT *
FROM `zinc-silicon-478503-m3`.cfpb_complaints.vw_company_trend
LIMIT 10;


--VIEW_3: Composite risk score
CREATE OR REPLACE VIEW `zinc-silicon-478503-m3`.cfpb_complaints.vw_risk_score AS
SELECT
  b.company_name,
  b.total_complaints,
  b.response_failure_pct,
  b.dispute_rate_pct,
  b.products_affected,
  b.states_affected,
  t.complaint_growth_pct,

  -- Volume Score
  CASE 
    WHEN b.total_complaints >= 10000 THEN 3
    WHEN b.total_complaints >= 1000 THEN 2
    ELSE 1
  END AS volume_score,

  -- Dispute Rate Score
  CASE 
    WHEN b.dispute_rate_pct > 15 THEN 3
    WHEN b.dispute_rate_pct >= 5 THEN 2
    ELSE 1
  END AS dispute_score,

  -- Response Failure Score
  CASE 
    WHEN b.response_failure_pct > 5 THEN 3
    WHEN b.response_failure_pct >= 1 THEN 2
    ELSE 1
  END AS response_score,

  -- Trend Score
  CASE 
    WHEN t.complaint_growth_pct > 100 THEN 3
    WHEN t.complaint_growth_pct >= 0 THEN 2
    ELSE 1
  END AS trend_score,

  -- Composite Score
  (CASE WHEN b.total_complaints >= 10000 THEN 3
        WHEN b.total_complaints >= 1000 THEN 2
        ELSE 1 END +
   CASE WHEN b.dispute_rate_pct > 15 THEN 3
        WHEN b.dispute_rate_pct >= 5 THEN 2
        ELSE 1 END +
   CASE WHEN b.response_failure_pct > 5 THEN 3
        WHEN b.response_failure_pct >= 1 THEN 2
        ELSE 1 END +
   CASE WHEN t.complaint_growth_pct > 100 THEN 3
        WHEN t.complaint_growth_pct >= 0 THEN 2
        ELSE 1 END) AS composite_score,

  -- Risk Level
  CASE
    WHEN (CASE WHEN b.total_complaints >= 10000 THEN 3
               WHEN b.total_complaints >= 1000 THEN 2
               ELSE 1 END +
          CASE WHEN b.dispute_rate_pct > 15 THEN 3
               WHEN b.dispute_rate_pct >= 5 THEN 2
               ELSE 1 END +
          CASE WHEN b.response_failure_pct > 5 THEN 3
               WHEN b.response_failure_pct >= 1 THEN 2
               ELSE 1 END +
          CASE WHEN t.complaint_growth_pct > 100 THEN 3
               WHEN t.complaint_growth_pct >= 0 THEN 2
               ELSE 1 END) >= 10 THEN 'HIGH'
    WHEN (CASE WHEN b.total_complaints >= 10000 THEN 3
               WHEN b.total_complaints >= 1000 THEN 2
               ELSE 1 END +
          CASE WHEN b.dispute_rate_pct > 15 THEN 3
               WHEN b.dispute_rate_pct >= 5 THEN 2
               ELSE 1 END +
          CASE WHEN b.response_failure_pct > 5 THEN 3
               WHEN b.response_failure_pct >= 1 THEN 2
               ELSE 1 END +
          CASE WHEN t.complaint_growth_pct > 100 THEN 3
               WHEN t.complaint_growth_pct >= 0 THEN 2
               ELSE 1 END) >= 7 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS risk_level

FROM `zinc-silicon-478503-m3`.cfpb_complaints.vw_company_base_metrics b
LEFT JOIN `zinc-silicon-478503-m3`.cfpb_complaints.vw_company_trend t
  ON b.company_name = t.company_name;

SELECT *
FROM `zinc-silicon-478503-m3`.cfpb_complaints.vw_risk_score
ORDER BY composite_score DESC, dispute_rate_pct DESC
LIMIT 10;

--VIEW_4: final executive summary
CREATE OR REPLACE VIEW `zinc-silicon-478503-m3`.cfpb_complaints.vw_executive_risk_summary AS
SELECT
  risk_level,
  COUNT(*) AS total_companies,
  ROUND(AVG(total_complaints), 0) AS avg_complaints,
  ROUND(AVG(dispute_rate_pct), 2) AS avg_dispute_rate,
  ROUND(AVG(response_failure_pct), 2) AS avg_response_failure,
  ROUND(AVG(complaint_growth_pct), 2) AS avg_complaint_growth
FROM `zinc-silicon-478503-m3`.cfpb_complaints.vw_risk_score
GROUP BY risk_level
ORDER BY 
  CASE risk_level 
    WHEN 'HIGH' THEN 1 
    WHEN 'MEDIUM' THEN 2 
    ELSE 3 
  END;


SELECT *
FROM `zinc-silicon-478503-m3`.cfpb_complaints.vw_executive_risk_summary;