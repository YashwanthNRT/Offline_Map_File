import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/offline_tile_provider.dart';
import '../models/geo_models.dart';
import '../services/map_parser_service.dart';

class TacticalMapScreen extends StatefulWidget {
  const TacticalMapScreen({super.key});

  @override
  State<TacticalMapScreen> createState() => _TacticalMapScreenState();
}

class _TacticalMapScreenState extends State<TacticalMapScreen> {
  final MapController _mapController = MapController();
  OfflineTileProvider? _tileProvider;
  final List<GeoLayer> _vectorLayers = [];
  bool _isLoading = false;

  // Set default zoom constraints
  double _minZoom = 1.0;
  double _maxZoom = 18.0;

  Future<void> _pickAndUploadMap() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'mbtiles', 'gpkg', 'kml', 'geojson', 'json', 'shp', 'zip'
        ],
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        _isLoading = true;
      });

      final file = result.files.first;
      final ext = file.name.split('.').last.toLowerCase();

      // RASTER ENGINE ROUTE (.mbtiles / .gpkg)
      if ((ext == 'mbtiles' || ext == 'gpkg') && file.path != null) {
        final provider = OfflineTileProvider(file.path!);
        final meta = await provider.getTileMetadata();

        setState(() {
          _tileProvider = provider;
          _minZoom = meta.minZoom.toDouble();
          _maxZoom = meta.maxZoom.toDouble();
          _isLoading = false;
        });

        if (meta.bounds != null) {
          // Move camera to bounds AND set zoom inside valid MBTiles zoom range
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: meta.bounds!,
              padding: const EdgeInsets.all(20),
              maxZoom: _maxZoom,
            ),
          );
        } else {
          // Fallback if metadata is missing bounds: move directly to zoom level created in QGIS
          _mapController.move(const LatLng(0, 0), _minZoom > 0 ? _minZoom : 12.0);
        }
        return;
      }

      // VECTOR ENGINE ROUTE (.kml, .geojson, .shp)
      final inputFiles = [
        for (final f in result.files)
          if (f.bytes != null) InputFile(f.name, f.bytes!, path: f.path)
      ];

      final outcome = await compute(
        parseInIsolate,
        ParseRequest(inputFiles),
      );

      if (mounted && outcome.layers.isNotEmpty) {
        setState(() {
          _vectorLayers.addAll(outcome.layers);
          _isLoading = false;
        });

        final bounds = outcome.layers.first.bounds;
        if (bounds != null) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(40),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading map: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20, 0),
              initialZoom: 3,
              minZoom: _minZoom,
              maxZoom: _maxZoom,
              backgroundColor: const Color(0xFF0F1412),
            ),
            children: [
              if (_tileProvider != null)
                TileLayer(
                  tileProvider: _tileProvider,
                  minNativeZoom: _minZoom.toInt(),
                  maxNativeZoom: _maxZoom.toInt(),
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                ),
              for (final layer in _vectorLayers) ...[
                if (layer.polys.isNotEmpty)
                  PolygonLayer(
                    polygons: [
                      for (final p in layer.polys)
                        Polygon(
                          points: p.outer,
                          color: const Color(0xFF00FF66).withOpacity(0.25),
                          borderColor: const Color(0xFF00FF66),
                          borderStrokeWidth: 2,
                        )
                    ],
                  ),
                if (layer.points.isNotEmpty)
                  CircleLayer(
                    circles: [
                      for (final p in layer.points)
                        CircleMarker(
                          point: p.p,
                          radius: 5,
                          color: const Color(0xFFFF3D00),
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.5,
                        )
                    ],
                  ),
              ],
            ],
          ),

          // Tactical Frame HUD Overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0x2200FF66), width: 2),
              ),
            ),
          ),

          // Floating Command Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 220,
                height: 56,
                child: FloatingActionButton.extended(
                  onPressed: _isLoading ? null : _pickAndUploadMap,
                  backgroundColor: const Color(0xFF00FF66),
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.upload_file_rounded, size: 28),
                  label: const Text(
                    "UPLOAD MAP",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: const Color(0xB3000000),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FF66)),
              ),
            ),
        ],
      ),
    );
  }
}
















