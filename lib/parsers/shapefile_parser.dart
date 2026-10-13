import 'dart:typed_data';
import '../models/geo_models.dart';

RawLayer parseShapefile(String name, Uint8List shp) {
  final l = RawLayer(name, 'Shapefile');
  final bd = ByteData.sublistView(shp);
  var pos = 100;

  while (pos + 8 <= shp.length) {
    final len = bd.getInt32(pos + 4, Endian.big) * 2;
    final s = pos + 8;
    if (len < 4 || s + len > shp.length) break;
    pos = s + len;
    final type = bd.getInt32(s, Endian.little);

    if (type == 5) { // Polygon
      final np = bd.getInt32(s + 36, Endian.little);
      final npts = bd.getInt32(s + 40, Endian.little);
      final parts = [for (var i = 0; i < np; i++) bd.getInt32(s + 44 + 4 * i, Endian.little)];
      final base = s + 44 + 4 * np;
      List<Pt> seg(int a, int b) => [for (var i = a; i < b; i++) Pt(bd.getFloat64(base + i * 16, Endian.little), bd.getFloat64(base + i * 16 + 8, Endian.little))];
      final rings = [for (var i = 0; i < np; i++) seg(parts[i], i + 1 < np ? parts[i + 1] : npts)];
      if (rings.isNotEmpty) l.polys.add(RawPoly(rings.first, rings.skip(1).toList(), {}));
    }
  }
  return l;
}