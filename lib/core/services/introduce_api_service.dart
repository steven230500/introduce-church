import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

class ApiUploadResult {
  const ApiUploadResult({
    required this.url,
    required this.filename,
    required this.category,
    required this.sizeBytes,
  });

  final String url;
  final String filename;
  final String category;
  final int sizeBytes;

  String get storagePath => '$category/$filename';
}

class IntroduceApiService {
  const IntroduceApiService(this._dio);
  final Dio _dio;

  Future<ApiUploadResult> upload(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: p.basename(file.path)),
    });

    final response = await _dio.post<Map<String, dynamic>>('/media/upload', data: formData);

    final data = response.data!;
    return ApiUploadResult(
      url: data['url'] as String,
      filename: data['filename'] as String,
      category: data['category'] as String,
      sizeBytes: ((data['size_kb'] as int? ?? 0) * 1024),
    );
  }

  Future<void> delete(String category, String filename) async {
    await _dio.delete<void>('/media/$category/$filename');
  }
}
