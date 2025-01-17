import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print(e);
  }

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
              .map(
                (doc) => {
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id,
                },
              )
              .toList(),
        );
  } catch (e) {
    throw Exception('Error fetching news: $e');
  }
}

class SeeAllFiles extends StatelessWidget {
  final storageRef = FirebaseStorage.instance.ref().child("image/assets");

  // Method to get all files from storage
  Future<ListResult> listFiles() async {
    ListResult listResults = await storageRef.listAll();
    return listResults;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Displays the contents of all files in storage"),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: FutureBuilder<ListResult>(
        future: listFiles(), // Fetch all files
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
            return Center(child: Text("No files found"));
          }

          // Get all file references
          final files = snapshot.data!.items;

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final fileRef = files[index];

              return FutureBuilder<String>(
                future: fileRef.getDownloadURL(), // Fetch the download URL
                builder: (context, downloadSnapshot) {
                  if (downloadSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return ListTile(
                      leading: CircularProgressIndicator(), // Loading spinner
                      title: Text(fileRef.name),
                      subtitle: Text("Loading image..."),
                    );
                  }

                  if (downloadSnapshot.hasError) {
                    return ListTile(
                      leading: SizedBox(width: 50, height: 50),
                      title: Text(fileRef.name),
                      subtitle: Text("Error loading image"),
                    );
                  }

                  if (downloadSnapshot.hasData) {
                    String downloadUrl = downloadSnapshot.data!;

                    return ListTile(
                      leading: Image.network(
                        downloadUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                      title: Text(downloadUrl),
                    );
                  }

                  return ListTile(
                    title: Text(fileRef.name),
                    subtitle: Text("No image available"),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class UploadImageBody extends StatefulWidget {
  final Reference storageRef;

  const UploadImageBody({Key? key, required this.storageRef}) : super(key: key);

  @override
  _UploadImageBodyState createState() => _UploadImageBodyState();
}

class _UploadImageBodyState extends State<UploadImageBody> {
  Uint8List? _selectedFileBytes;
  String? _fileName;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;

      if (mounted) {
        setState(() {
          _selectedFileBytes = fileBytes;
          _fileName = fileName;
        });
      }
    }
  }

  Future<void> _uploadImage(BuildContext context) async {
    if (_selectedFileBytes == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No file selected')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    try {
      // Upload the file to Firebase Storage
      widget.storageRef
          .child(
              'image/assets/${DateTime.now().millisecondsSinceEpoch.toString()}${_fileName}')
          .putData(_selectedFileBytes!,
              SettableMetadata(contentType: lookupMimeType(_fileName!)));

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      _showAlertDialog(context, true, "File uploaded successfully");
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Upload the image"),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _selectedFileBytes != null
                ? Image.memory(
                    _selectedFileBytes!,
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                  )
                : Placeholder(
                    fallbackHeight: 150,
                    fallbackWidth: 150,
                  ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Select Image'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () {
                      _uploadImage(context);
                    },
              child: Text(_isUploading ? 'Uploading...' : 'Upload Image'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SeeAllFiles()));
                    },
              child: Text("See all..."),
            ),
          ],
        ),
      ),
    );
  }
}

void deleteNews(data, context) async {
  CollectionReference news = FirebaseFirestore.instance.collection('news');

  undoButton(contextButton) {
    // Set up the buttons
    Widget cancelButton = TextButton(
      child: Text("Cancel"),
      onPressed: () {
        Navigator.pop(contextButton); // Close the dialog when Cancel is pressed
      },
    );
    return cancelButton;
  }

  continuedButton(contextButton) {
    Widget continueButton = TextButton(
      child: Text("Continue"),
      onPressed: () async {
        try {
          // Delete the news item from Firestore
          await news.doc(data['id']).delete();
          Navigator.pop(contextButton); // Close the confirmation dialog
        } catch (e) {
          Navigator.pop(contextButton); // Close the dialog if deletion fails
          _showAlertDialog(context, false, "Failed to delete data");
        }
      },
    );
    return continueButton;
  }

  // Set up the AlertDialog
  alertStart(contextAlert) {
    AlertDialog alert = AlertDialog(
      title: Text("Delete Confirmation"),
      content: Text("Would you like to delete this news: ${data['title']}?"),
      actions: [
        undoButton(contextAlert),
        continuedButton(contextAlert),
      ],
    );

    return alert;
  }

  // Show the dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alertStart(context);
    },
  );
}

void _showAlertDialog(
  BuildContext context,
  bool status,
  String message,
) {
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

class DetailNewsRoute extends StatelessWidget {
  final news;

  DetailNewsRoute({required this.news});

  @override
  Widget build(BuildContext context) {
    // Get the screen width to make the image responsive
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double imageHeight = screenWidth * 0.5;
    imageHeight =
        imageHeight < screenHeight * 0.4 ? imageHeight : screenHeight * 0.4;

    return Scaffold(
      appBar: AppBar(
        title: Text("News Detail"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Card(
        elevation: 2,
        margin: EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image of the article
            Container(
              width: double.infinity,
              height: imageHeight, // Use the responsive height
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/cover_image.jpg'),
                  fit: BoxFit.fill, // Make the image cover the entire area
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    "${news['title']}",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('${news['description']}'),
                  SizedBox(height: 8),
                  // Description
                  Text(
                    "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),

                  Text(
                    "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.",
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateNewsRoute extends StatelessWidget {
  final String articleId; // Menerima articleId dari constructor
  final news;
  UpdateNewsRoute({required this.articleId, required this.news});

  @override
  Widget build(BuildContext context) {
    final TextEditingController titleController =
        TextEditingController(text: news['title']);
    final TextEditingController descriptionController =
        TextEditingController(text: news['description']);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text("Update the news"),
        ),
        body: Column(
          children: [
            SizedBox(
              height: 20,
            ),
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
              height: 15,
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
              height: 20,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Menggunakan articleId untuk mengupdate dokumen yang sesuai
                  await FirebaseFirestore.instance
                      .collection("news")
                      .doc(articleId)
                      .update({
                    "title": titleController.text,
                    "description": descriptionController.text,
                    "time_stamp": FieldValue.serverTimestamp(),
                  });
                  _showAlertDialog(
                      context, true, "News successfully updated 👌");
                  // Navigator.pop(context);
                } catch (e) {
                  _showAlertDialog(context, false, e.toString());
                  print(e);
                }
              },
              child: const Text("Update"),
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

class AddNewsRoute extends StatelessWidget {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
                if (titleController.text.isEmpty &&
                    descriptionController.text.isEmpty) {
                  _showAlertDialog(context, false,
                      "Please do not leave any input fields blank");
                } else {
                  try {
                    await FirebaseFirestore.instance.collection("news").add({
                      "title": titleController.text,
                      "description": descriptionController.text,
                      "time_stamp": FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(context);

                    _showAlertDialog(
                        context, true, "News successfully created 👌");
                  } catch (e) {
                    _showAlertDialog(context, false, e.toString());
                    print(e);
                  }
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
                                  // print("detail button");
                                  // print(news[index]);
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => DetailNewsRoute(
                                                news: news[index],
                                              )));
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  deleteNews(news[index], context);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => UpdateNewsRoute(
                                                articleId: news[index]['id'],
                                                news: news[index],
                                              )));
                                },
                              ),
                            ],
                          ),
                          title: Text(news[index]['title'] ?? "No Title"),
                          subtitle: Text(
                            news[index]['description'] ?? "No Description",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  label: Text(
                    "Add more news",
                    style: TextStyle(color: Colors.white70),
                  ),
                  icon: Icon(
                    Icons.add,
                    color: Colors.white70,
                  ),
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
              SizedBox(
                height: 10,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  label: Text(
                    "Upload image",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  icon: Icon(
                    Icons.camera_alt,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UploadImageBody(
                                storageRef: FirebaseStorage.instance.ref(),
                              )),
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
