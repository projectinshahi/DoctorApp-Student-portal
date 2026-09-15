// lib/view/Home/profile/legal_text.dart
//
// The details a legal document needs and only the academy can supply.
//
// Kept here, at the top of one small file, rather than scattered through the
// prose — so filling them in is four edits in one place, and so the screens
// can tell whether they have been filled at all.
class LegalDetails {
  const LegalDetails._();

  /// The name students see. The document is about the app in their hands, so
  /// it names that rather than an internal platform name.
  static const String appName = "Dr. SKM's Academy";

  /// The entity behind the app. Shown in the Contact section.
  static const String companyName = '[Company Name]';

  static const String supportEmail = '[Support Email]';

  /// Privacy enquiries. Often the same inbox as support, but named
  /// separately because a privacy request may need to reach someone else.
  static const String privacyEmail = '[Privacy/Support Email]';
  static const String website = '[Website]';

  /// When these terms last changed. Not generated from the build date: the
  /// date on a legal document is when its wording changed, not when the app
  /// was compiled.
  static const String lastUpdated = '[Date]';

  /// True while any detail is still a placeholder.
  ///
  /// Drives the warning banner, so the reminder disappears by itself once the
  /// real values are in and nobody has to remember to remove it.
  static bool get isIncomplete => [
        companyName,
        supportEmail,
        privacyEmail,
        website,
        lastUpdated,
      ].any((value) => value.startsWith('['));
}
