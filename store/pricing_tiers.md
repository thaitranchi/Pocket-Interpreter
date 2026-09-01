# Pricing — Pocket Interpreter

## Business model

**Free (with ads) + Pro one-time purchase ("Pay once, own forever").**

No recurring subscription. Free tier is monetized with a banner ad; Pro is a single
one-time purchase that unlocks everything and removes ads. Offline-first users
prefer lifetime ownership over monthly fees.

## Free Tier

| Feature | Included |
|---|---|
| Standard text translation | ✅ |
| Limited daily voice/audio credits | 5 minutes/day |
| Basic common language pairs | ✅ |
| Banner ad | Shown while using the free tier |

**Target user:** Casual users, travelers doing quick lookups

## Pro Tier (one-time purchase, $4.99 – $14.99)

| Feature | Included |
|---|---|
| Unlimited real-time voice interpretation | ✅ |
| No ads | ✅ |
| Offline translation models | ✅ |
| High-speed processing / low latency | ✅ |
| Advanced features (document/camera OCR, specialized jargon domain) | ✅ |

**Target user:** Business travelers, expats, daily power users

## Revenue strategy notes

- The banner ad on the Free tier converts light daily usage without demanding a purchase.
- The one-time Pro price (recommended $6.99–$9.99, per Play Store fee tiers) is a single
  "buy once, own forever" invoice with Google Play Billing.
- Text translation stays free to keep casual users engaged; voice minutes are the
  premium driver.
- AdMob App ID is currently a placeholder (`ca-app-pub-3940256099942544~3347511713`,
  Google's test ID) — replace with the real AdMob App ID before production release.

## Play Billing wiring (implemented)

| Item | Value |
|---|---|
| Plugin | `in_app_purchase` (`lib/monetization/pro_purchase_service.dart`) |
| Product id | `pro_unlock` (non-consumable, one-time) |
| Purchase flow | `ProPurchaseService.startPurchase()` → Play purchase dialog |
| Verification | `purchaseStream` — on `purchased`/`restored`, `Entitlements.upgradeToPro()` persists locally |
| Graceful fallback | Billing unavailable → SnackBar; tests/emulators without Play fall back to local unlock |
| To activate | In Play Console create a non-consumable product with id **`pro_unlock`** (price ~$6.99) — code needs no change |