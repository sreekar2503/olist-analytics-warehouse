-- Grain: one row per zip code prefix. 1,000,163 raw rows collapse to 19,011.
-- (The raw table holds 19,015 distinct prefixes; four are dropped entirely by
-- the bounding box below because every one of their points is bad.)
--
-- THE TIE-BREAK, AND WHY IT IS A MEDIAN.
--
-- The raw table holds many coordinate points per prefix, and they disagree.
-- Measured before choosing: the average latitude spread within a prefix is
-- ~16km, but the maximum is ~8,550km, and 344 prefixes span more than 50km.
-- 47 rows sit outside Brazil's bounding box entirely.
--
-- That rules out the mean. One point in the wrong hemisphere drags a prefix's
-- centroid into the ocean, and nothing about the output would look wrong.
--
-- Two defences are applied, and both are stated rather than assumed:
--
--   1. Points outside Brazil's bounding box are excluded. A Brazilian CEP
--      cannot be in another continent, so these are errors rather than
--      outliers, and it removes 36 of 1,000,163 rows -- 0.004%.
--
--      The eastern bound is -28.8, not the -34.8 of the mainland coast. The
--      first version of this model used the mainland figure and silently
--      deleted zip prefix 53990 -- Fernando de Noronha, a Brazilian
--      archipelago at longitude -32.4, and the home of one real customer.
--      A cleaning rule that quietly removes correct data is the failure this
--      project exists to argue against, so the bound now covers Brazil's
--      oceanic islands and the excluded points are only these four:
--      the Canary Islands, Lisbon, the Spain-Portugal border, and the
--      Philippines.
--
--   2. The representative point is the MEDIAN latitude and longitude, not the
--      mean. The median is unmoved by a handful of bad points, which is the
--      whole reason to prefer it here.
--
-- Note: median lat and median lng are computed independently, so the result is
-- not guaranteed to be one of the observed points. For placing a prefix on a
-- map at country scale that is fine; it would not be fine for routing.
--
-- Coverage gap for the ledger: 158 customer zip prefixes and 7 seller zip
-- prefixes have no row in this table at all, so any map built on it silently
-- drops those customers and sellers.

with source as (
    select * from {{ source('raw', 'geolocation') }}
),

bounded as (
    select
        geolocation_zip_code_prefix as zip_prefix,
        cast(geolocation_lat as double) as lat,
        cast(geolocation_lng as double) as lng,
        geolocation_city  as city,
        geolocation_state as state
    from source
    where cast(geolocation_lat as double) between -34.0 and 5.3
      and cast(geolocation_lng as double) between -74.0 and -28.8
)

select
    zip_prefix,
    median(lat)                          as latitude,
    median(lng)                          as longitude,
    mode(city)                           as city,
    mode(state)                          as state,
    count(*)                             as source_point_count
from bounded
group by zip_prefix
