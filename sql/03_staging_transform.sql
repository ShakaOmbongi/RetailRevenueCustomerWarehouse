drop table if exists stg.retail_transactions;

create table stg.retail_transactions as
with filtered_raw as (
    select *
    from raw.retail_transactions
    where "InvoiceDate" is not null
      and lower(trim("InvoiceDate")) <> 'invoicedate'
),
typed as (
    select
        nullif(trim("InvoiceNo"), '')   as invoice_no,
        nullif(trim("StockCode"), '')   as stock_code,
        nullif(trim("Description"), '') as description,
        nullif(trim("Country"), '')     as country,

        case when trim("Quantity") ~ '^-?\d+$'
             then trim("Quantity")::int
             else null
        end as quantity,

        case when trim("UnitPrice") ~ '^-?\d+(\.\d+)?$'
             then trim("UnitPrice")::numeric(12,4)
             else null
        end as unit_price,

        case when trim("CustomerID") ~ '^\d+(\.0+)?$'
             then floor(trim("CustomerID")::numeric)::bigint
             else null
        end as customer_id,

        case
            when trim("InvoiceDate") ~ '^\d{4}-\d{2}-\d{2} ' then trim("InvoiceDate")::timestamp
            when trim("InvoiceDate") ~ '^\d{1,2}/\d{1,2}/\d{4} ' then to_timestamp(trim("InvoiceDate"), 'MM/DD/YYYY HH24:MI')
            else null
        end as invoice_ts
    from filtered_raw
),
deduped as (
    select distinct
        invoice_no, stock_code, description, quantity, invoice_ts, unit_price, customer_id, country
    from typed
    where invoice_no is not null
      and stock_code is not null
      and invoice_ts is not null
      and quantity is not null
      and unit_price is not null
)
select
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_ts as invoice_date,
    unit_price,
    customer_id,
    country,

    (quantity * unit_price)::numeric(14,4) as sales_amount,
    invoice_ts::date                       as order_date,
    date_trunc('month', invoice_ts)::date  as order_month,
    (quantity < 0)                         as is_return,
    (invoice_no ilike 'c%')                as is_cancellation,
    (customer_id is null)                  as is_guest_checkout
from deduped;

create index if not exists ix_stg_order_month on stg.retail_transactions(order_month);
create index if not exists ix_stg_customer    on stg.retail_transactions(customer_id);
create index if not exists ix_stg_invoice     on stg.retail_transactions(invoice_no);
create index if not exists ix_stg_stock       on stg.retail_transactions(stock_code);