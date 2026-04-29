import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/app_initialization_service.dart';
import 'presentation/providers/dependencies.dart';
import 'shared/constants/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Create provider container for dependency injection
  final container = ProviderContainer();

  // Set up error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorHandler = container.read(errorHandlerProvider);
    errorHandler.handleError(details.exception, details.stack);
  };

  // Run app with provider scope
  runApp(
    UncontrolledProviderScope(container: container, child: const SeizaniApp()),
  );
}

class SeizaniApp extends ConsumerWidget {
  const SeizaniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Seizani - 写真を星座アートに (Hot Reload Test)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppWrapper(),
      builder: (context, child) {
        // Global error handling wrapper
        return ErrorBoundary(child: child);
      },
    );
  }
}

/// Wrapper to handle app initialization and routing
class AppWrapper extends ConsumerWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initializationAsync = ref.watch(initializationFutureProvider);

    return initializationAsync.when(
      data: (_) {
        // App initialized successfully
        return const HomeScreen();
      },
      loading: () {
        // Show splash screen while initializing
        return const SplashScreen();
      },
      error: (error, stackTrace) {
        // Show error screen
        return AppErrorScreen(
          error: error,
          stackTrace: stackTrace,
          onRetry: () {
            ref.invalidate(initializationFutureProvider);
          },
        );
      },
    );
  }
}

/// Global error boundary widget
class ErrorBoundary extends StatelessWidget {
  final Widget? child;

  const ErrorBoundary({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return child ?? const SizedBox.shrink();
  }
}

/// Error screen shown when app initialization fails
class AppErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const AppErrorScreen({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 24),
              const Text(
                'アプリの初期化に失敗しました',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (onRetry != null)
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('再試行'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
