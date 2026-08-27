-- Grain: one row per order_id. Verified unique in docs/profile_raw.md.
--
-- Casting is explicit because the raw layer is all VARCHAR. All five timestamp
-- columns cast cleanly for every non-null value (0 failures across 99,441 rows,
-- checked before this model was written) -- so `cast` is used rather than
-- `try_cast`. If the source ever ships an unparseable timestamp, this model
-- should fail loudly rather than quietly produce a NULL that later reads as
-- "never delivered".

with source as (
    select * from {{ source('raw', 'orders') }}
)

select
    order_id,
    customer_id,
    order_status,

    cast(order_purchase_timestamp as timestamp)      as purchased_at,
    cast(order_approved_at as timestamp)             as approved_at,
    cast(order_delivered_carrier_date as timestamp)  as delivered_to_carrier_at,
    cast(order_delivered_customer_date as timestamp) as delivered_to_customer_at,
    cast(order_estimated_delivery_date as timestamp) as estimated_delivery_at

from source
