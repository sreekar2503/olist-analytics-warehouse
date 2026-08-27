-- Grain: one row per Portuguese category name. 71 rows, all distinct.
--
-- This is the governed reference table the source ships with -- and it is
-- incomplete. Two categories in raw.products have no row here:
-- `portateis_cozinha_e_preparadores_de_alimentos` and `pc_gamer`, covering 24
-- order lines and R$5,514 (0.04% of revenue). Small, and stated at its real
-- size rather than inflated.
--
-- The reverse direction is clean: all 71 entries are used by at least one
-- product, so this is a coverage gap, not a mismatch.
--
-- No trimming or case-folding is applied; 0 rows need it on either column.

with source as (
    select * from {{ source('raw', 'product_category_name_translation') }}
)

select
    product_category_name,
    product_category_name_english as product_category_name_en
from source
