import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/postgrest_error_mapper.dart';

/// Bucket cap is 5 MB (`kyc` / `complaints`); reject earlier for a clear message.
const maxPhotoBytes = 5 * 1024 * 1024;

class PickedPhoto {
  const PickedPhoto(this.bytes, this.ext, this.mime);
  final Uint8List bytes;
  final String ext;
  final String mime;
}

/// JPEG / PNG by magic bytes (buckets only accept these), else null.
({String ext, String mime})? sniffImage(Uint8List b) {
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return (ext: 'jpg', mime: 'image/jpeg');
  if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return (ext: 'png', mime: 'image/png');
  return null;
}

/// Validates picked bytes (type + size); throws `invalid_input` otherwise.
PickedPhoto toPhoto(Uint8List bytes) {
  final t = sniffImage(bytes);
  if (t == null || bytes.length > maxPhotoBytes) {
    throw const AppFailure('invalid_input', customMessage: 'Ảnh phải là JPG hoặc PNG, tối đa 5MB.');
  }
  return PickedPhoto(bytes, t.ext, t.mime);
}

/// Gallery access behind an interface so screens are testable without a device.
abstract class PhotoPicker {
  Future<PickedPhoto?> pickOne();
  Future<List<PickedPhoto>> pickMany(int limit);
}

/// Client-side resize to <= 1600 px, quality 80 (done by the platform picker).
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pickOne() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    return x == null ? null : toPhoto(await x.readAsBytes());
  }

  @override
  Future<List<PickedPhoto>> pickMany(int limit) async {
    final xs = limit < 2
        ? [?await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80)]
        : await _picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 80, limit: limit);
    return [for (final x in xs.take(limit)) toPhoto(await x.readAsBytes())];
  }
}

/// Uploads under `<uid>/` (the storage policy only allows the caller's own prefix; there is no
/// UPDATE policy, so every upload uses a fresh unique name and never upserts).
class PhotoUploader {
  PhotoUploader(this._db);
  final SupabaseClient _db;

  Future<String> upload({required String bucket, required String uid, required String name, required PickedPhoto photo}) async {
    final path = '$uid/$name.${photo.ext}';
    await _db.storage.from(bucket).uploadBinary(path, photo.bytes, fileOptions: FileOptions(contentType: photo.mime));
    return path;
  }
}
