import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Digital News',
    home: MyApp(),
  ));
}

Stream<List<Map<String, dynamic>>> fetchNewsRealtime() {
  try {
    return FirebaseFirestore.instance.collection('news').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList(),
        );
  } catch (e) {
    throw Exception('Error fetching news: $e');
  }
}

void deleteNews(index) async {
  CollectionReference news = FirebaseFirestore.instance.collection('news');

  // await ;
}

void _showAlertDialog(BuildContext context, bool status, String message) {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        if (status == false) {
          return AlertDialog(
            title: Text('Error message'),
            content: Text('$message'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          );
        } else {
          return AlertDialog(
            title: Text('Info'),
            content: Text('$message'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          );
        }
      });
}

class UpdateNewsRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

class AddNewsRoute extends StatelessWidget {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text("Add the news"),
        ),
        body: Column(
          children: [
            TextFormField(
              controller: titleController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelText: 'Enter the title of the news',
              ),
            ),
            SizedBox(
              height: 16,
            ),
            TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelText: 'Enter the description of the news',
              ),
            ),
            SizedBox(
              height: 16,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection("news").add({
                    "title": titleController.text,
                    "description": descriptionController.text,
                    "time_stamp": FieldValue.serverTimestamp(),
                  });
                  _showAlertDialog(
                      context, true, "News successfully created 👌");
                  titleController.clear();
                  descriptionController.clear();
                } catch (e) {
                  _showAlertDialog(context, false, e.toString());
                  print(e);
                }
              },
              child: const Text("Submit"),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter News App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blueAccent,
          title: const Text("News App", style: TextStyle(color: Colors.white)),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: fetchNewsRealtime(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No News Found'));
                    }
                    final news = snapshot.data!;
                    // print(snapshot.data![0]);
                    return ListView.builder(
                      itemCount: news.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                                'https://t3.ftcdn.net/jpg/06/34/80/20/360_F_634802094_qtHEQh9cJxc8bzzUpIVfiTqmzFBRT3zm.jpg'),
                          ),
                          trailing: Wrap(
                            spacing: 12,
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_red_eye_sharp),
                                onPressed: () {
                                  print("detail button");
                                  print(news[index]);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  print("delete button");
                                  print(news[index]);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () {
                                  print("edit button : ");
                                  print(news[index]);
                                },
                              ),
                            ],
                          ),
                          title: Text(news[index]['title'] ?? "No Title"),
                          subtitle: Text(
                              news[index]['description'] ?? "No Description"),
                        );
                      },
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  label: Text("Add more news"),
                  icon: Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddNewsRoute()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
