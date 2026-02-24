import 'package:flutter/material.dart';

/// Global key for the root navigator state, used for navigation without context.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global key for the scaffold messenger state, used for showing snackbars without context.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
