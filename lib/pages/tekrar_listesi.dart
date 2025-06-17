import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart'; // flutterLocalNotificationsPlugin erişimi

class TekrarListesi extends StatefulWidget {
  const TekrarListesi({super.key});

  @override
  State<TekrarListesi> createState() => _TekrarListesiState();
}

class _TekrarListesiState extends State<TekrarListesi> {
  List<DocumentSnapshot> _tekrarDocs = [];
  int _currentIndex = 0;

  // Tekrar aşamaları: 5 sn, 7 gün, 30 gün, 90 gün (örnek)
  final intervals = <Duration>[
    const Duration(seconds: 5),
    const Duration(days: 7),
    const Duration(days: 30),
    const Duration(days: 90),
  ];

  @override
  void initState() {
    super.initState();
    _fetchTekrarListesi();
  }

  /// Firestore'dan tekrar edilmesi gereken dokümanları çeker:
  /// nextReviewDate <= now olan (yani vakti gelmiş) ve
  /// type=='image' veya type=='quiz' alanı doğru olan dokümanları filtreler.
  Future<void> _fetchTekrarListesi() async {
    final now = DateTime.now();
    debugPrint('[_fetchTekrarListesi] Şu an: $now');

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tekrarListesi')
          .where('nextReviewDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('nextReviewDate', descending: false)
          .get();

      if (!mounted) return;

      // Geçerli tip ve veri alanlarını kontrol
      final validDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        final type = data['type'];
        if (type == 'image' && data.containsKey('url')) {
          return true;
        } else if (type == 'quiz' && data.containsKey('questionText')) {
          return true;
        }
        return false;
      }).toList();

      setState(() {
        _tekrarDocs = validDocs;
        _currentIndex = 0;
      });
      debugPrint('[_fetchTekrarListesi] Gelen doküman sayısı: ${validDocs.length}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tekrar listesi alınırken hata oluştu: $e')),
      );
      debugPrint('[_fetchTekrarListesi] Hata: $e');
    }
  }

  /// Listeden seçili dokümanı siler ve varsa bildirimini iptal eder.
  Future<void> _removeFromTekrarListesi() async {
    if (_tekrarDocs.isEmpty) return;
    final docToRemove = _tekrarDocs[_currentIndex];

    try {
      await FirebaseFirestore.instance
          .collection('tekrarListesi')
          .doc(docToRemove.id)
          .delete();

      final notificationId = docToRemove.id.hashCode;
      await flutterLocalNotificationsPlugin.cancel(notificationId);

      if (!mounted) return;
      setState(() {
        _tekrarDocs.removeAt(_currentIndex);
        if (_currentIndex >= _tekrarDocs.length && _tekrarDocs.isNotEmpty) {
          _currentIndex = 0;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listeden kaldırıldı.')),
      );
      debugPrint('[_removeFromTekrarListesi] Doküman silindi: ${docToRemove.id}');
    } catch (e) {
      debugPrint('[_removeFromTekrarListesi] Hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listeden kaldırılırken hata oluştu: $e')),
      );
    }
  }

  /// "Tekrar Et" butonuna basıldığında bir sonraki aşamaya geçirir;
  /// yeni nextReviewDate hesaplar ve bildirimi zamanlar.
  Future<void> _tekrarEt() async {
    if (_tekrarDocs.isEmpty) return;

    final docToUpdate = _tekrarDocs[_currentIndex];
    final data = docToUpdate.data() as Map<String, dynamic>;
    final currentStage = data['currentStage'] ?? 0;
    int nextStage = currentStage + 1;
    if (nextStage >= intervals.length) {
      nextStage = intervals.length - 1; // en son aşamada kal
    }

    final now = tz.TZDateTime.now(tz.local);
    var nextReviewDate = now.add(intervals[nextStage]);

    debugPrint('[_tekrarEt] Şu an: $now');
    debugPrint('[_tekrarEt] currentStage: $currentStage, nextStage: $nextStage');
    debugPrint('[_tekrarEt] Hesaplanan nextReviewDate: $nextReviewDate');

    // Eğer nextReviewDate şu anla aynı veya geçmişse, +1 saniye tampon ekle
    if (!nextReviewDate.isAfter(now)) {
      debugPrint('[_tekrarEt] nextReviewDate geçmiş veya eşit, 1sn ileri alıyoruz...');
      nextReviewDate = now.add(const Duration(seconds: 1));
    }

    // Kaç saniye fark var, loglayalım
    final diffMs = nextReviewDate.difference(now).inMilliseconds;
    debugPrint('[_tekrarEt] Fark: $diffMs ms');

    try {
      await FirebaseFirestore.instance
          .collection('tekrarListesi')
          .doc(docToUpdate.id)
          .update({
        'currentStage': nextStage,
        'nextReviewDate': Timestamp.fromDate(nextReviewDate),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${intervals[nextStage].inDays} gün/saniye sonra tekrar için ayarlandı.',
          ),
        ),
      );
      debugPrint('[_tekrarEt] Firestore güncellendi: $nextReviewDate');

      // Yeni bildirimi zamanla
      await _scheduleNotificationForTekrarDoc(docToUpdate.id, {
        ...data,
        'nextReviewDate': nextReviewDate,
      });

      // Listeyi yeniden yükle (gerekirse)
      await _fetchTekrarListesi();
    } catch (e) {
      debugPrint('[_tekrarEt] Hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tekrar etme sırasında hata oluştu: $e')),
      );
    }
  }

  /// Dokümanın tipine göre bildirim zamanlama
  Future<void> _scheduleNotificationForTekrarDoc(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final notificationId = docId.hashCode;
    // nextReviewDate alanını DateTime'e çevir (veya doğrudan DateTime geliyorsa)
    DateTime nextReviewDate;
    if (data['nextReviewDate'] is DateTime) {
      nextReviewDate = data['nextReviewDate'] as DateTime;
    } else if (data['nextReviewDate'] is Timestamp) {
      nextReviewDate = (data['nextReviewDate'] as Timestamp).toDate();
    } else {
      debugPrint('[_scheduleNotificationForTekrarDoc] Geçersiz nextReviewDate tipi.');
      return;
    }

    debugPrint('[_scheduleNotificationForTekrarDoc] Zamanlanacak: $nextReviewDate');

    // Bildirim kanalı ayarları
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tekrar_channel_id_v2',
      'Tekrar Bildirimleri',
      channelDescription:
          'Fotoğrafların veya soruların tekrar zamanı geldiğinde gösterilen bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    // Tipine göre başlık/içerik
    final type = data['type'] ?? '';
    String title = 'Tekrar Zamanı Geldi';
    String body = 'Tekrar etmeniz gereken bir öğe var!';
    if (type == 'image') {
      body = 'Tekrar etmeniz gereken bir fotoğraf var!';
    } else if (type == 'quiz') {
      body = 'Tekrar etmeniz gereken bir soru var!';
    }

    // TZDateTime oluştur
    final tzDateTime = tz.TZDateTime.from(nextReviewDate, tz.local);
    debugPrint('[_scheduleNotificationForTekrarDoc] tzDateTime: $tzDateTime');

    // Gelecek bir zaman mı, loglayalım
    final nowTz = tz.TZDateTime.now(tz.local);
    final diffMs = tzDateTime.difference(nowTz).inMilliseconds;
    debugPrint('[_scheduleNotificationForTekrarDoc] Şu an: $nowTz, Fark: $diffMs ms');

    if (!tzDateTime.isAfter(nowTz)) {
      debugPrint('[_scheduleNotificationForTekrarDoc] HATA: tzDateTime geçmiş veya anlık!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planlanan zaman geçmişte görünüyor. Bildirim ayarlanamadı.')),
      );
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: docId,
      );
      debugPrint('[_scheduleNotificationForTekrarDoc] Bildirim zamanlandı => $tzDateTime');
    } catch (e) {
      debugPrint('[_scheduleNotificationForTekrarDoc] Hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim zamanlanırken hata oluştu: $e')),
      );
    }
  }

  /// Listedeki bir sonrakini göster (varsa)
  void _showNext() {
    if (_tekrarDocs.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _tekrarDocs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_tekrarDocs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tekrar Listesi'),
        ),
        body: const Center(
          child: Text("Şu an tekrar etmeniz gereken bir öğe yok."),
        ),
      );
    }

    final currentDoc = _tekrarDocs[_currentIndex];
    final data = currentDoc.data() as Map<String, dynamic>;
    final type = data['type'] ?? '';

    final questionText = data.containsKey('questionText') ? data['questionText'] as String : null;
    final fotoUrl = data.containsKey('url') ? data['url'] as String : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tekrar Listesi'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (type == 'image' && fotoUrl != null) ...[
              Image.network(
                fotoUrl,
                errorBuilder: (_, __, ___) {
                  return const Icon(Icons.broken_image, size: 100);
                },
              ),
              const SizedBox(height: 20),
            ] else if (type == 'quiz' && questionText != null) ...[
              Text(
                questionText,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
            ] else ...[
              const Text(
                'Bu öğe için geçerli bir tip veya veri bulunamadı.',
                style: TextStyle(color: Colors.red),
              ),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _showNext,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  child: const Text('Sıradaki'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _removeFromTekrarListesi,
                  child: const Text('Listeden Sil'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _tekrarEt,
              child: const Text('Tekrar Et'),
            ),
          ],
        ),
      ),
    );
  }
}
