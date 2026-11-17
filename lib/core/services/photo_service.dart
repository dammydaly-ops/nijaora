import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Picks local photos and turns them into portable data URLs for the current
/// demo/local backend. When Supabase Storage is wired, this service will upload
/// the same bytes and return public object URLs instead.
class PhotoService {
  PhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<List<String>> pickPortfolioPhotos({required int limit}) async {
    if (limit <= 0) return const [];
    final files = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
      limit: limit,
    );
    return _toDataUrls(files);
  }

  Future<String?> pickOwnerPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      maxHeight: 900,
      imageQuality: 82,
    );
    if (file == null) return null;
    final urls = await _toDataUrls([file]);
    return urls.isEmpty ? null : urls.first;
  }

  /// Uploads a picked data URL to Supabase Storage when auth is live.
  /// Falls back to the local data URL in demo mode.
  Future<String> uploadBusinessPhoto({
    required String businessId,
    required String dataUrl,
    required String fileName,
  }) async {
    return _upload(
      bucket: 'business-photos',
      path: '$businessId/$fileName',
      dataUrl: dataUrl,
    );
  }

  Future<String> uploadOwnerPhoto({
    required String ownerId,
    required String dataUrl,
    required String fileName,
  }) async {
    return _upload(
      bucket: 'profile-photos',
      path: '$ownerId/$fileName',
      dataUrl: dataUrl,
    );
  }

  Future<String> _upload({
    required String bucket,
    required String path,
    required String dataUrl,
  }) async {
    if (!AppConfig.supabaseConfigured) return dataUrl;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return dataUrl;
    final bytes = _decodeDataUrl(dataUrl);
    if (bytes == null) return dataUrl;

    await client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _mimeFromDataUrl(dataUrl),
          ),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  Uint8List? _decodeDataUrl(String value) {
    if (!value.startsWith('data:image/')) return null;
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(value.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  String _mimeFromDataUrl(String value) {
    final start = value.indexOf(':');
    final end = value.indexOf(';');
    if (start < 0 || end <= start) return 'image/jpeg';
    return value.substring(start + 1, end);
  }

  Future<List<String>> _toDataUrls(List<XFile> files) async {
    final urls = <String>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? _mimeFromName(file.name);
      urls.add('data:$mime;base64,${base64Encode(bytes)}');
    }
    return urls;
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
