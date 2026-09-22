{{ config(materialized='incremental', incremental_strategy='merge', unique_key=['trade_date', 'currency_code'], on_schema_change='append_new_columns') }}
-- Merge, not rebuild: keeps ONE Iceberg table identity so Snowflake / Databricks follow it with no sync (see common_price_daily.sql).
-- Reference table: every run merges the full (small) source. Rows that vanish from the source are kept, not deleted.
-- Daily FX, expressed as "units of currency per 1 USD" (USD/AUD = 1.38 means 1 USD buys 1.38 AUD).
select
    try_cast(substr(trade_date, 1, 10) as date) as trade_date,
    upper(trim(quote_currency))                 as currency_code,
    cast(rate as double)                        as units_per_usd
from {{ source('stock_raw', 'fx_rates_daily') }}
where upper(trim(base_currency)) = 'USD'
  and rate is not null and rate > 0
