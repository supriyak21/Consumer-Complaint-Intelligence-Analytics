# Consumer Complaint Intelligence Analytics

![BigQuery](https://img.shields.io/badge/BigQuery-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![Looker Studio](https://img.shields.io/badge/Looker%20Studio-4285F4?style=for-the-badge&logo=google&logoColor=white)
![GCP](https://img.shields.io/badge/GCP-FF6F00?style=for-the-badge&logo=google-cloud&logoColor=white)

---

## Business Problem

Financial regulators and compliance teams receive millions of consumer complaints annually against banks, lenders, and financial institutions — but have limited resources to investigate every company.

**This project answers a critical compliance question:**
> *"Which financial institutions pose the highest regulatory risk and should be prioritized for compliance review — based not just on complaint volume, but on resolution quality, operational failures, and complaint trajectory?"*

This mirrors real-world risk signal work performed by CFPB analysts, internal bank compliance teams, and financial regulators to surface intervention priorities from large-scale complaint data.

---

## Dataset

| Attribute | Details |
|---|---|
| **Source** | CFPB Consumer Complaint Database (Google Cloud Marketplace) |
| **Size** | 3.4M+ complaints |
| **Period** | December 2011 — December 2016 |
| **Scope** | 1,016 financial institutions across 50 US states |
| **Key Fields** | Company, Product, State, Timely Response, Consumer Disputed, Date Received |

---

## Architecture

```
bigquery-public-data
    └── cfpb_complaints.complaint_database
            │
            ▼
zinc-silicon-478503-m3
    └── cfpb_complaints
            ├── cfpb_complaints_raw          ← Raw copy of source data
            ├── vw_company_base_metrics      ← Layer 1: Base risk signals
            ├── vw_company_trend             ← Layer 2: Complaint trajectory
            ├── vw_risk_score                ← Layer 3: Composite risk scoring
            └── vw_executive_risk_summary    ← Layer 4: Executive summary
                        │
                        ▼
                Looker Studio Dashboard
                (3-page interactive report)
```

---

## Risk Scoring Methodology

Each institution is scored across **4 dimensions** (1-3 points each):

| Dimension | Low Risk (1) | Medium Risk (2) | High Risk (3) |
|---|---|---|---|
| **Complaint Volume** | < 1,000 | 1,000 – 9,999 | ≥ 10,000 |
| **Dispute Rate** | < 5% | 5% – 15% | > 15% |
| **Response Failure Rate** | < 1% | 1% – 5% | > 5% |
| **Complaint Growth (2014-2016)** | Declining | 0% – 100% | > 100% |

**Composite Score = Sum of 4 dimension scores (range: 4–12)**
- **HIGH Risk**: Score ≥ 10
- **MEDIUM Risk**: Score 7–9
- **LOW Risk**: Score ≤ 6

> *Strict thresholds are intentional — only institutions failing on multiple dimensions simultaneously qualify as HIGH risk, reducing false positives in compliance prioritization.*

---

## Key Findings

- **2 institutions flagged HIGH risk** out of 1,016 analyzed
- **TENET Healthcare Corporation** — 247% complaint growth (2014-2016), 11.5% response failure rate
- **ACS Education Services** — 140% complaint growth, 15.5% consumer dispute rate
- **26% of institutions (267 companies)** remain on MEDIUM risk watch
- **California, Texas, and Florida** account for 33%+ of all 3.4M complaints nationally
- **Mortgage sector** shows highest dispute rate at 13.75%
- **Credit Reporting** dominates complaint volume at 1.7M+ — nearly 50% of all complaints

---

## Dashboard: **https://lookerstudio.google.com/s/vfIxz8V0380**

| Page | Description |
|---|---|
| **Executive Summary** | KPI scorecards, US state heatmap, risk distribution, top risk companies |
| **Company Risk Drilldown** | Interactive table with all risk dimensions, filterable by risk level |
| **Complaint Trends Analysis** | Monthly complaint volume 2011-2016, breakdown by financial product |

---

## Tech Stack

| Tool | Purpose |
|---|---|
| **Google BigQuery** | Cloud data warehouse — storage and SQL analytics |
| **BigQuery SQL** | Window functions, CTEs, CASE scoring, layered views |
| **Looker Studio** | Interactive dashboard connected live to BigQuery |
| **GCP** | Cloud infrastructure |
| **GitHub** | Version control and project documentation |
