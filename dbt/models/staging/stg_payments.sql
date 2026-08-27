-- Grain: one row per (order_id, payment_sequential). An order can be paid with
-- several instruments -- a voucher plus a card, say -- so this is NOT one row
-- per order and summing payment_value against an order-level join will
-- double-count unless the grain is respected.
--
-- Three things worth knowing about this table:
--
--   * `payment_type` includes the literal string 'not_defined' on 3 rows. That
--     is a NULL wearing a costume: it survives every not_null test while
--     meaning exactly what NULL means. It is preserved verbatim rather than
--     converted, because a validity test that names it is more useful than a
--     silent coalesce -- and because rewriting it here would hide the one row
--     type most worth seeing.
--
--   * 9 payments have a value of 0.00, and payment_installments runs from 0 to
--     24. Zero installments on a non-zero payment is not obviously meaningful.
--
--   * 99,440 of 99,441 orders have a payment row. Exactly one order has none,
--     so any revenue figure built from this table excludes it.
--
-- All values cast cleanly (0 failures across 103,886 rows).

with source as (
    select * from {{ source('raw', 'order_payments') }}
)

select
    order_id,
    cast(payment_sequential as integer)   as payment_sequence_number,
    payment_type,
    cast(payment_installments as integer) as payment_installments,
    cast(payment_value as decimal(10, 2)) as payment_brl
from source
