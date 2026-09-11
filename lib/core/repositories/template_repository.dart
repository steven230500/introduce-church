import '../models/slide_template.dart';
import '../services/supabase_service.dart';

class TemplateRepository {
  const TemplateRepository(this._supabase);
  final SupabaseService _supabase;

  Future<List<SlideTemplate>> getTemplates() async {
    final rows = await _supabase.client
        .from('templates')
        .select('id, name, config')
        .order('created_at');
    return rows
        .map(
          (r) => SlideTemplate.fromJson(
            id: r['id'] as String,
            name: r['name'] as String,
            json: r['config'] as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<SlideTemplate> saveTemplate(SlideTemplate t) async {
    final userId = _supabase.currentUser!.id;
    final isNew = t.id.startsWith('preset_') || t.id.isEmpty;
    if (isNew) {
      final row = await _supabase.client
          .from('templates')
          .insert({
            'user_id': userId,
            'created_by': userId,
            if (_supabase.orgId != null) 'org_id': _supabase.orgId,
            'name': t.name,
            'config': t.toJson(),
          })
          .select('id, name, config')
          .single();
      return SlideTemplate.fromJson(
        id: row['id'] as String,
        name: row['name'] as String,
        json: row['config'] as Map<String, dynamic>,
      );
    } else {
      await _supabase.client
          .from('templates')
          .update({'name': t.name, 'config': t.toJson()})
          .eq('id', t.id);
      return t;
    }
  }

  Future<void> deleteTemplate(String id) async {
    await _supabase.client.from('templates').delete().eq('id', id);
  }

  Future<void> setCollectionTemplate(String collectionId, String? templateId) async {
    await _supabase.client
        .from('collections')
        .update({'template_id': templateId})
        .eq('id', collectionId);
  }

  Future<void> setItemTemplate(String itemId, String? templateId) async {
    await _supabase.client
        .from('collection_items')
        .update({'template_id': templateId})
        .eq('id', itemId);
  }
}
