import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import '../models/geo_models.dart';

RawLayer parseKml(String name, String text) {
  final doc = XmlDocument.parse(text);
  final l = RawLayer(name, 'KML');

  for (final pm in doc.descendantElements.where((e) => e.name.local == 'Placemark')) {
    // Points
    for (final pt in pm.descendantElements.where((e) => e.name.local == 'Point')) {
      final cStr = pt.descendantElements.where((e) => e.name.local == 'coordinates').firstOrNull?.innerText.trim();
      if (cStr != null) {
        final parts = cStr.split(',');
        if (parts.length >= 2) {
          final x = double.tryParse(parts[0]), y = double.tryParse(parts[1]);
          if (x != null && y != null) l.points.add(RawPoint(Pt(x, y), {}));
        }
      }
    }
    // Polygons
    for (final poly in pm.descendantElements.where((e) => e.name.local == 'Polygon')) {
      final outer = poly.descendantElements.where((e) => e.name.local == 'outerBoundaryIs').firstOrNull;
      if (outer == null) continue;
      final coords = outer.descendantElements.where((e) => e.name.local == 'coordinates').firstOrNull?.innerText.trim() ?? '';
      final pts = <Pt>[];
      for (final t in coords.split(RegExp(r'\s+'))) {
        final p = t.split(',');
        if (p.length >= 2) {
          final x = double.tryParse(p[0]), y = double.tryParse(p[1]);
          if (x != null && y != null) pts.add(Pt(x, y));
        }
      }
      if (pts.length >= 3) l.polys.add(RawPoly(pts, [], {}));
    }
  }
  return l;
}