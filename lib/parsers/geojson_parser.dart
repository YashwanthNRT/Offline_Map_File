import 'dart:convert';
import '../models/geo_models.dart';

RawLayer parseGeoJson(String name, dynamic j) {
  final l = RawLayer(name, 'GeoJSON');
  if (j is Map && j['type'] == 'FeatureCollection') {
    for (final f in (j['features'] as List? ?? [])) {
      final g = f['geometry'];
      if (g is! Map) continue;
      final type = g['type'];
      final coords = g['coordinates'];

      if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
        final outer = [for (final c in coords[0] as List) Pt((c[0] as num).toDouble(), (c[1] as num).toDouble())];
        l.polys.add(RawPoly(outer, [], {}));
      } else if (type == 'Point' && coords is List && coords.length >= 2) {
        l.points.add(RawPoint(Pt((coords[0] as num).toDouble(), (coords[1] as num).toDouble()), {}));
      }
    }
  }
  return l;
}