# Wasteless database migration review

Project: `ueurvamkhwkgoydplnfe` (WasteLess), PostgreSQL 17.
Schema inspected once ACTIVE_HEALTHY. During startup queries briefly returned
incomplete catalogues; only the healthy snapshot was used for implementation.

## Applied migrations

1. `20260928173209_wasteless_commerce.sql`
   - Corrects cart_items' erroneous cart_id → product foreign key; establishes the
     product_id relationship and cart/product uniqueness.
   - Adds favorite ownership, decimal prices, product availability/category,
     order status/idempotency/subtotal and historical order-item names/prices.
   - Adds constraints and indexes, enables owner-scoped SELECT policies, revokes
     anonymous reads and direct authenticated writes on commerce tables.
   - Exposes invoker RPC wrappers backed by private, fixed-search-path functions.
     Every privileged function checks auth.uid(); cart mutation/checkout serialize
     by owner, checkout locks product stock in stable ID order. Functions cannot
     be called anonymously. No privileged key is embedded in the client.
2. `20260928173220_wasteless_legacy_access.sql`
   - Enables RLS and revokes anon/authenticated access on unused `tebelenoi.cart`.
   - Revokes public execution of the legacy `rls_auto_enable` helper when present.

Both migrations were applied successfully on 2026-09-28 after explicit user
approval. Initial automatic-review rejections made no database changes. Remote
versions are 20260928173209 and 20260928173220; local filenames now match them.
Post-application checks confirm six commerce SELECT policies, RLS enabled,
anonymous table/function access denied, and direct authenticated inserts denied.
Business-row counts remain unchanged, including the unowned legacy favorite and
two products with unknown stock.

## Existing data preservation

Read-only counts: cart=1, cart_items=2, favorite=1, product=2, order=0,
order_items=0. Products `mar` and `para` have NULL stock. Their values remain intact;
RLS excludes incomplete products from the customer catalogue. The unowned legacy
favorite is retained with NULL owner and is invisible to users. New rows must meet
the complete ownership/product constraints. Existing unknown ownership is not
inferred from whichever administrator applies the migration.

Constraints marked NOT VALID preserve incomplete legacy rows while validating new
writes. Review and complete old records with real business information before
validating those constraints. Do not assign invented stock or owners.

The migration expects the inspected schema, including empty order/order_items;
on incompatible historical data it fails transactionally rather than deleting or
silently backfilling information. Take a backup before deployment. Deploy API and
Flutter after migrations; verify schema cache refresh and test with separate
non-production users before release.

## Remote security findings

- Resolved: `tebelenoi.cart` previously had RLS disabled: [Supabase remediation](https://supabase.com/docs/guides/database/database-linter?lint=0013_rls_disabled_in_public).
- Six commerce tables now have appropriate SELECT policies. Unused legacy tables
  remain closed to ordinary users by RLS.
- Resolved: public execution of the legacy security-definer helper is revoked.
- Leaked-password protection is disabled in Supabase Auth. Review availability and
  enable it in project settings: [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

Post-migration security advisors report only the existing leaked-password warning
and informational notices for 15 unused tables with RLS and no policies. Non-MVP tables
remain closed by RLS rather than adding broad policies for unused features.

## Validation completed on 2026-09-28

- Supabase Management API confirmed `ACTIVE_HEALTHY`.
- 27 Python API tests passed; 47 Flutter tests passed, including protected routing
  and removal of account data/navigation on logout.
- 31 isolated PostgreSQL checks passed against the captured legacy schema.
- Flutter analyzer reports 13 informational findings in legacy files; no errors
  or warnings. These are naming, print calls, deprecated color APIs and an old
  async-context use, outside the production commerce routes.
- Live checkout remains unverified pending real stock and an authenticated end-to-end session.
