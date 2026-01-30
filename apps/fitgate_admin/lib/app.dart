import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fitgate_shared/fitgate_shared.dart';
import 'theme/app_colors.dart';
import 'screens/login_screen.dart';
import 'screens/member_edit_screen.dart';
import 'screens/member_details_screen.dart';
import 'screens/shell_screen.dart';
// ...existing code...

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
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        brightness: Brightness.light,
        
        // Poppins font globally
        fontFamily: GoogleFonts.poppins().fontFamily,
        
        // Text styles with Poppins
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.light().textTheme.apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
        ).copyWith(
          headlineSmall: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
          ),
        ),

        // App bar styling
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),

        // Button styling
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
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
            borderSide: BorderSide(color: AppColors.primary, width: 2),
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
        '/activity-logs': (context) => const ShellScreen(currentRoute: '/activity-logs'),
        // ...removed admin-settings route...
        '/member/details': (context) {
          final member = ModalRoute.of(context)?.settings.arguments as Member?;
          return MemberDetailsScreen(member: member ?? Member(
            id: '',
            name: '',
            cardId: '',
            status: 'active',
            membershipValidUntil: DateTime.now(),
            registeredAt: DateTime.now(),
          ));
        },
        '/member/edit': (context) {
          final member = ModalRoute.of(context)?.settings.arguments as Member?;
          return MemberEditScreen(member: member);
        },
      },
    );
  }
}
