-- Grain: one row per order. Additive measures live in fct_order_items; this
-- table carries the order lifecycle and its derived delivery measures.
--
-- Two deliberate choices, both about what a NULL means here:
--
--   * `is_on_time` is NULL, not false, when an order has no delivery timestamp.
--     Calling an undelivered order "late" would quietly move ~3,000 orders into
--     the numerator's complement and make the on-time rate look worse than the
--     evidence supports. Undelivered is unknown, and unknown is NULL.
--
--   * `delivery_days` is likewise NULL rather than 0 where either endpoint is
--     missing, so an average over it excludes those orders instead of dragging
--     toward zero.

with orders as (
    select * from {{ ref('stg_orders') }}
)

select
    order_id,                                        -- degenerate dimension
    customer_id,
    order_status,

    cast(purchased_at as date)                       as order_date,
    purchased_at,
    approved_at,
    delivered_to_carrier_at,
    delivered_to_customer_at,
    estimated_delivery_at,

    order_status = 'delivered'                       as is_delivered,

    date_diff('day', purchased_at, delivered_to_customer_at)
                                                     as delivery_days,
    date_diff('day', purchased_at, estimated_delivery_at)
                                                     as estimated_delivery_days,

    -- Positive = later than promised.
    date_diff('day', estimated_delivery_at, delivered_to_customer_at)
                                                     as delivery_lateness_days,

    case
        when delivered_to_customer_at is null then null
        else delivered_to_customer_at <= estimated_delivery_at
    end                                              as is_on_time

from orders
