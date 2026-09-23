// lib/core/utils/website.dart
//
// The website, where plans are bought.
//
// Subscriptions are not sold in the app: every "explore plans" and every
// "subscribe" opens this in the phone's browser, so there is one definition
// of where that is.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widget/app_snackbar.dart';

const String websiteUrl = 'https://skms-frontend.vercel.app/';

/// Swapped in tests, which have no browser to open.
@visibleForTesting
Future<bool> Function(Uri url) launchWebsite = (url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Opens the website. Says so when the phone has nothing to open it with,
/// rather than letting the tap do nothing.
Future<void> openWebsite(BuildContext context, {String path = ''}) async {
  final url = Uri.parse('$websiteUrl$path');

  var opened = false;
  try {
    opened = await launchWebsite(url);
  } catch (error) {
    if (kDebugMode) debugPrint('WEBSITE  could not open $url: $error');
  }

  if (!opened && context.mounted) {
    showAppSnackBar(
      context,
      'Could not open the browser. Visit $websiteUrl to see the plans.',
      kind: AppMessage.failure,
    );
  }
}
