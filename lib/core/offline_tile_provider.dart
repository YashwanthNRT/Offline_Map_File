import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

class OfflineTileProvider extends TileProvider {
  final String path;
  Database? _db;

  OfflineTileProvider(this.path);

  Future<void> init() async {
    _db ??= await openDatabase(path, readOnly: true);
  }

  Future<({LatLngBounds? bounds, int minZoom, int maxZoom})> getTileMetadata() async {
    await init();
    LatLngBounds? bounds;
    int minZoom = 0;
    int maxZoom = 18;

    try {
      final List<Map<String, dynamic>> res = await _db!.query('metadata');
      for (final row in res) {
        final name = row['name']?.toString().toLowerCase();
        final val = row['value']?.toString();
        if (name == 'bounds' && val != null) {
          final parts = val.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
          if (parts.length == 4) {
            bounds = LatLngBounds(LatLng(parts[1], parts[0]), LatLng(parts[3], parts[2]));
          }
        } else if (name == 'minzoom' && val != null) {
          minZoom = int.tryParse(val) ?? 0;
        } else if (name == 'maxzoom' && val != null) {
          maxZoom = int.tryParse(val) ?? 18;
        }
      }
    } catch (_) {}

    return (bounds: bounds, minZoom: minZoom, maxZoom: maxZoom);
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer tileLayer) {
    return OfflineImageProvider(path, coordinates, _db);
  }
}

class OfflineImageProvider extends ImageProvider<OfflineImageProvider> {
  final String path;
  final TileCoordinates coords;
  final Database? db;

  OfflineImageProvider(this.path, this.coords, this.db);

  @override
  Future<OfflineImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future.value(this);
  }

  @override
  ImageStreamCompleter loadImage(OfflineImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(OfflineImageProvider key, ImageDecoderCallback decode) async {
    final database = db ?? await openDatabase(path, readOnly: true);
    final tmsY = (1 << coords.z) - 1 - coords.y;

    List<Map<String, dynamic>> result = [];
    try {
      result = await database.rawQuery(
        'SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?',
        [coords.z, coords.x, tmsY],
      );
    } catch (_) {}

    if (result.isNotEmpty && result.first['tile_data'] != null) {
      final Uint8List bytes = result.first['tile_data'] as Uint8List;
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    }

    // 1x1 Transparent Tile Fallback
    final transparentBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
    final buffer = await ui.ImmutableBuffer.fromUint8List(transparentBytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is OfflineImageProvider &&
          coords.x == other.coords.x &&
          coords.y == other.coords.y &&
          coords.z == other.coords.z;

  @override
  int get hashCode => Object.hash(coords.x, coords.y, coords.z);
}