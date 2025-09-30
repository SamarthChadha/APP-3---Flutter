import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'screens/home.dart';
import 'screens/routines.dart';
import 'screens/settings.dart';
import 'core/esp_connection.dart';
import 'core/sunrise_sunset_manager.dart';
import 'core/theme_manager.dart';
import 'services/database_service.dart';
import 'services/esp_sync_service.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();


}

class _MainAppState extends State<MainApp> {
  late final List<Widget> _screens;
  bool _initializationFailed = false;
  String? _initializationError;
  static final Logger _logger = Logger('MainApp');

  @override
  void initState() {
    super.initState();
    _setupLogging();
    _initializeApp();
    
    _screens = [
      const HomeScreen(),
      const RoutinesScreen(),
      const SettingsScreen(),
    ];
  }

  void _setupLogging() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      if (record.error != null) {}
      if (record.stackTrace != null) {}
    });
  }

  Future<void> _initializeApp() async {
    try {
      _logger.info('Starting app initialization...');

      // Initialize database first - this is critical for app functionality
      _logger.info('Initializing database...');
      await db.initialize();
      _logger.info('Database initialized successfully');

      // Initialize theme manager
      _logger.info('Initializing theme manager...');
      await ThemeManager.I.init();
      _logger.info('Theme manager initialized successfully');

      // Start ESP connection - this is optional, app should work without it
      _logger.info('Starting ESP connection...');
      try {
        await EspConnection.I.connect();
        _logger.info('ESP connection attempt completed');

        // Listen for ESP connection changes and sync when connected
        EspConnection.I.connection.listen((isConnected) {
          if (isConnected) {
            _logger.info('ESP32 connected, triggering full sync...');
            EspSyncService.I.onEspConnected();
          }
        });
      } catch (espError) {
        // ESP connection failure shouldn't prevent app from working
        _logger.warning('ESP connection failed, continuing without device connection', espError);
      }

      // Initialize sunrise/sunset manager but don't enable it by default
      // It will be enabled when user turns it on in settings
      _logger.info('App initialization completed successfully');
      
    } catch (error, stackTrace) {
      _logger.severe('Critical app initialization failed', error, stackTrace);
      
      setState(() {
        _initializationFailed = true;
        _initializationError = error.toString();
      });
      
      // Show error to user
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('App initialization failed: ${error.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _initializationFailed = false;
                    _initializationError = null;
                  });
                  _initializeApp();
                },
              ),
            ),
          );
        });
      }
    }
  }
  
  @override
  void dispose() {
    // Clean up the sunrise/sunset manager when app is disposed
    SunriseSunsetManager.I.dispose();
    super.dispose();
  }
  int myIndex = 0;
  @override
  Widget build(BuildContext context) {
    // Show error state if initialization failed
    if (_initializationFailed) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red[50],
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[600],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'App Initialization Failed',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _initializationError ?? 'Unknown error occurred',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _initializationFailed = false;
                        _initializationError = null;
                      });
                      _initializeApp();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Initialization'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: ThemeManager.I,
      builder: (context, child) {
        return MaterialApp(
          theme: ThemeManager.I.lightTheme,
          darkTheme: ThemeManager.I.darkTheme,
          themeMode: ThemeManager.I.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        extendBody: true,
        body: _screens[myIndex],

        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            decoration: BoxDecoration(
              color: ThemeManager.I.navigationBarColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: ThemeManager.I.navigationBarShadow,
            ),
            child: BottomNavigationBar(
              backgroundColor: const Color.fromARGB(0, 22, 59, 31),
              elevation: 0,
              onTap: (index) => setState(() => myIndex = index),
              currentIndex: myIndex,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              selectedItemColor: ThemeManager.I.currentAccentColor,
              unselectedItemColor: ThemeManager.I.secondaryTextColor,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'Routines',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
        );
      },
    );
  }
}
 