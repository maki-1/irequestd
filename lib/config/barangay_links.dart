/// Outbound links to official Barangay Dologon channels.
///
/// Kept in one place so the APK and the web build stay in sync — both Flutter
/// targets compile from this same file, so there is nothing platform-specific
/// to maintain.
class BarangayLinks {
  /// Official Facebook page where the barangay posts announcements.
  ///
  /// Leave empty to hide the entry point entirely; the UI degrades gracefully
  /// rather than opening a dead tab.
  ///
  /// This is the numeric `profile.php?id=` form, which is what Facebook serves
  /// until a page claims a username. If the barangay later sets a custom handle
  /// (facebook.com/<name>), update this value — the old link keeps working, but
  /// the readable one is friendlier if a resident ever reads it aloud.
  static const String facebookPage = String.fromEnvironment(
    'FB_PAGE_URL',
    defaultValue: 'https://www.facebook.com/profile.php?id=61590862771260',
  );

  static bool get hasFacebookPage => facebookPage.isNotEmpty;
}
