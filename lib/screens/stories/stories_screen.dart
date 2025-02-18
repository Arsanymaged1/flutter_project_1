import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_project_1/data/user_story.dart';
import 'package:image_picker/image_picker.dart';

import 'stories_view.dart';

class StoriesScreen extends StatelessWidget {
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  StoriesScreen({super.key});

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _addStory(ImageSource source) async {

    // if (currentUserId == null) {
    //   print('User is not authenticated');
    //   return;
    // }

    final ImagePicker imagePicker = ImagePicker();
    final XFile? img = await imagePicker.pickImage(source: source);

    if (img != null) {
      File file = File(img.path);

      DocumentReference docRef = _fireStore.collection('stories').doc();

      Reference ref = _storage.ref().child('stories/${docRef.id}');

      await ref.putFile(file);
      String getURL = await ref.getDownloadURL();

      await docRef.set({
        'id' : docRef.id,
        'userId': currentUserId,
        'imgURL': getURL,
        'timeStamp': FieldValue.serverTimestamp()
      });
    }
  }

  void _showImageSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Story'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _addStory(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _addStory(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _fireStore.collection('stories')
              .orderBy('timeStamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            List<UserStory> allStories = [];
            if (snapshot.hasData) {
              allStories = snapshot.data!.docs.map((doc) {
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                return UserStory(
                    id: doc.id,
                    userId: data['userId'] as String? ?? '',
                    timeStamp: (data['timeStamp'] as Timestamp?)!.toDate(),
                    imgURL: data['imgURL'] as String? ?? ''
                );
              }).toList();
            }

            UserStory? userStory = allStories.firstWhereOrNull(
                  (story) => story.userId == currentUserId,
            );

            List<UserStory> contactStories = allStories.where(
                    (story) => story.userId != currentUserId
            ).toList();

            return Container(
              color: const Color(0xFF000E08),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoriesView(
                    story: userStory,
                    isUserStory: true,
                    onAddStory: () => _showImageSourceDialog(context),
                  ),
                  Expanded(
                    child: contactStories.isEmpty
                        ? const Text('No stories from contacts', style: TextStyle(color: Colors.white))
                        : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: contactStories.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: StoriesView(story: contactStories[index], isUserStory: false),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}