import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'pages/home.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Global bildirim değişkeni
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> checkAndRequestPermissions() async {
  // Bildirim iznini kontrol et ve talep et
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  // Schedule Exact Alarm iznini kontrol et ve talep et (Android 12 ve üzeri için gereklidir)
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase başlatma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Timezone başlatma
  tz.initializeTimeZones();
  // Bölgesel zaman dilimi ayarı
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  // Lokal bildirimler için ayarlar
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // Bildirim eklentisini başlat
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // İzinleri talep et
  await checkAndRequestPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tekrar Sistemi',
      debugShowCheckedModeBanner: false,
      home: const Home(),
    );
  }
}
