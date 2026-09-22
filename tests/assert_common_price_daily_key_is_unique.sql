-- The merge key must be unique, or the next MERGE fails and consumers double-count.
{{ config(enabled=(target.type == 'athena'), tags=['cross_engine_producer_consumer', 'cross_engine', 'role_producer', 'engine_athena']) }}
select ticker, exchange, trade_date, count(*) as n
from {{ ref('common_price_daily') }}
group by 1, 2, 3
having count(*) > 1
