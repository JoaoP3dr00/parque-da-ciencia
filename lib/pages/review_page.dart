import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({Key? key}) : super(key: key);

  @override
  _ReviewPageState createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late Future<int> _totalReviewsFuture;
  late Future<List<String>> _emailsFuture;
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _totalReviewsFuture = _getTotalReviews();
    _emailsFuture = _getEmails();
  }

  Future<void> sendEmail() async {
    final Uri emailUri = Uri(
        scheme: 'mailto',
        path: 'danielyudicarvalho@gmail.com',
        queryParameters: {'subject': 'Hello from flutter'}
    );

    if (await canLaunch(emailUri.toString())){
      await launch(emailUri.toString());
    }else{
      throw 'Could no launch';
    }
  }

  Future<Database> _openDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = documentsDirectory.path + "/reviews.db";
    return await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
          await db.execute(
              "CREATE TABLE reviews(id INTEGER PRIMARY KEY, review TEXT, isPositive INTEGER)");
        });
  }

  Future<int> _getTotalReviews() async {
    final database = await _openDatabase();
    final count = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM reviews'),
    );
    return count ?? 0; // Return 0 if count is null
  }

  Future<List<String>> _getEmails() async {
    final Database database = await _openEmailsDatabase();
    final List<Map<String, dynamic>> maps = await database.query('emails');
    return List.generate(maps.length, (i) {
      return maps[i]['email'];
    });
  }

  Future<Database> _openEmailsDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = documentsDirectory.path + "/emails.db";
    return await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
          await db.execute("CREATE TABLE emails(id INTEGER PRIMARY KEY, email TEXT)");
        });
  }

  Future<List<Map<String, dynamic>>> _getReviews() async {
    final database = await _openDatabase();
    return await database.query('reviews');
  }

  Future<void> _submitForm(List<String> emails, List<Map<String, dynamic>> reviews) async {
    // Prepare email content
    String emailContent = '';
    for (var review in reviews) {
      emailContent += '${review['review']}\n';
    }

    // Send email to each recipient
    for (var email in emails) {
      final smtpServer = gmail('danielyudicarvalho@gmail.com', 'rkww hvdl qrav fmel');
      final message = Message()
        ..from = Address('danielyudicarvalho@gmail.com', 'Yudi')
        ..recipients.add(email)
        ..subject = 'Reviews'
        ..text = emailContent;

      try {
        await send(message, smtpServer);
        print('email sent');
      } catch (e) {
        print('Error sending email: $e');
      }
    }

    // Delete all reviews from the database
    await _deleteReviews();
  }

  Future<void> _deleteReviews() async {
    final database = await _openDatabase();
    await database.delete('reviews');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FutureBuilder<int>(
                future: _totalReviewsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final totalReviews = snapshot.data!;
                    return Center(
                      child: Text('Total Reviews: $totalReviews'),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  // Display a loading indicator while fetching data
                  return const Center(child: CircularProgressIndicator());
                },
              ),
              SizedBox(height: 20),
              FutureBuilder<List<String>>(
                future: _emailsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final emails = snapshot.data!;
                    return Column(
                      children: [
                        for (var email in emails)
                          ListTile(
                            title: Text(email),
                          ),
                        ElevatedButton(
                          onPressed: () async {
                            final reviews = await _getReviews();
                            _submitForm(emails, reviews);
                          },
                          child: Text('Send Reviews'),
                        ),
                      ],
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  // Display a loading indicator while fetching data
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
