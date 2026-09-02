-- Grain: one row per seller. 3,095 rows, verified unique.

with sellers as (
    select * from {{ ref('stg_sellers') }}
)

select
    seller_id            as seller_key,
    seller_id,
    seller_zip_prefix,
    seller_city,
    seller_state
from sellers
