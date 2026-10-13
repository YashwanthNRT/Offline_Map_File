import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../models/geo_models.dart';
import '../parsers/geojson_parser.dart';
import '../parsers/shapefile_parser.dart';
import '../parsers/xml_parsers.dart';

class ParseRequest {
  final List<InputFile> files;
  ParseRequest(this.files);
}

class ParseOutcome {
  final List<GeoLayer> layers = [];
  final List<String> messages = [];
}

ParseOutcome parseInIsolate(ParseRequest req) {
  final out = ParseOutcome();
  for (final f in req.files) {
    try {
      final raw = _parseOne(f, req.files);
      if (raw != null && !raw.isEmpty) {
        out.layers.add(_finalizeLayer(raw));
      }
    } catch (e) {
      out.messages.add('${f.displayName}: $e');
    }
  }
  return out;
}

RawLayer? _parseOne(InputFile f, List<InputFile> all) {
  final text = utf8.decode(f.bytes, allowMalformed: true);
  switch (f.ext) {
    case 'kml':
      return parseKml(f.displayName, text);
    case 'geojson' || 'json':
      return parseGeoJson(f.displayName, jsonDecode(text));
    case 'shp':
      return parseShapefile(f.displayName, f.bytes);
    default:
      return null;
  }
}

GeoLayer _finalizeLayer(RawLayer raw) {
  LatLng c(Pt p) => LatLng(p.y, p.x);
  return GeoLayer(
    name: raw.name,
    format: raw.format,
    points: [for (final p in raw.points) GeoPoint(c(p.p), p.props)],
    polys: [for (final g in raw.polys) GeoPoly([for (final q in g.outer) c(q)], [], g.props)],
  );
}