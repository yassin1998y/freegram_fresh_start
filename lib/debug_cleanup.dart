import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freegram/firebase_options.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = FirebaseFirestore.instance;
  final collection = db.collection('random_chat_rooms');

  print("Fetching all rooms...");
  final snapshot = await collection.get();
  print("Found ${snapshot.docs.length} rooms.");

  int deleted = 0;
  for (var doc in snapshot.docs) {
    await doc.reference.delete();
    deleted++;
  }
  print("Deleted $deleted rooms.");

  // Test Query
  print("Testing App Query...");
  try {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 15));
    final querySnapshot = await collection
        .where('status', isEqualTo: 'waiting')
        .where('lastHeartbeat', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('lastHeartbeat', descending: true)
        .limit(1)
        .get();
    print(
        "Query success! (Result empty as expected: ${querySnapshot.docs.isEmpty})");
  } catch (e) {
    print("QUERY FAILED: $e");
    print("Likely index issue.");
  }
}
