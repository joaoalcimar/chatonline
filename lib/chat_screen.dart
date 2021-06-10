import 'dart:io';

import 'package:chatonline/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  FirebaseUser? _currentUser;
  bool _isLoading = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<FirebaseUser?> _getUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    try {
      final GoogleSignInAccount googleSignInAccount =
          await googleSignIn.signIn();

      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential authCredential = GoogleAuthProvider.getCredential(
          idToken: googleSignInAuthentication.idToken,
          accessToken: googleSignInAuthentication.accessToken);

      final AuthResult authResult =
          await FirebaseAuth.instance.signInWithCredential(authCredential);

      final FirebaseUser user = authResult.user;

      return user;
    } catch (err) {}
  }

  void _sendMessage({String? text, File? imgFile}) async {
    final FirebaseUser? user = await _getUser();
    Map<String, dynamic> data = {
      "uid": user!.uid,
      "senderName": user!.displayName,
      "senderPhotoUrl": user.photoUrl,
      "time": Timestamp.now()
    };

    if (user == null) {
      _scaffoldKey.currentState!.showSnackBar(SnackBar(
        content: Text("Não foi possível fazer o login, tente novamente"),
        backgroundColor: Colors.red,
      ));
    }

    if (imgFile != null) {
      StorageUploadTask task = FirebaseStorage.instance
          .ref()
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .putFile(imgFile);

      setState(() {
        _isLoading = true;
      });
      StorageTaskSnapshot taskSnapshot = await task.onComplete;
      String url = await taskSnapshot.ref.getDownloadURL();
      data['imgUrl'] = url;

      setState(() {
        _isLoading = false;
      });
    }

    if (text != null) data['text'] = text;

    Firestore.instance.collection('messages').add(data);
  }

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.onAuthStateChanged.listen((user) {
      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _currentUser != null
              ? 'Olá, ${_currentUser!.displayName}'
              : 'Chat App',
        ),
        centerTitle: true,
        elevation: 0,
        actions: <Widget>[
          _currentUser != null
              ? IconButton(
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    googleSignIn.signOut();
                    SnackBar(
                        content: Text("Deslogado com sucesso"),
                        backgroundColor: Colors.red);
                  },
                  icon: Icon(Icons.exit_to_app))
              : Container()
        ],
      ),
      body: Column(children: <Widget>[
        Expanded(
            child: StreamBuilder<QuerySnapshot>(
          stream: Firestore.instance
              .collection('messages')
              .orderBy('time')
              .snapshots(),
          builder: (context, snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                return Center(
                  child: CircularProgressIndicator(),
                );
              default:
                List<DocumentSnapshot> documents =
                    snapshot.data!.documents.reversed.toList();
                return ListView.builder(
                    itemBuilder: (context, index) {
                      return ChatMessage(documents[index].data, documents[index].data['uid'] == _currentUser?.uid
                      );
                    },
                    itemCount: documents.length,
                    reverse: true);
            }
          },
        )
        ),
        _isLoading ? LinearProgressIndicator() : Container(),
        TextComposer(_sendMessage)
      ]),
    );
  }
}
