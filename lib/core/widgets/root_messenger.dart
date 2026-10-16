import 'package:flutter/material.dart';

/// App-root [ScaffoldMessengerState] key, wired into `MaterialApp.router` via
/// `scaffoldMessengerKey`. Lets background/detached work (e.g. the OCR feedback
/// upload that outlives the review screen) show a toast on whatever screen is
/// now foreground, independent of any disposed widget's context. The `?.` guard
/// at the call site drops the toast harmlessly if the app was torn down.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();
