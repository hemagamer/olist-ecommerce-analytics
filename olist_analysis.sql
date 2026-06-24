-- 1.1 Monthly Revenue Trend

SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id)                       AS total_orders,
    ROUND(SUM(p.payment_value)::NUMERIC, 2)          AS total_revenue
FROM olist_orders_dataset o
JOIN olist_order_payments_dataset p ON o.order_id = p.order_id
WHERE o.order_status != 'canceled'
GROUP BY 1
ORDER BY 1;


-- 1.2 Revenue by Product Category
select 
	pr.product_category_name,
	count(Distinct oi.order_id) as total_orders,
	round(sum(oi.price)::Numeric,2) as total_revenue,
	round(AVG(oi.price)::Numeric,2) as Avg_order_value
from olist_order_items_dataset oi
join olist_products_dataset pr on oi.product_id=pr.product_id
group by 1
order by total_revenue desc
limit 15;

-- 1.3 Revenue by Customer State
select 
	c.customer_state,
	count(distinct o.order_id) as total_orders,
	round(sum(p.payment_value):: Numeric,2) as total_revenue
from olist_orders_dataset o
join olist_customers_dataset c on o.customer_id=c.customer_id
join olist_order_payments_dataset p on o.order_id=p.order_id
group by 1
order by total_revenue desc;

-- 1.4 Payment Method Distribution
select payment_type,count(*) as usage_count,round(sum(payment_value)::Numeric,2) as total_value,
round(avg(payment_value)::Numeric,2) as Avg_value
from olist_order_payments_dataset
group by 1
order by usage_count Desc;

-- 1.5 Peak Season — Day of Week + Hour Heatmap
select 
to_char(order_purchase_timestamp,'Day') as day_of_week,
extract(Hour from order_purchase_timestamp) as hour,
count(*) as order_count
from olist_orders_dataset
group by 1,2
order by 2;


-- 2.1 Average Delivery Time by Customer State
select c.customer_state,Round(Avg(dv.actual_delivery_days)::Numeric,2) as avg_delivery_days,
round(Avg(dv.estimated_delivery_days)::Numeric,2) as avg_estimated_days,
count(*) as total_orders
from order_delivery_view dv
join olist_customers_dataset c on dv.customer_id=c.customer_id
group by 1
order by avg_delivery_days desc;


--2.2

select c.customer_state,count(*) as total_orders,sum(dv.is_late) as late_orders,
round((sum(dv.is_late)*100.0/count(*))::Numeric,2) as late_rate_pct
from order_delivery_view dv
join olist_customers_dataset c on dv.customer_id=c.customer_id
group by 1
order by late_rate_pct desc;


--2.3
select s.seller_state,
count(*) as total_orders,
sum(dv.is_late) as late_orders,
round((sum(dv.is_late)*100.0/count(*))::Numeric,2) as late_rate_pct
from order_delivery_view dv
join olist_order_items_dataset oi on dv.order_id=oi.order_id
join olist_sellers_dataset s on oi.seller_id =s.seller_id
group by 1
order by late_rate_pct DESC;

-- 2.4 Delivery Time Distribution Buckets
SELECT
    CASE
        WHEN actual_delivery_days <= 7  THEN '0-7 days'
        WHEN actual_delivery_days <= 14 THEN '8-14 days'
        WHEN actual_delivery_days <= 21 THEN '15-21 days'
        WHEN actual_delivery_days <= 30 THEN '22-30 days'
        ELSE '30+ days'
    END AS delivery_bucket,
    COUNT(*) AS order_count
FROM order_delivery_view
GROUP BY 1
ORDER BY 2 DESC;


-- 3.1 Seller Scorecard
SELECT
    s.seller_id,
    s.seller_state,
    COUNT(DISTINCT oi.order_id)   AS total_orders,
    ROUND(SUM(oi.price)::NUMERIC, 2)  AS total_revenue,
    ROUND(AVG(r.review_score)::NUMERIC, 2)  AS avg_review_score,
    ROUND(AVG(dv.actual_delivery_days)::NUMERIC, 2)  AS avg_delivery_days,
    ROUND((SUM(dv.is_late) * 100.0 / COUNT(*))::NUMERIC, 2) AS late_rate_pct
FROM olist_sellers_dataset s
JOIN olist_order_items_dataset oi ON s.seller_id = oi.seller_id
JOIN order_delivery_view dv ON oi.order_id = dv.order_id
JOIN olist_order_reviews_dataset r ON dv.order_id = r.order_id
GROUP BY 1, 2
ORDER BY avg_review_score ASC;

-- 3.2 Correlation Setup — Delivery Days vs Review Score
SELECT
    dv.order_id,
    dv.actual_delivery_days,
    dv.is_late,
    r.review_score
FROM order_delivery_view dv
JOIN olist_order_reviews_dataset r ON dv.order_id = r.order_id;
-- Export this one to Python for actual correlation coefficient

-- 3.3 Top 10 and Bottom 10 Sellers by Avg Review
(
    SELECT seller_id, ROUND(AVG(r.review_score)::NUMERIC,2) AS avg_score, COUNT(*) AS total_orders, 'TOP' AS rank_group
    FROM olist_order_items_dataset oi
    JOIN olist_order_reviews_dataset r ON oi.order_id = r.order_id
    GROUP BY 1 HAVING COUNT(*) > 30
    ORDER BY avg_score DESC LIMIT 10
)
UNION ALL
(
    SELECT seller_id, ROUND(AVG(r.review_score)::NUMERIC,2) AS avg_score, COUNT(*) AS total_orders, 'BOTTOM' AS rank_group
    FROM olist_order_items_dataset oi
    JOIN olist_order_reviews_dataset r ON oi.order_id = r.order_id
    GROUP BY 1 HAVING COUNT(*) > 30
    ORDER BY avg_score ASC LIMIT 10
);

-- 4.1 Review Score Distribution
SELECT
    review_score,
    COUNT(*)                                            AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage
FROM olist_order_reviews_dataset
GROUP BY 1
ORDER BY 1;

-- 4.2 Avg Review Score by Product Category
SELECT
    pr.product_category_name,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_score,
    COUNT(*)                               AS total_reviews
FROM olist_order_reviews_dataset r
JOIN olist_order_items_dataset oi ON r.order_id = oi.order_id
JOIN olist_products_dataset pr ON oi.product_id = pr.product_id
GROUP BY 1
HAVING COUNT(*) > 50
ORDER BY avg_score ASC;

-- 4.3 Late Delivery vs Review Score — The Key Insight
SELECT
    dv.is_late,
    r.review_score,
    COUNT(*) AS count
FROM order_delivery_view dv
JOIN olist_order_reviews_dataset r ON dv.order_id = r.order_id
GROUP BY 1, 2
ORDER BY 1, 2;

-- 4.4 Review Score by Delivery Bucket
SELECT
    CASE
        WHEN dv.actual_delivery_days <= 7  THEN '0-7 days'
        WHEN dv.actual_delivery_days <= 14 THEN '8-14 days'
        WHEN dv.actual_delivery_days <= 21 THEN '15-21 days'
        WHEN dv.actual_delivery_days <= 30 THEN '22-30 days'
        ELSE '30+ days'
    END AS delivery_bucket,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score,
    COUNT(*) AS total_orders
FROM order_delivery_view dv
JOIN olist_order_reviews_dataset r ON dv.order_id = r.order_id
GROUP BY 1
ORDER BY avg_review_score DESC;