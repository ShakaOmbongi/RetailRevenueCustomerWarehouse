
select
  sum(sales_amount) as total_gross_revenue
from dw.fact_order_items
where is_cancellation = false
  and is_return = false;

select
  sum(sales_amount) as total_net_revenue
from dw.fact_order_items
where is_cancellation = false;

select
  d.year,
  d.month,
  date_trunc('month', d.full_date)::date as revenue_month,
  sum(f.sales_amount) as net_revenue
from dw.fact_order_items f
join dw.dim_date d on d.date_key = f.date_key
where f.is_cancellation = false
group by d.year, d.month, revenue_month
order by revenue_month;

with monthly as (
  select
    date_trunc('month', d.full_date)::date as revenue_month,
    sum(f.sales_amount) as net_revenue
  from dw.fact_order_items f
  join dw.dim_date d on d.date_key = f.date_key
  where f.is_cancellation = false
  group by 1
)
select
  revenue_month,
  net_revenue,
  lag(net_revenue) over (order by revenue_month) as prior_month_revenue,
  round(
    100.0 * (net_revenue - lag(net_revenue) over (order by revenue_month))
    / nullif(lag(net_revenue) over (order by revenue_month), 0)
  , 2) as mom_growth_pct
from monthly
order by revenue_month;

with orders as (
  select
    invoice_no,
    sum(sales_amount) as order_net_revenue
  from dw.fact_order_items
  where is_cancellation = false
  group by invoice_no
)
select
  round(avg(order_net_revenue), 2) as aov_net
from orders;

select
  coalesce(country, 'Unknown') as country,
  sum(sales_amount) as net_revenue
from dw.fact_order_items
where is_cancellation = false
group by 1
order by net_revenue desc;

select
  p.stock_code,
  p.description,
  sum(f.sales_amount) as net_revenue
from dw.fact_order_items f
join dw.dim_product p on p.product_key = f.product_key
where f.is_cancellation = false
group by p.stock_code, p.description
order by net_revenue desc
limit 20;

with customer_orders as (
  select
    customer_key,
    count(distinct invoice_no) as order_count
  from dw.fact_order_items
  where is_cancellation = false
    and customer_key is not null
  group by customer_key
)
select
  round(
    100.0 * count(*) filter (where order_count >= 2) / nullif(count(*), 0)
  , 2) as repeat_purchase_rate_pct
from customer_orders;

with customer_revenue as (
  select
    customer_key,
    sum(sales_amount) as net_revenue
  from dw.fact_order_items
  where is_cancellation = false
    and customer_key is not null
  group by customer_key
),
ranked as (
  select
    customer_key,
    net_revenue,
    ntile(10) over (order by net_revenue desc) as decile
  from customer_revenue
)
select
  round(100.0 * sum(net_revenue) filter (where decile = 1) / nullif(sum(net_revenue),0), 2)
    as top_10pct_revenue_share_pct
from ranked;

with first_month as (
  select
    customer_key,
    min(date_trunc('month', d.full_date)::date) as cohort_month
  from dw.fact_order_items f
  join dw.dim_date d on d.date_key = f.date_key
  where f.is_cancellation = false
    and f.customer_key is not null
  group by customer_key
),
activity as (
  select
    f.customer_key,
    date_trunc('month', d.full_date)::date as activity_month
  from dw.fact_order_items f
  join dw.dim_date d on d.date_key = f.date_key
  where f.is_cancellation = false
    and f.customer_key is not null
  group by f.customer_key, activity_month
),
cohorts as (
  select
    fm.cohort_month,
    a.activity_month,
    (extract(year from a.activity_month) - extract(year from fm.cohort_month)) * 12
      + (extract(month from a.activity_month) - extract(month from fm.cohort_month)) as months_since_first
  from first_month fm
  join activity a on a.customer_key = fm.customer_key
)
select
  cohort_month,
  months_since_first,
  count(*) as active_customers
from cohorts
group by cohort_month, months_since_first
order by cohort_month, months_since_first;