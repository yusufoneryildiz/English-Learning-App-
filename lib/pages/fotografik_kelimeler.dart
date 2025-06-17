import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
// main.dart içerisindeki global flutterLocalNotificationsPlugin
import '../main.dart';

class Fotografik extends StatefulWidget {
  const Fotografik({super.key});

  @override
  State<Fotografik> createState() => _FotografikState();
}

class _FotografikState extends State<Fotografik> {
  // Firestore'dan çekilen fotoğrafların URL listesi
  List<String> _fotoUrls = [];
  // Şu an ekranda gösterilen fotoğrafın URL'si
  String? _currentFotoUrl;

  @override
  void initState() {
    super.initState();
    _fetchFotoUrls();
  }

  /// Firestore'daki 'fotografikKelimeler' koleksiyonundan url'leri çeker
  Future<void> _fetchFotoUrls() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('fotografikKelimeler')
          .get();

      if (!mounted) return;

      setState(() {
        _fotoUrls = snapshot.docs.map((doc) => doc['url'] as String).toList();
      });

      debugPrint('Fotografik Kelimeler Fetch - Toplam: ${_fotoUrls.length}');
      _showRandomFoto();
    } catch (e) {
      debugPrint('Fotografik Kelimeler Fetch Hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler yüklenirken bir hata oluştu: $e')),
      );
    }
  }

  /// Listedeki fotoğraflardan rastgele birini seçer ve ekranda gösterir
  void _showRandomFoto() {
    if (_fotoUrls.isEmpty) {
      setState(() {
        _currentFotoUrl = null;
      });
      return;
    }
    final random = Random();
    int randomIndex = random.nextInt(_fotoUrls.length);
    setState(() {
      _currentFotoUrl = _fotoUrls[randomIndex];
    });
    debugPrint('Rastgele Fotoğraf Gösteriliyor. Index: $randomIndex');
  }

  /// Fotoğrafı tekrar listesine ekler ve 5 saniye sonrasına bildirim zamanlar
  Future<void> _addToTekrarListesi(String fotoUrl) async {
    try {
      // 5 saniye sonrası (test amaçlı)
      final now = tz.TZDateTime.now(tz.local);
      final nextDate = now.add(const Duration(days: 1));

      // Firestore'a ekle
      final docRef = await FirebaseFirestore.instance.collection('tekrarListesi').add({
        'type': 'image',  // Bu bir FOTOĞRAF tipi
        'url': fotoUrl,
        'currentStage': 0,
        'nextReviewDate': Timestamp.fromDate(nextDate),
      });

      debugPrint('Firestore\'a eklendi => docID: ${docRef.id} | url: $fotoUrl');

      // Bildirimi zamanla
      await _scheduleNotificationForFoto(docRef.id, fotoUrl, nextDate);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fotoğraf tekrar listesine eklendi. 5 saniye sonra bildirim gelir.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Tekrar Listesi Eklenirken Hata: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf eklenirken bir hata oluştu: $e')),
      );
    }
  }

  /// Fotoğraf için zonedSchedule ile bildirim
  Future<void> _scheduleNotificationForFoto(
    String docId,
    String fotoUrl,
    DateTime scheduledTime,
  ) async {
    // Notification ID olarak docId veya fotoUrl.hashCode kullanabilirsiniz.
    final notificationId = docId.hashCode;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_channel_id',
      'Tekrar Bildirimleri',
      channelDescription:
          'Fotoğrafların tekrar zamanı geldiğinde gösterilen bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    try {
      debugPrint('Bildirim zamanlanıyor: $scheduledTime | Hash: $notificationId');

      // scheduledTime'ı TZDateTime'e çevir
      final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        'Tekrar Zamanı Geldi',
        'Tekrar etmeniz gereken bir fotoğraf var!',
        tzScheduled,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: fotoUrl, // Opsiyonel
      );

      debugPrint('Bildirim başarıyla zamanlandı: $tzScheduled');
    } catch (e) {
      debugPrint('Bildirim zamanlanırken hata: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim ayarlanırken hata oluştu: $e')),
      );
    }
  }

  /// Normal show() bildirimi ile test
  Future<void> _sendTestNotification() async {
    try {
      debugPrint('Normal Show() ile Test Bildirimi Gönderiliyor...');
      await flutterLocalNotificationsPlugin.show(
        999, // Test ID
        'Test Başlık',
        'Bu bir test bildirimidir.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel_id',
            'Test Kanalı',
            channelDescription: 'Bu bir test kanal açıklamasıdır.',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
      debugPrint('Test bildirimi başarıyla gönderildi.');
    } catch (e) {
      debugPrint('Test bildirimi gönderilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotografik Kelimeler'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_currentFotoUrl != null)
              Image.network(
                _currentFotoUrl!,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, size: 80);
                },
              )
            else
              const Text("Henüz bir fotoğraf seçilmedi"),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Rastgele fotoğraf göster
                ElevatedButton(
                  onPressed: _showRandomFoto,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  child: const Text('Rastgele Fotoğraf'),
                ),
                // Tekrar listesine ekle
                ElevatedButton(
                  onPressed: _currentFotoUrl == null
                      ? null
                      : () => _addToTekrarListesi(_currentFotoUrl!),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  child: const Text('Tekrar Listesine Ekle'),
                ),
              ],
            ),
          ],
        ),
      ),

      // Opsiyonel: FAB ile test bildirimi
      floatingActionButton: FloatingActionButton(
        onPressed: _sendTestNotification,
        child: const Icon(Icons.notifications),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    debugPrint('Fotografik State Dispose');
  }
}
