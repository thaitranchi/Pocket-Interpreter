enum SubscriptionTier {
  free('Free'),
  pro('Pro');

  const SubscriptionTier(this.label);

  final String label;

  bool get isPro => this == SubscriptionTier.pro;
}