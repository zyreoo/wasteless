# Customer and merchant simulation

Authenticated `/business` creates the current user's merchant profile. The button
“Adaugă cele 4 produse fictive” seeds four clearly marked test offers once per
merchant. Products, stock and orders persist in Supabase and are shared across
accounts. No payment is processed and no real collection should be expected.

1. Merchant: create profile, seed offers, edit price/stock or hide an offer.
2. Customer: browse catalog or merchant map, add available offers from one merchant
   to cart, then submit the order. Stock is reserved atomically.
3. Merchant: refresh orders, accept and mark ready for pickup.
4. Customer: open order details and provide the pickup code.
5. Merchant: enter the code to complete collection.

Either participant can cancel before collection with a reason. Cancellation restores
stock exactly once. Customers cannot advance merchant statuses; other merchants
cannot edit offers or manage orders they do not own. Changes appear on refresh.
Existing unassigned legacy products are preserved; use the newly seeded offers to
exercise merchant fulfillment.

Migration: `20260930190954_merchant_order_lifecycle.sql`. Applied to the Wasteless
project with explicit user approval. Live lifecycle checks ran inside a rolled-back
transaction; they did not leave test identities or orders behind.
