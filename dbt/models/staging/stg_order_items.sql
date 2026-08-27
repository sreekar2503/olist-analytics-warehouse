-- Grain: one row per (order_id, order_item_id).
--
-- order_item_id is a sequence WITHIN an order, not a global key -- it restarts
-- at 1 for every order and runs to a maximum of 21. Joining on it alone fans
-- out. The surrogate key below is what downstream models should use.
--
-- Note for the coverage ledger: this table covers 98,666 of the 99,441 orders.
-- 775 orders have no item rows at all, so any per-order revenue figure computed
-- from here silently excludes them.
--
-- All prices, freight values and shipping timestamps cast cleanly (0 failures
-- across 112,650 rows), so `cast` is used rather than `try_cast`.

with source as (
    select * from {{ source('raw', 'order_items') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }}
                                              as order_item_key,
    order_id,
    cast(order_item_id as integer)            as order_line_number,
    product_id,
    seller_id,

    cast(shipping_limit_date as timestamp)    as shipping_limit_at,
    cast(price as decimal(10, 2))             as item_price_brl,
    cast(freight_value as decimal(10, 2))     as freight_brl

from source
