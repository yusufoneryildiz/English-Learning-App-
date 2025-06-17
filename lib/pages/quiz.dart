import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../main.dart'; // main.dart içerisindeki global flutterLocalNotificationsPlugin

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<DocumentSnapshot> _questions = [];
  int _currentQuestionIndex = 0;
  String? _selectedAnswer;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  /// Firestore'dan quizQuestions verilerini çeker, options ve other alanların varlığını kontrol eder.
  Future<void> _fetchQuestions() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('quizQuestions')
          .get();

      if (!mounted) return;

      // Filtre: Hem questionText hem options hem correctAnswer alanı olan dokümanları alalım.
      final validDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;

        if (data == null) return false;
        // 'options' alanı bir liste mi?
        if (data.containsKey('options') &&
            data['options'] is List &&
            (data['options'] as List).isNotEmpty &&
            data.containsKey('questionText') &&
            data.containsKey('correctAnswer')) {
          return true;
        }
        return false;
      }).toList();

      setState(() {
        _questions = validDocs;
        _questions.shuffle(); // rastgele sıralıyoruz
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sorular alınırken hata oluştu: $e')),
      );
    }
  }

  /// Kullanıcının seçtiği şıkkı doğru cevapla karşılaştırır
  void _checkAnswer(String selectedOption) {
    final currentDoc = _questions[_currentQuestionIndex];
    final data = currentDoc.data() as Map<String, dynamic>;
    final correctAnswer = data['correctAnswer'] as String;

    setState(() {
      _selectedAnswer = selectedOption;
      _isAnswered = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedOption.trim() == correctAnswer.trim()
              ? 'Doğru cevap!'
              : 'Yanlış cevap. Doğru cevap: ${correctAnswer.trim()}',
        ),
      ),
    );
  }

  /// Sonraki soruya geçme
  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _isAnswered = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test sona erdi!')),
      );
    }
  }

  /// Soru tekrar listesine eklenir ve 5 saniye sonrasına bildirim ayarlanır.
  Future<void> _addToTekrarListesi(String questionId, String questionText) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final nextDate = now.add(const Duration(seconds: 5)); // test amaçlı kısa

      // Firestore'a ekle
      await FirebaseFirestore.instance.collection('tekrarListesi').add({
        'type': 'quiz',         // Bu bir SORU tipi
        'questionId': questionId,
        'questionText': questionText,
        'currentStage': 0,
        'nextReviewDate': Timestamp.fromDate(nextDate.toLocal()),
      });

      // Bildirim zamanla
      await _scheduleNotificationForQuestion(
        questionId,
        'Soru Tekrar Zamanı Geldi',
        'Tekrar etmeniz gereken bir soru var!',
        nextDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soru tekrar listesine eklendi.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Soru eklenirken bir hata oluştu: $e')),
      );
    }
  }

  /// Bildirim zamanlama
  Future<void> _scheduleNotificationForQuestion(
    String id,
    String title,
    String body,
    DateTime scheduledTime,
  ) async {
    final notificationId = id.hashCode;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tekrar_channel_id',
      'Tekrar Bildirimleri',
      channelDescription: 'Soruların tekrar zamanı geldiğinde gösterilen bildirimler',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId, // Bildirim ID
        title,          // Başlık
        body,           // İçerik
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: id,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bildirim zamanlanırken hata oluştu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eğer hiç valid doküman yoksa veya Firestore boş döndüyse
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(
          child: Text(
            "Soru bulunamadı veya 'options' alanı eksik dokümanlar var. Lütfen Firestore verilerini kontrol edin.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final currentDoc = _questions[_currentQuestionIndex];
    final data = currentDoc.data() as Map<String, dynamic>;
    final questionText = data['questionText'] as String;
    final rawOptions = data['options'] as List; // Firestore'da array
    // Her eleman String olmalı, yoksa toString() yapalım
    final options = rawOptions.map((e) => e.toString()).toList();
    final questionId = currentDoc.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Text(
              questionText,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            // Şıkları göstermek
            for (var option in options)
              ElevatedButton(
                onPressed: _isAnswered ? null : () => _checkAnswer(option),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAnswered
                      ? // Eğer cevap verildiyse doğru-yanlış renklendirme
                        (option.trim() ==
                                (data['correctAnswer'] as String).trim()
                            ? Colors.green
                            : (option == _selectedAnswer
                                ? Colors.red
                                : Colors.blue))
                      : Colors.blue,
                ),
                child: Text(option),
              ),
            const SizedBox(height: 20),
            // Cevap verilmişse Sonraki Soru butonu
            if (_isAnswered)
              ElevatedButton(
                onPressed: _nextQuestion,
                child: const Text('Sonraki Soru'),
              ),
            const SizedBox(height: 20),
            // Tekrar listesine ekleme
            ElevatedButton(
              onPressed: () => _addToTekrarListesi(questionId, questionText),
              child: const Text('Tekrar Listesine Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
