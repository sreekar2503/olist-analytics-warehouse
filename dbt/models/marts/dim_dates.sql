-- Grain: one row per calendar date.
--
-- Range is derived from the fact data rather than hardcoded, and padded to whole
-- years so that partial-year edges are visible as low counts rather than absent
-- rows. A date dimension that stops before the data does produces silently
-- dropped facts on an inner join.

with bounds as (
    select
        date_trunc('year', min(purchased_at))::date              as start_date,
        (date_trunc('year', max(purchased_at)) + interval 1 year
            - interval 1 day)::date                              as end_date
    from {{ ref('stg_orders') }}
),

calendar as (
    select unnest(generate_series(
        (select start_date from bounds),
        (select end_date from bounds),
        interval 1 day
    ))::date as date_day
)

select
    date_day,
    cast(strftime(date_day, '%Y%m%d') as integer) as date_key,
    extract(year from date_day)                   as year_number,
    extract(quarter from date_day)                as quarter_number,
    extract(month from date_day)                  as month_number,
    strftime(date_day, '%Y-%m')                   as year_month,
    strftime(date_day, '%B')                      as month_name,
    extract(day from date_day)                    as day_of_month,
    extract(dayofweek from date_day)              as day_of_week,   -- 0 = Sunday
    strftime(date_day, '%A')                      as day_name,
    extract(dayofweek from date_day) in (0, 6)    as is_weekend
from calendar
