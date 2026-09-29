import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/world_map_controller.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:gate_closes/shared/widgets/app_card.dart';
import 'package:gate_closes/shared/widgets/app_state_view.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

enum MapDisplayMode { spatialView, nearbyList }

const Map<String, Object> _kEmptyFeatureCollection = {
  'type': 'FeatureCollection',
  'features': <Object>[],
};
const _kAirportBoundarySourceId = 'airport-boundaries-source';
const _kEchoNodesManagerId = 'echo-nodes-annotation-manager';

class WorldMapPage extends ConsumerStatefulWidget {
  const WorldMapPage({super.key});

  @override
  ConsumerState<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends ConsumerState<WorldMapPage> {
  MapDisplayMode _mode = MapDisplayMode.spatialView;

  MapboxMap? _mapboxMap;
  GeoJsonSource? _boundarySource;
  CircleAnnotationManager? _echoAnnotationManager;
  Timer? _boundsDebounceTimer;
  AirportEntity? _lastFlownToAirport;

  @override
  void dispose() {
    _boundsDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WorldMapState>(worldMapControllerProvider, _onStateChanged);

    final state = ref.watch(worldMapControllerProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          _mode == MapDisplayMode.spatialView
              ? (state.selectedAirport != null
                  ? '${state.selectedAirport!.iata} — Terminal Map'
                  : 'Terminal Map')
              : 'Nearby Airports',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _mode == MapDisplayMode.spatialView
                ? 'List view'
                : 'Spatial map',
            icon: Icon(
              _mode == MapDisplayMode.spatialView
                  ? Icons.view_list_rounded
                  : Icons.map_rounded,
              color: colors.textPrimary,
            ),
            onPressed: () {
              setState(() {
                _mode = _mode == MapDisplayMode.spatialView
                    ? MapDisplayMode.nearbyList
                    : MapDisplayMode.spatialView;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(worldMapControllerProvider.notifier).initMapData(),
        child: _mode == MapDisplayMode.spatialView
            ? _buildSpatialView(context, colors, state)
            : _buildNearbyList(context, colors, state),
      ),
    );
  }

  void _onStateChanged(WorldMapState? previous, WorldMapState next) {
    final boundaryChanged = !identical(
      previous?.airportBoundariesGeoJson,
      next.airportBoundariesGeoJson,
    );
    if (boundaryChanged) {
      unawaited(_syncBoundary(next.airportBoundariesGeoJson));
    }
    if (previous?.echoNodes != next.echoNodes) {
      unawaited(_syncEchoNodes(next.echoNodes));
    }
    if (previous?.selectedAirport != next.selectedAirport) {
      _flyToAirport(next.selectedAirport);
    }
  }

  Widget _buildSpatialView(
    BuildContext context,
    GateColors colors,
    WorldMapState state,
  ) {
    if (state.isLoading && state.echoNodes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final selected = state.selectedAirport;

    return Stack(
      children: [
        Positioned.fill(
          child: MapWidget(
            key: const ValueKey('world-map-widget'),
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            onMapIdleListener: _onMapIdle,
          ),
        ),

        // Foreground content overlay
        SafeArea(
          child: Column(
            children: [
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: GlassCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              colors.accent.withValues(alpha: 0.18),
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            color: colors.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.name,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${selected.iata} · '
                                '${selected.detectionState.name}',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.airports.length > 1)
                          PopupMenuButton<AirportEntity>(
                            icon: Icon(
                              Icons.expand_more_rounded,
                              color: colors.textMuted,
                            ),
                            onSelected: (airport) => ref
                                .read(worldMapControllerProvider.notifier)
                                .selectAirport(airport),
                            itemBuilder: (_) => state.airports
                                .map(
                                  (a) => PopupMenuItem(
                                    value: a,
                                    child: Text('${a.iata} - ${a.name}'),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyList(
    BuildContext context,
    GateColors colors,
    WorldMapState state,
  ) {
    if (state.isLoading && state.airports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.airports.isEmpty) {
      return AppStateView(
        kind: AppStateKind.error,
        title: 'Could not load nearby airports',
        message: state.error,
        actionLabel: 'Retry',
        onAction: () =>
            ref.read(worldMapControllerProvider.notifier).initMapData(),
      );
    }

    if (state.airports.isEmpty) {
      return const AppStateView(
        kind: AppStateKind.empty,
        title: 'No nearby airports',
        message: 'Nothing within range of your current location.',
      );
    }

    return ListView.separated(
      padding: AppSpacing.edgeInsetsMd,
      itemCount: state.airports.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final airport = state.airports[index];
        final isSelected = airport.id == state.selectedAirport?.id;

        return AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? colors.accent
                  : colors.accent.withValues(alpha: 0.15),
              child: Icon(
                Icons.flight_takeoff_rounded,
                color: isSelected ? colors.accentOn : colors.accent,
                size: 20,
              ),
            ),
            title: Text(
              airport.name,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              [
                airport.iata,
                if (airport.countryCode != null) airport.countryCode!,
                if (airport.distanceKm != null)
                  '${airport.distanceKm!.toStringAsFixed(0)} km',
              ].join(' · '),
              style: TextStyle(color: colors.textSecondary),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colors.accent)
                : null,
            onTap: () {
              ref
                  .read(worldMapControllerProvider.notifier)
                  .selectAirport(airport);
              setState(() => _mode = MapDisplayMode.spatialView);
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Mapbox wiring
  // ---------------------------------------------------------------------

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
    final selected = ref.read(worldMapControllerProvider).selectedAirport;
    if (selected != null) {
      _flyToAirport(selected, animated: false);
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _mapboxMap;
    if (map == null) return;

    final boundarySource = GeoJsonSource(
      id: _kAirportBoundarySourceId,
      data: jsonEncode(_kEmptyFeatureCollection),
    );
    await map.style.addSource(boundarySource);
    _boundarySource = boundarySource;

    // Ported from gate-closes-app's AirportBoundariesLayer.tsx: fill +
    // outline glow + crisp outline, same colors/opacities.
    await map.style.addLayer(
      FillLayer(
        id: 'airport-boundaries-fill',
        sourceId: _kAirportBoundarySourceId,
        fillColor: const Color(0xFF7F8792).toARGB32(),
        fillOpacity: 0.16,
      ),
    );
    await map.style.addLayer(
      LineLayer(
        id: 'airport-boundaries-outline-glow',
        sourceId: _kAirportBoundarySourceId,
        lineColor: const Color(0xFF7F8792).toARGB32(),
        lineOpacity: 0.34,
        lineWidth: 6,
      ),
    );
    await map.style.addLayer(
      LineLayer(
        id: 'airport-boundaries-outline',
        sourceId: _kAirportBoundarySourceId,
        lineColor: const Color(0xFFC4CBD4).toARGB32(),
        lineWidth: 1.5,
      ),
    );

    final manager = await map.annotations.createCircleAnnotationManager(
      id: _kEchoNodesManagerId,
    );
    manager.tapEvents(onTap: _onEchoAnnotationTap);
    _echoAnnotationManager = manager;

    if (!mounted) return;
    final state = ref.read(worldMapControllerProvider);
    await _syncBoundary(state.airportBoundariesGeoJson);
    await _syncEchoNodes(state.echoNodes);
  }

  void _onMapIdle(MapIdleEventData _) {
    _boundsDebounceTimer?.cancel();
    _boundsDebounceTimer =
        Timer(const Duration(milliseconds: 300), _refetchNodesForCurrentBounds);
  }

  Future<void> _refetchNodesForCurrentBounds() async {
    final map = _mapboxMap;
    if (map == null) return;

    final cameraState = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(
      CameraOptions(
        center: cameraState.center,
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      ),
    );

    if (!mounted) return;
    await ref.read(worldMapControllerProvider.notifier).fetchEchoNodesForBounds(
          west: bounds.southwest.coordinates.lng.toDouble(),
          south: bounds.southwest.coordinates.lat.toDouble(),
          east: bounds.northeast.coordinates.lng.toDouble(),
          north: bounds.northeast.coordinates.lat.toDouble(),
        );
  }

  Future<void> _syncBoundary(Map<String, dynamic>? geoJson) async {
    final source = _boundarySource;
    if (source == null) return;
    await source.updateGeoJSON(jsonEncode(geoJson ?? _kEmptyFeatureCollection));
  }

  Future<void> _syncEchoNodes(List<TerminalEchoMapNodeEntity> nodes) async {
    final manager = _echoAnnotationManager;
    if (manager == null || !mounted) return;

    final colors = context.colors;
    await manager.deleteAll();
    if (nodes.isEmpty) return;

    await manager.createMulti(
      nodes.map((node) => _echoNodeCircleOptions(node, colors)).toList(),
    );
  }

  CircleAnnotationOptions _echoNodeCircleOptions(
    TerminalEchoMapNodeEntity node,
    GateColors colors,
  ) {
    return CircleAnnotationOptions(
      geometry: Point(coordinates: Position(node.longitude, node.latitude)),
      circleRadius: node.isNew ? 10.0 : 8.0,
      circleColor: _colorForNodeKind(node.nodeKind, colors).toARGB32(),
      circleOpacity: 0.92,
      circleStrokeColor: Colors.white.withValues(alpha: 0.85).toARGB32(),
      circleStrokeWidth: node.isNew ? 2.5 : 1.5,
      customData: {'nodeId': node.id},
    );
  }

  Color _colorForNodeKind(EchoNodeKind kind, GateColors colors) =>
      switch (kind) {
        EchoNodeKind.parallelSoul => const Color(0xFF6366F1),
        EchoNodeKind.destinationThread => const Color(0xFF10B981),
        EchoNodeKind.batonTouch => const Color(0xFFF59E0B),
        EchoNodeKind.terminalEcho => colors.accent,
      };

  void _onEchoAnnotationTap(CircleAnnotation annotation) {
    final nodeId = annotation.customData?['nodeId'] as String?;
    if (nodeId == null || nodeId.isEmpty) return;
    unawaited(_openEchoThread(nodeId));
  }

  Future<void> _openEchoThread(String nodeId) async {
    // The thread route loads the echo by id — no terminal_echo import needed.
    await context.push(RouteNames.echoThreadFor(nodeId));
  }

  void _flyToAirport(AirportEntity? airport, {bool animated = true}) {
    final map = _mapboxMap;
    final lat = airport?.latitude;
    final lng = airport?.longitude;
    if (map == null || lat == null || lng == null) return;
    if (identical(airport, _lastFlownToAirport)) return;
    _lastFlownToAirport = airport;

    final camera = CameraOptions(
      center: Point(coordinates: Position(lng, lat)),
      zoom: 15,
      pitch: 0,
      bearing: 0,
    );

    if (animated) {
      unawaited(map.flyTo(camera, MapAnimationOptions(duration: 800)));
    } else {
      unawaited(map.setCamera(camera));
    }
  }
}
