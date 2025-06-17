import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class OkumaSayfasi extends StatefulWidget {
  const OkumaSayfasi({Key? key}) : super(key: key);

  @override
  State<OkumaSayfasi> createState() => _OkumaSayfasiState();
}

class _OkumaSayfasiState extends State<OkumaSayfasi> {
  List<DocumentSnapshot> _stories = [];
  DocumentSnapshot? _currentStory;
  bool _showTranslation = false;

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  Future<void> _fetchStories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .get(); // Dilerseniz orderBy('createdAt').get()

      if (!mounted) return;
      setState(() {
        _stories = snapshot.docs;
      });

      _showRandomStory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hikayeler yüklenirken hata oluştu: $e')),
      );
    }
  }

  void _showRandomStory() {
    if (_stories.isEmpty) {
      // Liste boşsa hiçbir şey yapma veya ekrana bilgi ver
      setState(() {
        _currentStory = null;
      });
      return;
    }

    final random = Random();
    final randomIndex = random.nextInt(_stories.length);

    setState(() {
      _currentStory = _stories[randomIndex];
      _showTranslation = false; // Yeni hikaye gelince Türkçeyi sıfırla
    });
  }

  void _toggleTranslation() {
    setState(() {
      // “Türkçesini Göster/Gizle” geçişi
      _showTranslation = !_showTranslation;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStory == null && _stories.isEmpty) {
      // Hikayeler daha çekilmemiş ya da boş
      return Scaffold(
        appBar: AppBar(title: const Text('Okuma')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // currentStory kesinlikle null değilse, verisini al
    final englishText = _currentStory?['englishText'] ?? 'No Data';
    final turkishText = _currentStory?['turkishText'] ?? 'No Data';

   return Scaffold(
  appBar: AppBar(
    title: const Text('Okuma'),
  ),
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16.0),
    child: _currentStory == null
        ? const Center(child: Text('Hiç hikâye bulunamadı.'))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'İngilizce Hikaye:',
                style: const TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                englishText,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              if (_showTranslation) ...[
                Text(
                  'Türkçe Çeviri:',
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  turkishText,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
              ],

              ElevatedButton(
                onPressed: _toggleTranslation,
                child: Text(
                  _showTranslation 
                      ? 'Türkçeyi Gizle' 
                      : 'Türkçesini Göster'
                ),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _showRandomStory,
                child: const Text('Sıradaki Hikaye'),
              ),
            ],
          ),
  ),
);

  }
}
