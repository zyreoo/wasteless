# Required before implementing persistent commerce

Provide read-only access to the existing Wasteless Supabase project or a schema-only
SQL export (no rows or credentials). The configured project's hostname did not
resolve during implementation; the connected Supabase account showed a different
project. Do not use that unrelated project.

Inspect columns, keys, constraints, grants, RLS flags, policies, triggers and
functions for `product`, `cart`, `cart_items`, `favorite`, `order`, `order_items`,
`merchants`, `offers` and any referenced tables. Confirm the relationship to
`auth.users.id` and how products, prices and availability are represented.

Then implement in this order:

1. Versioned migrations adapting the existing tables, including ownership-based
   RLS for direct Data API access and read-only catalogue grants.
2. Request-scoped, user-token database access plus server-side owner predicates.
   Never share mutable authentication between requests.
3. Product listing/detail, persistent cart and favorite CRUD with typed contracts.
4. Transactional checkout with server prices, price snapshots, row locking and
   an owner-scoped unique idempotency key; clear cart only inside that transaction.
5. Replace temporary authenticated landing with real data in existing design
   components; preserve colors, typography and navigation.
6. Two-account database tests, real auth, restart/session restoration and complete
   product/cart/favorite/order flows on a development database.

No SQL migration is included yet: guessing the schema would violate the requested
compatibility constraint. No live project was modified.
