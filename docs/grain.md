# Declared grain

Written before the marts were built, not after. Every model below states what
one row means, and every claim carries the number that supports it.

Grain is the first thing a reviewer should be able to check and the first thing
that goes wrong quietly. A model whose grain nobody wrote down is a model whose
joins nobody can reason about.

---

## Facts

### `fct_order_items` — one row per order line

The atomic fact. Everything else aggregates up from here.

- **Key:** `order_item_key`, a surrogate over `(order_id, order_line_number)`.
- **Size:** 112,650 rows across 98,666 orders, 32,951 products, 3,095 sellers.
- **Additive measures:** `item_price_brl`, `freight_brl`, `line_total_brl`.

`order_line_number` restarts at 1 within every order and runs to 21. It is not
a global key, and joining on it alone fans out.

**Coverage:** 775 of 99,441 orders have no item rows. Any per-order revenue
figure computed from this table excludes them.

### `fct_orders` — one row per order

Order lifecycle and delivery measures. Money lives in `fct_order_items`; the
order-level totals here are rolled up from it and are **not** additive across
a join back to the line grain.

- **Key:** `order_id`, also a degenerate dimension.
- **Size:** 99,441 rows.

`is_on_time` and `delivery_days` are NULL, not `false` or `0`, when an order has
no delivery timestamp. 2,965 orders have none. Calling those late would move 3%
of the business into the wrong bucket silently.

---

## Dimensions

### `dim_customers` — one row per person

**This is the decision that shaped Phase 2.**

The source has two customer keys and they mean different things:

| Key | Distinct values | What it is |
|---|---:|---|
| `customer_id` | 99,441 | Issued once **per order** |
| `customer_unique_id` | 96,096 | The actual **person** |

Keying this dimension on `customer_id` would produce one row per order and make
every buyer a first-time buyer. 2,997 people ordered more than once (one of
them 17 times) and all of them would disappear.

So the grain is **one row per `customer_unique_id`**, and `fct_orders` carries
`customer_id` as a degenerate dimension for traceability back to the source.

#### Why there is no Type 2 slowly changing dimension here

250 of 96,096 customers (0.26%) have a different zip code across their orders;
122 changed city and 39 changed state. So a slowly changing dimension is not
absent from this data, which is what the build plan assumed. It is present and
small.

It is still not built, for a reason better than size: **the fact table already
preserves address at time of order.** Because `customer_id` is issued per
order, the order's own customer row carries the address as it stood that day.
Point-in-time geography is available through the fact without any effective
dating at all.

A Type 2 dimension would therefore add version rows, surrogate keys and
effective dates to reproduce something the grain already gives us. It would be
the textbook answer and the wrong one.

What *would* require Type 2: an attribute that only exists on the dimension and
changes over time, with no per-event snapshot to fall back on. A customer
loyalty tier, a credit rating, a sales region assignment. This dataset has
none of those.

`dim_customers` is therefore **Type 1** and holds the address from each
customer's most recent order.

### `dim_products` — one row per product

- **Key:** `product_id`. **Size:** 32,951 rows.

Two coverage problems, both surfaced rather than filtered:

- **610 products carry no category and no attributes at all** — no name length,
  no description length, no photo count. They are rows with an id. They get
  `category_status = 'no category in source'`.
- **13 products** have a category the source's own translation table does not
  cover (`portateis_cozinha_e_preparadores_de_alimentos`, `pc_gamer`). They keep
  the Portuguese name and get `category_status = 'no english translation'`.

Neither is dropped. A product excluded from the dimension is revenue excluded
from every category report, and nothing would say so.

### `dim_sellers` — one row per seller

- **Key:** `seller_id`. **Size:** 3,095 rows.

### `dim_geography` — one row per zip code prefix

- **Key:** `zip_prefix`. **Size:** 19,011 rows, reduced from 1,000,163 points.

Representative coordinates are the **median** latitude and longitude, not the
mean: within-prefix spread reaches 8,550km, so a mean lands prefixes in the
ocean. See `stg_geolocation.sql` for the bounding box and the Fernando de
Noronha correction.

**Coverage:** 279 customer rows and 7 seller rows have a zip prefix with no
geolocation entry. They keep their `zip_prefix` and get null coordinates, so a
map drops them but a count does not.

### `dim_dates` — one row per calendar date

Range derived from the order data and padded to whole years. A date dimension
that stops before the facts do drops them silently on an inner join.
