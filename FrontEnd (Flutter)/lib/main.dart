import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/services/hive_service.dart';
import 'core/themes/app_theme.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/providers/schedule_provider.dart';
import 'presentation/providers/chat_provider.dart';
import 'presentation/providers/ingredient_provider.dart';
import 'presentation/providers/photo_provider.dart';
import 'presentation/screens/splash_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id', null);
  await dotenv.load(fileName: ".env");
  await HiveService.init();
  runApp(const NutrifyApp());
}

class NutrifyApp extends StatelessWidget {
  const NutrifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProxyProvider<DashboardProvider, ScheduleProvider>(
          create: (context) => ScheduleProvider(),
          update: (context, dashboardProvider, scheduleProvider) {
            scheduleProvider!.updateDashboardProvider(dashboardProvider);
            return scheduleProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => IngredientProvider()),
        ChangeNotifierProvider(create: (_) => PhotoProvider()),
      ],
      child: MaterialApp(
        title: 'NutriFy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
