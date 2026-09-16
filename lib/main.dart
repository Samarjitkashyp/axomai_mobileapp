import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth_gate_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Gracefully handle font network/CORS timeouts so the app falls back to system fonts seamlessly
  FlutterError.onError = (FlutterErrorDetails details) {
    final errStr = details.exception.toString();
    if (errStr.contains('google_fonts') ||
        errStr.contains('Failed to load font') ||
        errStr.contains('fonts.gstatic.com')) {
      debugPrint('Font network notice (falling back to system font): $errStr');
      return;
    }
    FlutterError.presentError(details);
  };

  // Set immersive status & navigation bar styles
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.bgMain,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final isDark = await StorageService.loadIsDarkMode();

  runApp(AxomAiApp(initialIsDark: isDark));
}

class AxomAiApp extends StatefulWidget {
  final bool initialIsDark;
  const AxomAiApp({super.key, required this.initialIsDark});

  @override
  State<AxomAiApp> createState() => _AxomAiAppState();
}

class _AxomAiAppState extends State<AxomAiApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.initialIsDark;
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    StorageService.saveIsDarkMode(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Axom AI',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: AuthGateScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
