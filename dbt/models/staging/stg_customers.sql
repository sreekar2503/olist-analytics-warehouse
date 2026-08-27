-- Grain: one row per customer_id.
--
-- IMPORTANT: `customer_id` is not a customer. It is issued once per order.
-- 99,441 customer_id values map to 96,096 customer_unique_id values, so 3,345
-- orders come from people who had ordered before. A dim_customers keyed on
-- customer_id would therefore be a one-row-per-order "dimension" and would
-- silently make every customer a first-time buyer.
--
-- Both keys are kept here and the choice is made in the mart, where it can be
-- documented against a declared grain.
--
-- customer_zip_code_prefix stays VARCHAR. All 99,441 values are exactly five
-- characters; Brazilian CEP prefixes can begin with 0, and casting to an
-- integer would silently destroy those.

with source as (
    select * from {{ source('raw', 'customers') }}
)

select
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix as customer_zip_prefix,
    customer_city,
    customer_state
from source
