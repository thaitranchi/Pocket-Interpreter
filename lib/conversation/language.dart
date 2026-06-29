enum SupportedLanguage {
  english('English', 'en'),
  vietnamese('Vietnamese', 'vi');

  const SupportedLanguage(this.label, this.code);

  final String label;
  final String code;
}
