import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to manage the app's theme mode (light / dark / system).
/// Defaults to system so the user gets the OS theme out of the box.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
