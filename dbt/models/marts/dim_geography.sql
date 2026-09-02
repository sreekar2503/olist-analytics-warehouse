-- Grain: one row per zip code prefix. 19,011 rows.
--
-- Coordinates are medians over the raw points, computed in stg_geolocation --
-- see that model for why a mean would put prefixes in the ocean.

with geo as (
    select * from {{ ref('stg_geolocation') }}
)

select
    zip_prefix           as geography_key,
    zip_prefix,
    city,
    state,
    latitude,
    longitude,
    source_point_count
from geo
