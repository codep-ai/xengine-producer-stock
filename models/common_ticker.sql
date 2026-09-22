{{ config(materialized='incremental', incremental_strategy='merge', unique_key=['ticker_raw', 'exchange'], on_schema_change='append_new_columns') }}
-- Merge, not rebuild: keeps ONE Iceberg table identity so Snowflake / Databricks follow it with no sync (see common_price_daily.sql).
-- Reference table: every run merges the full (small) source. Rows that vanish from the source are kept, not deleted.
-- Conformed ticker: sources disagree on the symbol (BHP.AX vs BHP). One business key, the raw symbol kept for audit.
select
    split_part(ticker, '.', 1)  as ticker,
    ticker                      as ticker_raw,
    upper(trim(exchange))       as exchange,
    company_name,
    sector,
    asset_type,
    region,
    is_active
from {{ source('stock_raw', 'ticker_universe') }}
