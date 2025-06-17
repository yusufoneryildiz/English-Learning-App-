import 'package:flutter/material.dart';
import 'package:finalprojesi1/pages/fotografik_kelimeler.dart';
import 'package:finalprojesi1/pages/okuma.dart';
import 'package:finalprojesi1/pages/tekrar_listesi.dart';
import 'package:finalprojesi1/pages/quiz.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Başlık Alanı
          Stack(
            children: [
              Container(
                height: 220,
                padding: EdgeInsets.only(left: 20, top: 50),
                decoration: BoxDecoration(
                  color: Color.fromARGB(224, 0, 0, 0),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.asset(
                        "images/LEARN_ENGLISH.jpeg", // Resmi buraya ekleyin
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(
                      width: 20,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "Yusuf Öneryıldız",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Kategori Kutucukları
          Expanded(
            child: GridView.count(
              crossAxisCount: 2, // 2 sütunlu grid
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              padding: EdgeInsets.all(20),
              children: [
                // İlk Kutucuk
                categoryBox(
                  context,
                  imagePath: "images/foto1.jpeg", // Resim yolu
                  title: "Kelimeler",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Fotografik()),
                    );
                  },
                ),
                // İkinci Kutucuk
                categoryBox(
                  context,
                  imagePath: "images/foto2.jpeg",
                  title: "Tekrar listesi",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => TekrarListesi()),
                    );
                  },
                ),
                // Üçüncü Kutucuk
                categoryBox(
                  context,
                  imagePath: "images/foto3.jpeg",
                  title: "Quiz",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => QuizPage()),
                    );
                  },
                ),
                // Dördüncü Kutucuk
                categoryBox(
                  context,
                  imagePath: "images/foto4.jpeg",
                  title: "OkumaSayfasi",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => OkumaSayfasi()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tekrarlayan kutucuklar için fonksiyon
  Widget categoryBox(BuildContext context,
      {required String imagePath, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
