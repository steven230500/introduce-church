import '../api/api_client.dart';
import '../models/slide_template.dart';

class TemplateRepository {
  const TemplateRepository(this._api);
  final ApiClient _api;

  Future<List<SlideTemplate>> getTemplates() async => parseTemplates(await getTemplatesRaw());

  /// The rows exactly as the server sent them, so they can be cached for the
  /// Sundays when the building has no internet.
  Future<List<Map<String, dynamic>>> getTemplatesRaw() async {
    final rows = await _api.get<List<dynamic>>('/templates');
    return (rows ?? []).cast<Map<String, dynamic>>();
  }

  static List<SlideTemplate> parseTemplates(List<Map<String, dynamic>> rows) => rows
      .map(
        (row) => SlideTemplate.fromJson(
          id: row['id'] as String,
          name: row['name'] as String,
          json: Map<String, dynamic>.from(row['config'] as Map),
        ),
      )
      .toList();

  /// Creates or replaces a design.
  ///
  /// A preset id means the operator started from a built-in and is saving their
  /// own copy, so it is created rather than updated.
  Future<SlideTemplate> saveTemplate(SlideTemplate t) async {
    final isNew = t.id.startsWith('preset_') || t.id.isEmpty;
    final payload = {'name': t.name, 'config': t.toJson()};

    final body = isNew
        ? await _api.post<Map<String, dynamic>>('/templates', data: payload)
        : await _api.put<Map<String, dynamic>>('/templates/${t.id}', data: payload);

    return SlideTemplate.fromJson(
      id: body!['id'] as String,
      name: body['name'] as String,
      json: Map<String, dynamic>.from(body['config'] as Map),
    );
  }

  Future<void> deleteTemplate(String id) async {
    await _api.delete<void>('/templates/$id');
  }

  Future<void> setCollectionTemplate(String collectionId, String? templateId) async {
    await _api.patch<void>('/collections/$collectionId', data: {'template_id': templateId});
  }

  Future<void> setItemTemplate(String itemId, String? templateId) async {
    await _api.patch<void>('/collections/items/$itemId', data: {'template_id': templateId});
  }
}
