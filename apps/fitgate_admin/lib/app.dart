import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/member_edit_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'models/locker.dart';

/// Main app widget with routing configuration
class FitGateAdminApp extends StatelessWidget {
  const FitGateAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitGate Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Professional, clean design
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        brightness: Brightness.light,
        
        // Poppins font globally
        fontFamily: GoogleFonts.poppins().fontFamily,
        
        // Text styles with Poppins
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.light().textTheme.apply(
            bodyColor: Colors.black87,
            displayColor: Colors.black87,
          ),
        ).copyWith(
          headlineSmall: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        // App bar styling
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          centerTitle: false,
        ),

        // Button styling
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),

        // Input field styling
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),

        // Card styling
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        // Data table styling
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          headingRowHeight: 56,
        ),
      ),

      // Routes
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/dashboard': (context) => const ShellScreen(currentRoute: '/dashboard'),
        '/members': (context) => const ShellScreen(currentRoute: '/members'),
        '/lockers': (context) => const ShellScreen(currentRoute: '/lockers'),
        '/admin-settings': (context) => const AdminSettingsScreen(),
        '/member/edit': (context) {
          final member = ModalRoute.of(context)?.settings.arguments as Member?;
          return MemberEditScreen(member: member);
        },
      },
    );
  }
}
