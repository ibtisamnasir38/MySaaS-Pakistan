-- Lets a category exist without appearing in storefront nav, the shop listing, or
-- filter facets, while staying reachable via its own direct URL.
ALTER TABLE "Category" ADD COLUMN IF NOT EXISTS "isHidden" BOOLEAN NOT NULL DEFAULT false;
