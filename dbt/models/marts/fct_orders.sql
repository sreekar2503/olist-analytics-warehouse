-- Grain: one row per order. 99,441 rows.
--
-- Carries the order lifecycle and its derived delivery measures. Money is
-- rolled up from fct_order_items and is NOT additive across a join back down
-- to the line grain -- summing order_total_brl after joining to items
-- multiplies it by the line count.
--
-- Two choices about what NULL means here:
--
--   * is_on_time is NULL, not false, when an order has no delivery timestamp.
--     Calling 2,965 undelivered orders "late" would move 3% of the business
--     into the wrong bucket and nothing would report it.
--
--   * delivery_days is NULL rather than 0 where either endpoint is missing, so
--     an average over it excludes those orders instead of dragging toward zero.
--
-- customer_geography_key is the address as it stood ON THIS ORDER, taken from
-- the order's own per-order customer row. That is what makes a Type 2
-- dimension unnecessary: point-in-time geography lives on the fact. See
-- docs/grain.md.

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

-- 775 orders have no item rows, so this is a LEFT join and their money
-- measures are NULL rather than 0. Zero would read as a free order.
item_rollup as (
    select
        order_id,
        count(*)                                   as item_count,
        count(distinct product_id)                 as distinct_product_count,
        count(distinct seller_id)                  as distinct_seller_count,
        sum(item_price_brl)                        as gross_item_brl,
        sum(freight_brl)                           as freight_brl,
        sum(item_price_brl) + sum(freight_brl)     as order_total_brl
    from {{ ref('stg_order_items') }}
    group by order_id
)

select
    orders.order_id,

    -- Foreign keys.
    customers.customer_unique_id                     as customer_key,
    customers.customer_zip_prefix                    as customer_geography_key,
    cast(orders.purchased_at as date)                as order_date,

    -- Degenerate: the per-order customer identifier, kept for traceability.
    orders.customer_id,
    orders.order_status,

    orders.purchased_at,
    orders.approved_at,
    orders.delivered_to_carrier_at,
    orders.delivered_to_customer_at,
    orders.estimated_delivery_at,

    orders.order_status = 'delivered'                as is_delivered,
    item_rollup.order_id is null                     as has_no_items,

    item_rollup.item_count,
    item_rollup.distinct_product_count,
    item_rollup.distinct_seller_count,
    item_rollup.gross_item_brl,
    item_rollup.freight_brl,
    item_rollup.order_total_brl,

    date_diff('day', orders.purchased_at, orders.delivered_to_customer_at)
                                                     as delivery_days,
    date_diff('day', orders.purchased_at, orders.estimated_delivery_at)
                                                     as estimated_delivery_days,

    -- Positive = later than promised.
    date_diff('day', orders.estimated_delivery_at, orders.delivered_to_customer_at)
                                                     as delivery_lateness_days,

    case
        when orders.delivered_to_customer_at is null then null
        else orders.delivered_to_customer_at <= orders.estimated_delivery_at
    end                                              as is_on_time

from orders
inner join customers on orders.customer_id = customers.customer_id
left join item_rollup on orders.order_id = item_rollup.order_id
