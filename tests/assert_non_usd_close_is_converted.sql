-- Guards the defect found 2026-09-19 in fct_daily_price, where `close` was silently a copy of `close_usd`.
-- For any non-USD currency with a rate that is not 1, the native close and the USD close must differ.
{{ config(enabled=(target.type == 'athena'), tags=['cross_engine_producer_consumer', 'cross_engine', 'role_producer', 'engine_athena']) }}
select ticker, exchange, trade_date, currency_code, close, close_usd, units_per_usd
from {{ ref('common_price_daily') }}
where currency_code <> 'USD'
  and units_per_usd is not null and abs(units_per_usd - 1.0) > 0.0001
  and close <> 0
  and abs(close_usd - close) < 1e-9
