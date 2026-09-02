-- Grain: one row per customer_unique_id, the actual person.
--
-- NOT one row per customer_id. The source issues customer_id per order, so
-- keying on it would give 99,441 rows instead of 96,096 people, and make every
-- buyer a first-time buyer, erasing the 2,997 who ordered more than once.
--
-- Type 1: the address held here is the one from the customer's most recent
-- order. 250 customers (0.26%) moved between orders, and that history is not
-- kept here because it does not need to be -- fct_orders carries customer_id,
-- whose own row holds the address as it stood on the order date. Point-in-time
-- geography comes from the fact, not from version rows in the dimension.
--
-- See docs/grain.md for why a Type 2 dimension would be the textbook answer
-- and the wrong one.

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select customer_id, purchased_at from {{ ref('stg_orders') }}
),

-- Rank each person's orders so "most recent address" is a stated rule rather
-- than whichever row the engine happened to return.
ranked as (
    select
        customers.customer_unique_id,
        customers.customer_id,
        customers.customer_zip_prefix,
        customers.customer_city,
        customers.customer_state,
        orders.purchased_at,
        row_number() over (
            partition by customers.customer_unique_id
            order by orders.purchased_at desc, customers.customer_id
        ) as recency_rank
    from customers
    left join orders using (customer_id)
),

aggregated as (
    select
        customer_unique_id,
        count(*)          as order_count,
        min(purchased_at) as first_ordered_at,
        max(purchased_at) as last_ordered_at
    from ranked
    group by customer_unique_id
)

select
    ranked.customer_unique_id                as customer_key,
    ranked.customer_zip_prefix               as customer_zip_prefix,
    ranked.customer_city                     as customer_city,
    ranked.customer_state                    as customer_state,

    aggregated.order_count,
    aggregated.order_count > 1               as is_repeat_customer,
    aggregated.first_ordered_at,
    aggregated.last_ordered_at

from ranked
inner join aggregated using (customer_unique_id)
where ranked.recency_rank = 1
