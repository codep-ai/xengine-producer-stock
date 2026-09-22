{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    unique_key           = ['ticker', 'exchange', 'trade_date'],
    on_schema_change     = 'append_new_columns'
) }}
-- The shared price table every consumer reads. Carries BOTH the native close and the USD close, plus the rate used,
-- so no consumer ever has to guess which currency a number is in.
--
-- INCREMENTAL MERGE ON PURPOSE (2026-09-21). A `table` model is rebuilt by DROP + CREATE on Athena, which gives the Iceberg table a
-- new UUID and folder every run. Engines that follow a table by identity (Snowflake auto-refresh, Databricks) then stop following and
-- serve the old snapshot silently. A merge keeps ONE table identity and adds snapshots, so consumers follow it with no sync step,
-- and Iceberg history / time travel survive. Each run re-merges the last {{ var('price_reprocess_days', 7) }} days (late corrections).
-- `dbt build --full-refresh` recreates the table (new UUID) — run `xengine.py snowflake-sync` afterwards.
{% set reprocess_days = var('price_reprocess_days', 7) %}
{% set fx_lookback_days = var('price_fx_lookback_days', 30) %}   {# extra history so the FX carry-forward has a rate to carry #}
with px as (
    select
        split_part(p.ticker, '.', 1) as ticker,
        upper(trim(p.exchange))      as exchange,
        p.trade_date,
        p.close,
        p.volume
    from {{ source('stock_raw', 'prices') }} p
    -- Keep rows with a usable price. Written as an expression ON PURPOSE: a plain `close is not null` / `close > 0`
    -- is pushed down to the Parquet min/max statistics, and Athena rejects this Snowflake-written file with
    -- ICEBERG_BAD_DATA "Corrupted statistics for column close" (file stores float, Iceberg schema says double).
    where coalesce(p.close, -1) > 0
    {% if is_incremental() %}
      and p.trade_date >= (select date_add('day', -{{ reprocess_days + fx_lookback_days }}, max(trade_date)) from {{ this }})
    {% endif %}
),
dedup as (
    -- Raw can hold BHP.AX and BHP for the same day; conforming maps both to one key (44 rows of 8.1M on 2026-09-21).
    -- One row per key, by a fixed rule (highest volume, then highest close), because a MERGE must not see duplicate keys.
    select * from (
        select px.*, row_number() over (partition by ticker, exchange, trade_date order by volume desc nulls last, close desc) as rn
        from px
    ) where rn = 1
),
fx as (
    select trade_date, currency_code, units_per_usd from {{ ref('common_fx_daily') }}
),
joined as (
    select
        d.ticker, d.exchange, d.trade_date, e.currency_code,
        d.close, d.volume,
        case when e.currency_code = 'USD' then 1.0 else fx.units_per_usd end as rate_on_day
    from dedup d
    join {{ ref('common_exchange') }} e on e.exchange = d.exchange
    left join fx on fx.trade_date = d.trade_date and fx.currency_code = e.currency_code
),
filled as (
    -- markets trade on days FX does not publish: carry the last known rate forward, per currency
    select *,
        coalesce(rate_on_day,
                 last_value(rate_on_day) ignore nulls over (
                     partition by currency_code order by trade_date
                     rows between unbounded preceding and current row)) as units_per_usd
    from joined
)
select
    ticker, exchange, trade_date, currency_code,
    close,
    units_per_usd,
    close / units_per_usd as close_usd,
    cast(volume as double) as volume
from filled
{% if is_incremental() %}
where trade_date >= (select date_add('day', -{{ reprocess_days }}, max(trade_date)) from {{ this }})
{% endif %}
