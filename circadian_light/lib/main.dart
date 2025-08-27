import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/routines.dart';
import 'screens/settings.dart';
import 'core/esp_connection.dart';

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
  @override
  void initState() {
    super.initState();
  // Start ESP connection on app launch
  EspConnection.I.connect();
    _screens = [
      const HomeScreen(),
      const RoutinesScreen(),
      const SettingsScreen(),
    ];
  }
  int myIndex = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC049), // warm yellow seed
          brightness: Brightness.light,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFC049),
            foregroundColor: const Color(0xFF3C3C3C),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF5A4A00),
            side: const BorderSide(color: Color(0xFFFFC049), width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.grey,
          foregroundColor: Color(0xFF3C3C3C),
          elevation: 0,
        ),
      ),
      home: Scaffold(
        extendBody: true,
        body: _screens[myIndex],

        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: BottomNavigationBar(
              backgroundColor: const Color.fromARGB(0, 22, 59, 31),
              elevation: 0,
              onTap: (index) => setState(() => myIndex = index),
              currentIndex: myIndex,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
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
  }
}
 