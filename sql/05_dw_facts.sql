

create schema if not exists dw;

drop table if exists dw.fact_order_items;

create table dw.fact_order_items (
  order_item_key   bigserial primary key,

  invoice_no       text not null,

  date_key         int not null references dw.dim_date(date_key),
  customer_key     bigint references dw.dim_customer(customer_key),
  product_key      bigint not null references dw.dim_product(product_key),

  country          text,
  quantity         int not null,
  unit_price       numeric(12,4) not null,
  sales_amount     numeric(14,4) not null,
  is_return        boolean not null,
  is_cancellation  boolean not null
);

insert into dw.fact_order_items (
  invoice_no, date_key, customer_key, product_key,
  country, quantity, unit_price, sales_amount,
  is_return, is_cancellation
)
select
  s.invoice_no,
  (extract(year from s.order_date)::int * 10000
   + extract(month from s.order_date)::int * 100
   + extract(day from s.order_date)::int) as date_key,
  c.customer_key,
  p.product_key,
  s.country,
  s.quantity,
  s.unit_price,
  s.sales_amount,
  s.is_return,
  s.is_cancellation
from stg.retail_transactions s
join dw.dim_product p
  on p.stock_code = s.stock_code
left join dw.dim_customer c
  on c.customer_id = s.customer_id;

create index if not exists ix_fact_order_items_date_key on dw.fact_order_items(date_key);
create index if not exists ix_fact_order_items_customer_key on dw.fact_order_items(customer_key);
create index if not exists ix_fact_order_items_product_key on dw.fact_order_items(product_key);
create index if not exists ix_fact_order_items_invoice on dw.fact_order_items(invoice_no);