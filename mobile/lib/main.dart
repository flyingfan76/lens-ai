import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
// Unified State Management
import 'core/state/app_state_provider.dart';
import 'core/state/ui_state_provider.dart';
import 'core/state/error_state_provider.dart';
import 'core/state/state_manager.dart';
import 'screens/splash_screen.dart';
import 'screens/main_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Performance optimizations for mobile-first approach
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Initialize unified state management system
  final stateManager = await StateManager.initialize();
  
  runApp(LensAIApp(stateManager: stateManager));
}

class LensAIApp extends StatelessWidget {
  final StateManager stateManager;
  
  const LensAIApp({
    super.key, 
    required this.stateManager,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: stateManager.getProviders(),
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'Lens AI',
            theme: AppTheme.lightTheme.copyWith(
              textTheme: AppTheme.lightTheme.textTheme.apply(
                fontFamily: 'Roboto',
                fontFamilyFallback: const ['Arial', 'sans-serif'],
              ),
              // Performance optimizations
              visualDensity: VisualDensity.adaptivePlatformDensity,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            darkTheme: AppTheme.darkTheme.copyWith(
              textTheme: AppTheme.darkTheme.textTheme.apply(
                fontFamily: 'Roboto',
                fontFamilyFallback: const ['Arial', 'sans-serif'],
              ),
              visualDensity: VisualDensity.adaptivePlatformDensity,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            themeMode: appState.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/main': (context) => const MainDashboard(),
            },
            debugShowCheckedModeBanner: false,
            // Performance settings
            builder: (context, child) {
              final uiState = context.watch<UIStateProvider>();
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: appState.textScaleFactor,
                ),
                child: Stack(
                  children: [
                    child!,
                    // Global error banner - TEMPORARILY DISABLED FOR DEBUG
                    // if (context.watch<ErrorStateProvider>().showErrorBanner)
                    //   _buildErrorBanner(context),
                    // Global loading overlay - TEMPORARILY DISABLED FOR DEBUG
                    // if (uiState.isAnyLoading)
                    //   _buildLoadingOverlay(context),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildErrorBanner(BuildContext context) {
    final errorState = context.watch<ErrorStateProvider>();
    
    return Positioned(
      top: MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: errorState.currentErrorSeverity == ErrorSeverity.critical
            ? Colors.red
            : Colors.orange,
        child: Row(
          children: [
            Icon(
              errorState.currentErrorSeverity == ErrorSeverity.critical
                  ? Icons.error
                  : Icons.warning,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorState.currentErrorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => errorState.dismissErrorBanner(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLoadingOverlay(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}