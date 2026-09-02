-- Grain: one row per product. 32,951 rows.
--
-- Nothing is filtered out. Two groups would vanish from a naive inner join to
-- the translation table, and both are kept with an explicit status instead:
--
--   * 610 products have no category AND no other attributes -- no name length,
--     no description length, no photo count. Rows with an id and nothing else.
--     They carry 1.32% of revenue.
--   * 13 products have a category the source's own translation table does not
--     cover. They keep the Portuguese name.
--
-- `category_status` exists so a category report can show what it is missing
-- rather than quietly summing to a smaller number. A product dropped here is
-- revenue dropped from every category breakdown, with nothing to say so.

with products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_category_translation') }}
)

select
    products.product_id                       as product_key,
    products.product_id,

    products.product_category_name            as category_name_pt,
    translation.product_category_name_en      as category_name_en,

    -- The label a report should group by. Never null, so nothing silently
    -- drops out of a GROUP BY.
    coalesce(
        translation.product_category_name_en,
        products.product_category_name,
        '(no category)'
    )                                         as category_label,

    case
        when products.product_category_name is null
            then 'no category in source'
        when translation.product_category_name_en is null
            then 'no english translation'
        else 'translated'
    end                                       as category_status,

    products.product_name_length,
    products.product_description_length,
    products.product_photos_qty,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm,

    products.product_category_name is null    as has_no_attributes

from products
left join translation
    on products.product_category_name = translation.product_category_name
