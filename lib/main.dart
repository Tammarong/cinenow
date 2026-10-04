import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/backend_mode.dart';
import 'core/theme/app_theme.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sora + Inter ship in assets/google_fonts, so text looks right offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlayStyle);

  final (backend, prefs) = await (initBackend(), SharedPreferences.getInstance()).wait;

  runApp(
    ProviderScope(
      overrides: [backendStatusProvider.overrideWithValue(backend), prefsProvider.overrideWithValue(prefs)],
      // Screens show their own error states with a "Try again" button.
      retry: (retryCount, error) => null,
      child: const CineNowApp(),
    ),
  );
}
