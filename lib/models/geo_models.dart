import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Pt {
  final double x, y;
  const Pt(this.x, this.y);
}

class InputFile {
  final String name;
  final Uint8List bytes;
  final String? path;
  InputFile(this.name, this.bytes, {this.path});

  String get displayName => name.split('/').last;

  String get ext {
    final n = displayName;
    final i = n.lastIndexOf('.');
    return i < 0 ? '' : n.substring(i + 1).toLowerCase();
  }

  String get baseName {
    final i = name.lastIndexOf('.');
    final cut = i > name.lastIndexOf('/') ? i : name.length;
    return name.substring(0, cut).toLowerCase();
  }
}

class RawPoint {
  final Pt p;
  final Map<String, dynamic> props;
  RawPoint(this.p, this.props);
}

class RawLine {
  final List<Pt> pts;
  final Map<String, dynamic> props;
  RawLine(this.pts, this.props);
}

class RawPoly {
  final List<Pt> outer;
  final List<List<Pt>> holes;
  final Map<String, dynamic> props;
  RawPoly(this.outer, this.holes, this.props);
}

class RawLayer {
  final String name;
  String format;
  final List<RawPoint> points = [];
  final List<RawLine> lines = [];
  final List<RawPoly> polys = [];
  RawLayer(this.name, this.format);

  bool get isEmpty => points.isEmpty && lines.isEmpty && polys.isEmpty;
}

class GeoPoint {
  final LatLng p;
  final Map<String, dynamic> props;
  GeoPoint(this.p, this.props);
}

class GeoLine {
  final List<LatLng> pts;
  final Map<String, dynamic> props;
  GeoLine(this.pts, this.props);
}

class GeoPoly {
  final List<LatLng> outer;
  final List<List<LatLng>> holes;
  final Map<String, dynamic> props;
  GeoPoly(this.outer, this.holes, this.props);
}

class GeoLayer {
  final String name;
  final String format;
  final List<GeoPoint> points;
  final List<GeoLine> lines;
  final List<GeoPoly> polys;

  GeoLayer({
    required this.name,
    required this.format,
    this.points = const [],
    this.lines = const [],
    this.polys = const [],
  });

  LatLngBounds? get bounds {
    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    void add(double lat, double lon) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }

    for (final p in points) {
      add(p.p.latitude, p.p.longitude);
    }
    for (final l in lines) {
      for (final p in l.pts) {
        add(p.latitude, p.longitude);
      }
    }
    for (final g in polys) {
      for (final p in g.outer) {
        add(p.latitude, p.longitude);
      }
    }
    if (minLat > maxLat) return null;
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }
}