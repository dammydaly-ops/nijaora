import 'dart:io';

import 'package:nijagig/data/reference/catalog_taxonomy.dart';

String _text(String value) => "'${value.replaceAll("'", "''")}'";

String _array(List<String> values) {
  if (values.isEmpty) return "'{}'::text[]";
  return 'array[${values.map(_text).join(', ')}]';
}

void main() {
  final categories = buildCatalogCategories();
  final out = StringBuffer()
    ..writeln(
      'insert into public.categories '
      '(id, parent_id, name, description, synonyms, kind, sort_order) values',
    );

  for (var i = 0; i < categories.length; i++) {
    final category = categories[i];
    final parent = category.parentId == null ? 'null' : _text(category.parentId!);
    final row = '  (${_text(category.id)}, $parent, ${_text(category.name)}, '
        '${_text(category.description)}, ${_array(category.synonyms)}, '
        "'${category.kind.name}', $i)";
    out.writeln('$row${i == categories.length - 1 ? '' : ','}');
  }

  out.writeln(
    'on conflict (id) do update set '
    'parent_id = excluded.parent_id, '
    'name = excluded.name, '
    'description = excluded.description, '
    'synonyms = excluded.synonyms, '
    'kind = excluded.kind, '
    'sort_order = excluded.sort_order;',
  );

  stdout.write(out.toString());
}
