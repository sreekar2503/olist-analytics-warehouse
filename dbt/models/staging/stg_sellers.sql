-- Grain: one row per seller_id. Verified unique across all 3,095 rows.
--
-- seller_zip_code_prefix stays VARCHAR for the same reason as in
-- stg_customers: five-character CEP prefixes that may begin with 0.
--
-- City and state values arrive already lower/upper cased consistently (0 rows
-- deviate in either table), so no normalisation is applied. Cleaning that isn't
-- needed is still a transformation someone has to trust.

with source as (
    select * from {{ source('raw', 'sellers') }}
)

select
    seller_id,
    seller_zip_code_prefix as seller_zip_prefix,
    seller_city,
    seller_state
from source
