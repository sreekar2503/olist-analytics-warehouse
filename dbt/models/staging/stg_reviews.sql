-- Grain: one row per (review_id, order_id).
--
-- THE DECISION THIS MODEL EXISTS TO DOCUMENT.
--
-- `review_id` is not unique: 789 of them appear on more than one row, covering
-- 1,603 rows in total. The obvious reading is "duplicate data", and the obvious
-- fix -- deduplicate on review_id -- would be wrong.
--
-- Checked before choosing: each of those 789 review_ids carries exactly ONE
-- distinct review_score (789 ids, 789 id/score pairs). So these are not
-- conflicting reviews of the same order. They are a single review attached to
-- several orders -- one customer, one survey response, several order records.
--
-- That makes (review_id, order_id) the real grain, and it is verified unique:
-- 99,224 rows, 99,224 distinct pairs, 0 duplicate pairs.
--
-- The consequence downstream is what matters. Joining reviews to orders on
-- review_id alone fans out. Averaging review_score over this table counts those
-- 789 reviews once per order they touch, which is correct for "average score
-- per order" and wrong for "average score per review". The metric dictionary
-- has to say which one it means.

with source as (
    select * from {{ source('raw', 'order_reviews') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }}
                                                as review_order_key,
    review_id,
    order_id,

    cast(review_score as integer)               as review_score,

    review_comment_title,
    review_comment_message,

    -- 88% of rows have no title and 59% have no message. A count of reviews is
    -- not a count of written feedback, and these flags keep that visible
    -- instead of leaving it to whoever writes the WHERE clause.
    review_comment_title is not null            as has_comment_title,
    review_comment_message is not null          as has_comment_message,

    cast(review_creation_date as timestamp)     as review_created_at,
    cast(review_answer_timestamp as timestamp)  as review_answered_at

from source
