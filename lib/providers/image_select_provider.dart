import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class ImageFile extends StateNotifier<XFile?> {
  ImageFile(): super(null);
  void updateFile(XFile? file) => state = file;
}
final fileProvider = StateNotifierProvider.autoDispose<ImageFile, XFile?>((_) => ImageFile());