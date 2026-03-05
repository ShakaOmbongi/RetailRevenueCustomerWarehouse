drop table if exists raw.retail_transactions;

create table raw.retail_transactions (
  "InvoiceNo"   text,
  "StockCode"   text,
  "Description" text,
  "Quantity"    text,
  "InvoiceDate" text,
  "UnitPrice"   text,
  "CustomerID"  text,
  "Country"     text
);