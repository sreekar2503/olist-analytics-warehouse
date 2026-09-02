-- Grain: one row per order line. The atomic fact -- everything else
-- aggregates up from here. 112,650 rows.
--
-- Joins to orders are INNER because every order_item row has a matching order
-- (0 orphans, verified in docs/profile_raw.md). The reverse is not true: 775
-- orders have no item rows and therefore do not appear here at all.
--
-- customer_key is the person, resolved through stg_customers, so this fact
-- joins to dim_customers rather than to a per-order pseudo-customer.

with items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select customer_id, customer_unique_id from {{ ref('stg_customers') }}
)

select
    items.order_item_key,

    -- Degenerate dimensions: kept on the fact, no dimension table of their own.
    items.order_id,
    items.order_line_number,

    -- Foreign keys.
    items.product_id                          as product_key,
    items.seller_id                           as seller_key,
    customers.customer_unique_id              as customer_key,
    cast(orders.purchased_at as date)         as order_date,

    orders.order_status,
    items.shipping_limit_at,

    -- Additive measures.
    items.item_price_brl,
    items.freight_brl,
    items.item_price_brl + items.freight_brl  as line_total_brl

from items
inner join orders    on items.order_id = orders.order_id
inner join customers on orders.customer_id = customers.customer_id
