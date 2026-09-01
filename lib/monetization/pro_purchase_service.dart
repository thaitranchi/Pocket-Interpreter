import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../entitlements/entitlements.dart';

/// Wraps Google Play Billing for the one-time Pro upgrade.
///
/// The Google Play Console product must expose a non-consumable product with
/// [proProductId]. When a verified purchase completes, [Entitlements] is
/// upgraded and persisted locally.
class ProPurchaseService {
  ProPurchaseService({
    required Entitlements entitlements,
    InAppPurchase? purchase,
  }) : _entitlements = entitlements,
       _purchase = purchase ?? InAppPurchase.instance;

  /// One-time (non-consumable) product id configured in Play Console.
  static const String proProductId = 'pro_unlock';

  final Entitlements _entitlements;
  final InAppPurchase _purchase;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _proProduct;

  final ValueNotifier<bool> _purchasing = ValueNotifier(false);

  /// True while a purchase flow is in flight (used to disable the Go Pro
  /// button and show a spinner).
  ValueListenable<bool> get purchasing => _purchasing;

  /// True when Play Billing is available and the Pro product was found.
  bool _available = false;

  bool get isAvailable => _available;

  /// Subscribes to purchase results and loads the Pro product details.
  ///
  /// Safe to call on any environment (e.g. tests) - failures disable billing
  /// instead of throwing.
  Future<void> initialize() async {
    try {
      _subscription = _purchase.purchaseStream.listen(_onPurchases);
      if (!await _purchase.isAvailable()) {
        return;
      }
      final response = await _purchase.queryProductDetails(
        const <String>{proProductId},
      );
      if (response.notFoundIDs.contains(proProductId)) {
        return;
      }
      _proProduct = response.productDetails
          .where((details) => details.id == proProductId)
          .firstOrNull;
      _available = _proProduct != null;
    } catch (_) {
      _available = false;
    }
  }

  /// Starts the Play purchase flow. Returns false when billing is unavailable
  /// or the product is missing (e.g. running outside a Play Store device).
  Future<bool> startPurchase() async {
    final product = _proProduct;
    if (!_available || product == null) {
      return false;
    }
    _purchasing.value = true;
    try {
      await _purchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      return true;
    } catch (_) {
      _purchasing.value = false;
      return false;
    }
  }

  /// Closes the purchase subscription and releases resources.
  void dispose() {
    unawaited(_subscription?.cancel());
    _purchasing.dispose();
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != proProductId) {
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          unawaited(_entitlements.upgradeToPro());
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
          break;
      }
      if (purchase.pendingCompletePurchase) {
        _purchase.completePurchase(purchase);
      }
    }
    _purchasing.value = false;
  }
}