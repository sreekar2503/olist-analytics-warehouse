-- Grain: one row per product_id. Verified unique across all 32,951 rows.
--
-- Two things this model fixes and one it deliberately does not.
--
-- Fixes: the source misspells `product_name_lenght` and
-- `product_description_lenght`. They are renamed here -- this is the only place
-- in the project where those spellings should appear, and the raw layer keeps
-- them verbatim so the source stays diffable.
--
-- Fixes: every numeric column is stored as text upstream. All values cast
-- cleanly, and weight and dimensions are integral (0 fractional values), so
-- integer is the honest type rather than a float that implies precision the
-- source does not have.
--
-- Does NOT fix: 610 products carry no category AND no name length, description
-- length, or photo count -- they are empty shells with nothing but a
-- product_id. Labelling them is business logic and belongs in dim_products
-- against a declared grain, not here.

with source as (
    select * from {{ source('raw', 'products') }}
)

select
    product_id,
    product_category_name,

    cast(product_name_lenght as integer)        as product_name_length,
    cast(product_description_lenght as integer) as product_description_length,
    cast(product_photos_qty as integer)         as product_photos_qty,

    cast(product_weight_g as integer)           as product_weight_g,
    cast(product_length_cm as integer)          as product_length_cm,
    cast(product_height_cm as integer)          as product_height_cm,
    cast(product_width_cm as integer)           as product_width_cm

from source
