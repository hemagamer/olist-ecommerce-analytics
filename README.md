# 🛒 Olist E-Commerce Analytics — End-to-End Data Analytics Portfolio Project

**Author:** Ibrahim Mohamed Ibrahim Khalil  
**Dataset:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)  
**Period Covered:** 2016 – 2018 | **Orders:** 99,441+  

---

## 📋 Project Overview

A full end-to-end data analytics project built on the Olist Brazilian E-Commerce public dataset — covering the complete pipeline from raw CSV ingestion to a multi-tool analytics stack. The project targets four analytical domains: **Sales & Revenue**, **Delivery Performance**, **Seller Performance**, and **Customer Satisfaction**, producing actionable business intelligence through dashboards, statistical models, and machine learning.

---

## 🛠️ Technology Stack

| Tool | Role |
|------|------|
| **PostgreSQL 16 + pgAdmin 4** | Primary database — schema design, data import, all analytical SQL queries, views |
| **Microsoft Excel + Power Query (M)** | Data cleaning, type correction, calculated columns, category consolidation, pivot dashboards |
| **Power BI Desktop** | Final interactive dashboards with DAX measures and relational data model |
| **Python (Jupyter)** | EDA, geospatial mapping, Random Forest classifier, K-Means clustering, RFM/CLV modeling |
| **R + RStudio** | Hypothesis testing, linear regression, ggplot2 visualizations |
| **Tableau** | Enterprise-grade visual storyboarding with LOD expressions and geospatial heatmaps |

---

## 📁 Project Structure

```
OLIST/
│
├── 📂 SQL
│   ├── TABLE INIT.sql               # Schema provisioning — table creation, data types, PKs, FKs
│   ├── view creation.sql            # order_delivery_view + all analytical views
│   └── olist_analysis.sql           # 20+ analytical queries (revenue, delivery, sellers, satisfaction)
│
├── 📂 Excel
│   └── OLIST.xlsx                   # Power Query cleaning + pivot dashboards
│
├── 📂 Power BI
│   ├── PBI.pbix                     # Full 4-page operational dashboard
│   ├── PBI EXEC DASH.png            # Executive summary dashboard screenshot
│   ├── PBI LOGISTICS.png            # Logistics & delivery performance dashboard screenshot
│   ├── PBI MISC.png                 # Seller performance & satisfaction dashboard screenshot
│   └── EXCEL DASH.png               # Excel dashboard screenshot
│
├── 📂 Tableau
│   ├── OLIST.twb                    # Full Tableau workbook (Noodle model + all dashboards)
│   └── TABLEAU DASH.png             # Executive Command Center screenshot
│
├── 📂 Python
│   └── PYTHON ANALYSIS.ipynb        # EDA → Geospatial → Random Forest → K-Means → RFM/CLV
│
├── 📂 R
│   └── R.R                          # DBI pipeline → ggplot2 → hypothesis tests → regression
│
├── 📂 Visuals / Output Charts
│   ├── PROJECT FLOW CHART.png                        # End-to-end pipeline architecture diagram
│   ├── BRAZIL LOGISTICS RISK MAP.png                 # Geospatial SLA heatmap — northern red zones
│   ├── MACRO TRADE FLOW SANKEY.png                   # SP trade route concentration analysis
│   ├── ORDERS HEATMAP.png                            # Order volume by day-of-week × hour
│   ├── MACRO ECOSYS CORR MATRIX.png                  # Ecosystem-wide Pearson correlation matrix
│   ├── 3D logistics Matrix kmeans customer arche types.png  # K-Means 3D cluster visualization
│   ├── CUSTOMER BASE SEGMENTATION MATRIX RFM.png     # RFM behavioral tier matrix
│   ├── CUSTOMER SATISFACTION.png                     # Review score distributions & late impact
│   └── CREDIT DEPENDENCY OV vs installments.png      # Credit card installment dependency analysis
│
└── 📂 Data
    └── raw/                         # Original 8 CSV files from Kaggle (not committed — see note below)
```

> **Note on raw data:** The 8 original Kaggle CSV files are not committed to this repository due to size constraints. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place the files in `data/raw/` before running `TABLE INIT.sql`.

---

## 🗄️ Database Design

### The MySQL → PostgreSQL Migration

The project did not begin on PostgreSQL — it was a deliberate architectural pivot forced by two fatal engine failures in MySQL:

| Error | Root Cause | Impact |
|---|---|---|
| **Error 1170** — BLOB/TEXT key length restriction | MySQL cannot index `TEXT` columns without an explicit key prefix length, which was incompatible with the dataset's long string IDs used as foreign keys | Schema could not enforce referential integrity on the core `order_id` and `customer_id` relationships |
| **Error 2013** — Lost connection during heavy joins | Client-side connection timeouts triggered during multi-table joins across the 100,000+ row dataset | Made complex analytical queries unreliable and non-reproducible |

The decision to migrate fully to **PostgreSQL 16** was not arbitrary — PostgreSQL's native `TEXT` type carries no indexing length restriction, and its `SERIAL` surrogate key pattern cleanly resolved the geolocation normalization problem that MySQL's engine could not handle gracefully.

### Schema
The PostgreSQL schema follows a **star schema** pattern with `olist_orders_dataset` as the central fact table.

| Table | Rows | Key Columns |
|-------|------|-------------|
| olist_orders_dataset | 99,441 | order_id, customer_id |
| olist_customers_dataset | 99,441 | customer_id, zip_code_prefix |
| olist_order_items_dataset | 112,650 | order_id, product_id, seller_id |
| olist_order_payments_dataset | 103,886 | order_id, payment_type |
| olist_order_reviews_dataset | 99,224 | review_id, order_id |
| olist_products_dataset | 32,951 | product_id, category_name |
| olist_sellers_dataset | 3,095 | seller_id, zip_code_prefix |
| olist_geolocation_dataset | 1,000,163 | zip_code_prefix, lat, lng |

### Geolocation Bridge Table

The geolocation table had a fundamental normalization challenge: a single `zip_code_prefix` maps to multiple coordinate rows, making it impossible to use as a primary key. The solution was a **bridge table** (`customer_geolocation`) using a SERIAL surrogate key on the geolocation table, preserving all coordinate data while maintaining proper relational integrity.

```sql
CREATE TABLE customer_geolocation (
    customer_id    VARCHAR(50) NOT NULL,
    geolocation_id INT         NOT NULL,
    PRIMARY KEY (customer_id, geolocation_id),
    FOREIGN KEY (customer_id)    REFERENCES olist_customers_dataset(customer_id),
    FOREIGN KEY (geolocation_id) REFERENCES olist_geolocation_dataset(geolocation_id)
);
```

---

## 🔍 SQL Analytics Layer

The SQL work is split across two files: **`TABLE INIT.sql`** handles schema provisioning (CREATE TABLE, data types, constraints, indexes), and **`view creation.sql`** + **`olist_analysis.sql`** contain the analytical layer.

A reusable `order_delivery_view` encapsulates delivery time calculations referenced by all delivery-related queries. A `WHERE order_status = 'delivered'` filter was applied as a **data leakage prevention measure** — ensuring all downstream ML models train exclusively on completed, factual delivery routes rather than canceled or in-progress orders.

```sql
CREATE VIEW order_delivery_view AS
SELECT
    o.order_id,
    o.customer_id,
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date
        - o.order_purchase_timestamp))/86400 AS actual_delivery_days,
    EXTRACT(EPOCH FROM (o.order_estimated_delivery_date
        - o.order_purchase_timestamp))/86400 AS estimated_delivery_days,
    CASE
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN 1 ELSE 0
    END AS is_late
FROM olist_orders_dataset o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;
```

**SQL techniques demonstrated:**

- Window functions (`SUM() OVER()`, `COUNT(*) OVER()`)
- CTEs for multi-step seller scorecard queries
- `EXTRACT` / `DATE_TRUNC` for temporal analysis
- `CASE` statements for feature engineering (delivery buckets, late flags)
- Multi-table JOINs across 4+ tables in a single query
- `UNION ALL` for top/bottom seller ranking
- `CREATE INDEX` for JOIN optimization before heavy INSERT operations

---

## 🧹 Data Cleaning Highlights

### Category Consolidation
73 Portuguese product categories were translated to English and consolidated into **37 clean macro groups** across two rounds:

- **Round 1** — Must-merge duplicates and typo fixes (e.g., `fashio_female_clothing` → `fashion_female_clothing`)
- **Round 2** — Logical groupings (e.g., `computers` + `computers_accessories` + `pc_gamer` → `computers_and_accessories`)

Final macro groups: Technology, Home & Furniture, Tools, Health & Personal, Fashion, Baby & Kids, Automotive, Sports, Media & Arts, Food, and more.

### Power Query (M Code)
All consolidations were implemented in a single `Table.ReplaceValue` call, executing in one pass rather than chained sequential steps. Null categories were explicitly mapped to `"unknown"`.

---

## 📊 Key Findings

### Revenue & Growth
- Revenue grew approximately **10x** from Q3 2016 to Q2 2018, peaking at ~R$3.5M in Q2 2018
- **Top 3 revenue categories:** health_beauty, watches_gifts, bed_bath_table
- ~73% of transactions used credit card; ~19% used Boleto

### Delivery Performance
- Northern states (RR, AP, AM) average **22–28 day delivery times**, 2–3x longer than São Paulo (~10 days)
- Late delivery rates in northern states reach **48–52%**
- ~8% of all delivered orders arrived after the estimated delivery date

### Customer Satisfaction
- 5-star reviews account for ~57% of all reviews; 1-star accounts for ~11% — a bimodal distribution
- Late deliveries consistently receive lower review scores
- The R regression model quantified: **every additional late day reduces the expected review score by ~0.0308 points** (p < 2.2e-16)

---

## 🤖 Predictive AI & Segmentation Layer (Python)

The project shifted from diagnosing historical data to predicting future operational failures using `SQLAlchemy`, `Scikit-Learn`, `Seaborn`, and `Plotly`.

### Network Flow Analytics — Trade Route Sankey Diagram

Before building predictive models, the supply chain's structural risk was visualized using a **Plotly Sankey diagram** mapping the flow of goods from seller states → product categories → customer states. This exposed an existential concentration risk: a disproportionate volume of all orders in the dataset originates from a single São Paulo hub, meaning any disruption to SP's logistics infrastructure cascades nationally. This is the visual proof behind the "Decentralize the Seller Network" recommendation.

### Direct SQLAlchemy Pipelines — Leak-Proof Feature Engineering

Data was pulled from PostgreSQL directly into Pandas via SQLAlchemy, with the JOIN written to strictly exclude any post-delivery variables. Only features available at the moment of checkout were included:

```python
query = """
    SELECT
        oi.freight_value,
        oi.price,
        p.product_weight_g,
        (p.product_length_cm * p.product_height_cm * p.product_width_cm) AS product_volume_cm3,
        CASE WHEN c.customer_state != s.seller_state THEN 1 ELSE 0 END AS cross_state,
        odv.is_late
    FROM olist_order_items_dataset oi
    JOIN olist_products_dataset p      ON oi.product_id   = p.product_id
    JOIN olist_orders_dataset o        ON oi.order_id     = o.order_id
    JOIN olist_customers_dataset c     ON o.customer_id   = c.customer_id
    JOIN olist_sellers_dataset s       ON oi.seller_id    = s.seller_id
    JOIN order_delivery_view odv       ON oi.order_id     = odv.order_id
"""
```

No estimated delivery date, no actual delivery date, no review score — nothing that wouldn't exist at checkout.

### Random Forest — Predictive SLA Engine

**Class Imbalance Resolution with SMOTE**

The raw dataset has a 92/8 split between on-time and late deliveries. Training on this imbalance produces a model that predicts "on-time" 92% of the time and achieves misleadingly high accuracy while being useless for actually catching late orders. SMOTE was applied exclusively to the training set — never the test set:

```python
from imblearn.over_sampling import SMOTE

sm = SMOTE(random_state=42)
X_train_res, y_train_res = sm.fit_resample(X_train, y_train)
# Test set remains untouched — evaluating on the real class distribution
```

**Optimizing for Recall, Not Accuracy**

The classifier was specifically tuned to achieve **Recall > 0.70 for the late delivery class**. This is a deliberate business calculation:

| Error Type | Business Consequence | Cost |
|---|---|---|
| **False Negative** — missed late prediction | Customer receives no warning → order arrives late → 7× more likely to leave 1-star review → brand damage | **HIGH** |
| **False Positive** — unnecessary SLA buffer added | Customer gets a conservative delivery estimate → order arrives early → positive surprise effect | **LOW** |

Missing a high-risk shipment is far more costly than over-communicating caution. The decision threshold was tuned on the precision-recall curve rather than left at the default 0.5 boundary.

**Feature Importance Results**

Extracting feature importances from the trained forest mathematically proved that `product_volume_cm3` and the `cross_state` flag are the dominant predictors of delivery failure — not price, not weight alone. This directly targets where the engineering fix should be applied.

### K-Means Clustering — Order Archetypes

Unsupervised clustering grouped historical orders into operational archetypes to reveal fulfillment structure without a predefined label.

| Cluster | Profile |
|---|---|
| **Standard** | Low freight, fast delivery, low price |
| **Premium** | High price, moderate freight, good reviews |
| **Logistics Nightmare** | High freight + extreme delay + bulky — geographically concentrated in northern states |
| **Remote** | High freight, very slow, moderate price |

### RFM Customer Segmentation

Transitioned from aggregate analytics to individual-level segmentation, enabling targeted CRM campaigns across 99,000+ users.

| Segment | Profile | Action |
|---|---|---|
| **Champions** | Recent, frequent, high spend | Reward loyalty, use as brand advocates |
| **Loyal Customers** | Consistent buyers | Upsell to higher-value categories |
| **Potential Loyalists** | Recent, showing promise | Drive second purchase |
| **At Risk** | Formerly active, going quiet | Win-back campaigns with urgency messaging |
| **Lost Customers** | Inactive, low value | Low-cost reactivation or deprioritize |
| **New Customers** | Just purchased | Onboarding sequence within 30 days |

### Predictive CLV — Buy Till You Die (BG/NBD + Gamma-Gamma)

The analysis went beyond static RFM scoring by deploying a two-model probabilistic CLV framework via the `lifetimes` library:

| Model | What It Estimates |
|---|---|
| **BG/NBD** (Beta-Geometric / Negative Binomial Distribution) | The probability that a customer is still "alive" (not churned) and their expected number of future transactions in a given time window |
| **Gamma-Gamma** | The expected average monetary value of each future transaction, conditioned on the customer being active |

Combined, these produce a **per-customer predictive CLV** — not a historical average, but a forward-looking financial forecast. This quantifies the monetary gap between Champions and Lost Customers to justify differential marketing budget allocation across RFM tiers.

---

## 📐 Statistical Proof Layer (R & RStudio)

Visual theories established in Tableau were taken to mathematical certainty in R. Rather than exporting CSVs, the PostgreSQL database was pulled directly into R RAM via `DBI` and `RPostgres`, keeping the pipeline live and eliminating intermediate file steps.

### Assumption Testing Before Algorithm Selection

The choice of statistical test was not arbitrary — it was derived from formal normality checks run first:

```r
# Step 1: Check normality of delivery days distribution
shapiro.test(sample(df$actual_delivery_days, 5000))  # Shapiro-Wilk (n limited for performance)
qqnorm(df$actual_delivery_days); qqline(df$actual_delivery_days)

# Step 2: Check review score distribution
hist(df$review_score)  # Reveals bimodal spike at 1 and 5
```

**Findings from assumption testing:**

| Variable | Distribution Shape | Test Implication |
|---|---|---|
| `actual_delivery_days` | Heavily right-skewed — long tail of extreme late orders | Violates normality assumption → non-parametric test required |
| `review_score` | Bimodal — mass concentrated at 1 and 5 stars | Violates normality → ordinal/non-parametric approach |

This ruled out a standard Pearson correlation and Student's t-test. The analysis was adapted accordingly:

- **Two-sample Welch t-test** for the late vs. on-time review score comparison (Welch's variant is robust to unequal variance, which exists between the two groups)
- **Spearman rank correlation** instead of Pearson for the delay days × review score relationship — Spearman makes no assumption about the underlying distribution and handles the ordinal nature of the 1–5 scale correctly

### "Anatomy of a Bad Review" — ggplot2 Boxplot

A custom `ggplot2` boxplot mapped SLA delay days against the 1–5 star rating scale. The interquartile ranges proved visually that **1-star reviews are heavily populated by extreme outliers in the "late" territory (+10 to +20 days)**, while 5-star reviews were almost exclusively delivered early.

### Multiple Linear Regression — `lm()`

```r
lm(review_score ~ sla_error_days + freight_value + price + product_weight_g)
```

| Finding | Result |
|---|---|
| **Global model significance** | F-statistic p-value < 2.2e-16 — 99.9% statistical certainty |
| **The Coefficient of Delay** | Every additional late day drops the expected review score by **−0.0308 points** |
| **The Weight Myth debunked** | `product_weight_g` has zero statistical significance (p = 0.375) — physical weight does not impact satisfaction |
| **Behavioral context** | R² = 0.054 — logistics explains a portion of variance; the remainder is unmeasured human factors (product quality, seller communication) |

---

## 📊 Business Intelligence Layer

### Power BI — Operational Dashboards

Rather than just surfacing raw numbers, Power BI was used to build operational command centers that make data understandable for non-technical stakeholders. DAX measures were engineered for all 16 KPIs across the four analytical domains.

| Page | Key Visuals |
|------|-------------|
| Sales & Revenue | Revenue trend line, top categories bar, Brazil choropleth map, date/state slicers |
| Delivery Performance | Avg delivery by state, late rate by state, delivery bucket histogram |
| Seller Performance | Seller scorecard table, delivery vs. review scatter, seller geography map |
| Customer Satisfaction | Review distribution, avg review by category, late vs. on-time cross-tab, score by delivery bucket |

**Core DAX Measures:**
```dax
Late Order Rate =
DIVIDE(
    COUNTROWS(FILTER(order_delivery_view, order_delivery_view[is_late] = 1)),
    COUNTROWS(order_delivery_view)
)

Avg Delivery Days = AVERAGE(order_delivery_view[actual_delivery_days])
Total Revenue     = SUM(olist_order_payments_dataset[payment_value])
Total Orders      = DISTINCTCOUNT(olist_orders_dataset[order_id])
Avg Review Score  = AVERAGE(olist_order_reviews_dataset[review_score])
```

---

### Tableau — Executive Command Center

Tableau was used to build the boardroom-ready visual storyboard, complementing Power BI with superior geographic visualization capabilities and LOD expressions for complex aggregation.

**Performance Engineering — Tableau Extracts**

The live PostgreSQL connection was viable for development but introduced latency on a 100,000+ row dataset during dashboard interactions. The final published dashboards use compressed columnar **Tableau Extracts (`.hyper` files)** rather than live connections. The `.hyper` format stores data in columnar layout optimized for analytical aggregation, delivering sub-second filter response on the geospatial and cross-tab views that would otherwise require round-trips to the database.

**The "Noodle" Relational Model**

To prevent Cartesian product duplication — where joining Orders to both Items and Payments simultaneously inflates revenue totals — a hub-and-spoke logical model was architected with `Orders` as the anchor table. `Products` and `Payments` were strictly chained *through* `Order Items`, preserving the correct financial granularity.

| Relationship | Type |
|---|---|
| Orders → Order Items | Many-to-One on order_id |
| Order Items → Products | Many-to-One on product_id |
| Orders → Payments | Many-to-One on order_id (separate chain) |
| Orders → Reviews | Many-to-One on order_id |
| Orders → Customers | Many-to-One on customer_id |

**LOD Expressions — `FIXED` and `EXCLUDE`**

Standard aggregations in Tableau operate at the view's granularity level. When an order contains multiple items, a naive `SUM([payment_value])` at item granularity double-counts revenue. Two LOD expression types were deployed to solve this:

```
# FIXED: Revenue per State — ignores all view-level filters except context filters
{ FIXED [customer_state] : SUM([payment_value]) }

# FIXED: First purchase date for cohort construction
{ FIXED [customer_unique_id] : MIN([order_purchase_timestamp]) }

# EXCLUDE: Avg delivery time excluding the item-level dimension to prevent fan-out
{ EXCLUDE [product_id] : AVG([actual_delivery_days]) }
```

The `EXCLUDE` pattern specifically prevents the "fan-out" problem where joining to the items table causes delivery days to be summed across each item row in an order rather than once per order.

**Key Dashboards:**

| Dashboard | Purpose |
|---|---|
| **Geospatial Risk Heatmap** | Filled map of Brazil colored by late delivery rate — visually proved the logistics network is collapsing in northern states (RR, AP, AM). Size-encoded circles for order volume; tooltip shows avg delivery days, late rate %, and freight burden % |
| **Revenue Storyboard** | Time-series area chart with annotations, category treemap sized by revenue, state-level bar chart for executive/board audience |
| **Seller Performance Matrix** | Scatter: x=avg delivery days, y=avg review score, size=revenue, color=seller state — divides sellers into quadrant performance tiers |
| **Customer Cohort Analysis** | Heatmap of retention rate by cohort month × months since first purchase — reveals how quickly Olist loses customers after first purchase |

---

## 🖼️ Visual Gallery

### Pipeline Architecture
| | |
|---|---|
| ![Project Flow Chart](PROJECT%20FLOW%20CHART.png) |  **End-to-end pipeline architecture** showing the 6-phase flow from raw CSV ingestion through PostgreSQL → Excel → Power BI → Tableau → Python → R, with data direction and tool handoffs |

### Power BI Dashboards
| | |
|---|---|
| ![Executive Dashboard](PBI%20EXEC%20DASH.png) | **Executive Summary** — top-line KPIs for orders, revenue, review score, and late rate |
| ![Logistics Dashboard](PBI%20LOGISTICS.png) | **Logistics & Delivery** — state-level heatmap, delivery bucket histogram, late rate trend |
| ![Misc Dashboard](PBI%20MISC.png) | **Seller & Satisfaction** — scorecard table, delivery vs. review scatter, satisfaction breakdown |
| ![Excel Dashboard](EXCEL%20DASH.png) | **Excel Pivot Dashboard** — baseline financial model used as cross-validation source of truth |

### Tableau Executive Command Center
| | |
|---|---|
| ![Tableau Dashboard](TABLEAU%20DASH.png) | **4-quadrant Executive Command Center** — Geospatial Risk Heatmap, Revenue Storyboard, Seller Matrix, Customer Cohort |

### Python Analysis Outputs
| | |
|---|---|
| ![Brazil Risk Map](BRAZIL%20LOGISTICS%20RISK%20MAP.png) | **Geospatial SLA Heatmap** — Folium choropleth proving northern state network collapse (RR, AP, AM) |
| ![Sankey](MACRO%20TRADE%20FLOW%20SANKEY.png) | **Macro Trade Flow Sankey** — São Paulo seller concentration risk visualized as order flow volume |
| ![Orders Heatmap](ORDERS%20HEATMAP.png) | **Order Volume Heatmap** — day-of-week × hour matrix revealing peak purchase windows |
| ![Correlation Matrix](MACRO%20ECOSYS%20CORR%20MATRIX.png) | **Ecosystem Correlation Matrix** — Pearson correlations across all major numeric features |
| ![K-Means 3D](3D%20logistics%20Matrix%20kmeans%20customer%20arche%20types.png) | **3D K-Means Cluster Visualization** — order archetype segmentation (Standard / Premium / Logistics Nightmare / Remote) |
| ![RFM Matrix](CUSTOMER%20BASE%20SEGMENTATION%20MATRIX%20RFM.png) | **Customer Segmentation Matrix** — RFM behavioral tier mapping across 99,000+ users |
| ![Satisfaction](CUSTOMER%20SATISFACTION.png) | **Customer Satisfaction Analysis** — review score distribution + late delivery impact overlay |
| ![Credit Dependency](CREDIT%20DEPENDENCY%20OV%20vs%20installments.png) | **Credit Installment Dependency** — order value vs. installment usage; CFO-level risk surface |

---

## 💼 Strategic Business Insights & Recommendations

### Key Analytical Proofs

| Finding | Detail |
|---|---|
| **The 7x Penalty** | Late deliveries make customers 7× more likely to leave a 1-star review — proved through the late vs. on-time review cross-tab analysis |
| **The Coefficient of Delay** | Every single late day mathematically reduces the expected review score by −0.0308 points (p < 2.2e-16) |
| **The Weight Myth** | Physical product weight has zero statistically significant impact on customer satisfaction (p = 0.375) |
| **Northern Network Collapse** | States RR, AP, AM show 48–52% late rates and 22–28 day average delivery times — 2–3× the national average |
| **São Paulo Concentration Risk** | Sankey trade route analysis revealed a disproportionate volume of orders ship out of SP — a systemic supply chain concentration risk |
| **Installment Dependency** | ~73% of transactions use credit card; high-ticket categories depend entirely on 10+ month installment plans |

### Strategic Roadmap

1. **Dynamic SLA Checkout Buffers** — Integrate the Random Forest model at checkout to automatically pad delivery estimates for high-volume or cross-state orders; the model proves product volume and freight cost are the mathematical root cause of SLA breaches
2. **Renegotiate Northern LTL Carrier Contracts** — Onboard specialized regional freight partners in northern Brazil with SLA-backed penalty clauses for deliveries exceeding 21 days
3. **Decentralize the Seller Network** — Incentivize seller onboarding outside São Paulo to reduce cross-state shipment volume; cross-state flag is a top Random Forest predictor of late delivery
4. **Protect the Installment Pipeline** — Monitor installment utilization rate as a leading revenue indicator; hedge against SELIC rate increases to protect high-ticket category revenue
5. **Targeted CRM via RFM Segmentation** — Deploy differentiated campaigns per behavioral tier, prioritizing the "At Risk" win-back segment given their historically high monetary value

---

## ✅ Data Integrity Validation & Feature Engineering Decisions

### Referential Integrity Audit — LEFT ANTI JOIN

Before any modeling began, proactive orphan record hunting was executed across all foreign key relationships. A LEFT ANTI JOIN pattern was used rather than relying on constraint enforcement alone, since constraints applied after import cannot catch pre-existing dirty references:

```sql
-- Orphan audit: order_items referencing non-existent orders
SELECT oi.order_id
FROM olist_order_items_dataset oi
LEFT JOIN olist_orders_dataset o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Orphan audit: orders referencing non-existent customers
SELECT o.customer_id
FROM olist_orders_dataset o
LEFT JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
```

This pattern was applied across every FK relationship in the schema before any JOIN-based analytical query was executed.

### Feature Pruning

Deliberate decisions were made to drop columns that would have added noise without analytical value:

| Column Dropped | Reason |
|---|---|
| `review_comment_title` | **88.4% NULL** — virtually no coverage; imputing or carrying forward would have manufactured signal from noise |
| Timestamp columns on undelivered orders | Excluded via `WHERE order_status = 'delivered'` filter to prevent data leakage into ML features |

### Anomaly Eradication

- **Future delivery timestamps** — orders where `order_delivered_customer_date < order_purchase_timestamp` were identified and purged; these would have produced negative delivery durations that corrupt all SLA calculations
- **Zero-price items** — flagged and excluded from revenue aggregations
- **Blank state codes** — identified in geolocation joins and handled explicitly rather than silently propagated as NULLs

### Power Query Timestamp Engineering

When calculating delivery durations in M Code, a specific type-correction step was required before applying `Duration.Days()`. Timestamps imported from CSV arrive as plain `text` — applying duration arithmetic directly causes silent type errors. The fix:

```m
// Step 1: Convert text → DateTime explicitly
#"Changed Type" = Table.TransformColumnTypes(Source, {
    {"order_purchase_timestamp",     type datetime},
    {"order_delivered_customer_date", type datetime}
}),

// Step 2: Now safe to compute duration
#"Added Delivery Days" = Table.AddColumn(
    #"Changed Type",
    "delivery_days",
    each Duration.Days([order_delivered_customer_date] - [order_purchase_timestamp]),
    Int64.Type
)
```

Skipping the explicit cast is a silent failure mode — Power Query returns `null` for the duration column with no error raised, which would have produced a dashboard full of blank delivery metrics.

---

## 🚧 Project Status

| Phase | Tool(s) | Status |
|-------|---------|--------|
| Schema Provisioning & Data Ingestion | PostgreSQL / pgAdmin 4 | ✅ Complete |
| SQL Analytical Queries (20+) | PostgreSQL | ✅ Complete |
| Data Cleaning & Category Consolidation | Excel + Power Query | ✅ Complete |
| Excel Pivot Dashboard | Excel | ✅ Complete |
| Operational BI Dashboards | Power BI | ✅ Complete |
| Executive Command Center | Tableau | ✅ Complete |
| EDA, Geospatial & ML Pipeline | Python (Jupyter) | ✅ Complete |
| Statistical Proofs & Regression | R + RStudio | ✅ Complete |
