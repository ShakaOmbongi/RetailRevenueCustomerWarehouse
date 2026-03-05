

create schema if not exists dw;


drop table if exists dw.dim_date;

create table dw.dim_date (
  date_key        int primary key,     
  full_date       date not null,
  year            int not null,
  quarter         int not null,
  month           int not null,
  month_name      text not null,
  day             int not null,
  day_of_week     int not null,          
  day_name        text not null,
  week_of_year    int not null,
  is_weekend      boolean not null
);

insert into dw.dim_date (
  date_key, full_date, year, quarter, month, month_name, day,
  day_of_week, day_name, week_of_year, is_weekend
)
select
  (extract(year from d)::int * 10000
   + extract(month from d)::int * 100
   + extract(day from d)::int) as date_key,
  d as full_date,
  extract(year from d)::int as year,
  extract(quarter from d)::int as quarter,
  extract(month from d)::int as month,
  to_char(d, 'Mon') as month_name,
  extract(day from d)::int as day,
  extract(isodow from d)::int as day_of_week,
  to_char(d, 'Dy') as day_name,
  extract(week from d)::int as week_of_year,
  (extract(isodow from d)::int in (6,7)) as is_weekend
from generate_series(
    (select min(order_date) from stg.retail_transactions),
    (select max(order_date) from stg.retail_transactions),
    interval '1 day'
) as gs(d);

create index if not exists ix_dim_date_full_date on dw.dim_date(full_date);


drop table if exists dw.dim_customer;

create table dw.dim_customer (
  customer_key        bigserial primary key,
  customer_id         bigint unique,          
  first_purchase_date date,
  last_purchase_date  date,
  country             text
);

insert into dw.dim_customer (customer_id, first_purchase_date, last_purchase_date, country)
select
  customer_id,
  min(order_date) as first_purchase_date,
  max(order_date) as last_purchase_date,
  max(country)    as country
from stg.retail_transactions
where customer_id is not null
group by customer_id;

create index if not exists ix_dim_customer_customer_id on dw.dim_customer(customer_id);


drop table if exists dw.dim_product;

create table dw.dim_product (
  product_key   bigserial primary key,
  stock_code    text not null,
  description   text,
  is_active     boolean not null default true,
  constraint uq_dim_product_stock_code unique(stock_code)
);

insert into dw.dim_product (stock_code, description)
select
  stock_code,
  max(description) as description
from stg.retail_transactions
where stock_code is not null
group by stock_code;

create index if not exists ix_dim_product_stock_code on dw.dim_product(stock_code);