import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyDhe5EkPNq4xakFfJI_vqbzPHB2Rdmtu34",
            authDomain: "watr-24fbd.firebaseapp.com",
            projectId: "watr-24fbd",
            storageBucket: "watr-24fbd.appspot.com",
            messagingSenderId: "816399726038",
            appId: "1:816399726038:web:15d80ece334e811b7ca077",
            measurementId: "G-1WGJ44NL8M"));
  } else {
    await Firebase.initializeApp();
  }
}
