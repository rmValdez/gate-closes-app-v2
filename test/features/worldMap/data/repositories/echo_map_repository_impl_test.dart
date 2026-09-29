import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/worldMap/data/repositories/echo_map_repository_impl.dart';
import 'package:gate_closes/features/worldMap/domain/entities/echo_map_node_entity.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService api;
  late EchoMapRepositoryImpl repository;

  setUp(() {
    api = MockApiService();
    repository = EchoMapRepositoryImpl(api);
  });

  test('parses GeoJSON features into map nodes', () async {
    when(() => api.get(any(), query: any(named: 'query'))).thenAnswer(
      (_) async => {
        'data': {
          'type': 'FeatureCollection',
          'features': [
            {
              'id': 'e1',
              'geometry': {
                'type': 'Point',
                'coordinates': [103.99, 1.35],
              },
              'properties': {'type': 'baton_touch', 'senderId': 'u9'},
            },
          ],
        },
      },
    );

    final result = await repository.getNodes();

    final nodes = result.getOrElse((_) => fail('expected Right'));
    expect(nodes, hasLength(1));
    expect(nodes.single.id, 'e1');
    expect(nodes.single.nodeKind, EchoNodeKind.batonTouch);
    expect(nodes.single.longitude, 103.99);
    expect(nodes.single.latitude, 1.35);
  });

  test('sends the bounding box only when all four edges are given', () async {
    when(
      () => api.get(any(), query: any(named: 'query')),
    ).thenAnswer((_) async => {'data': <String, dynamic>{}});

    await repository.getNodes(west: 1, south: 2, east: 3, north: 4);
    await repository.getNodes(west: 1);

    final queries = verify(
      () => api.get(
        ApiEndpoints.terminalEchoMap,
        query: captureAny(named: 'query'),
      ),
    ).captured;
    expect(queries.first, {'west': 1, 'south': 2, 'east': 3, 'north': 4});
    expect(queries.last, isNull);
  });

  test('maps a network error to NetworkFailure', () async {
    when(
      () => api.get(any(), query: any(named: 'query')),
    ).thenThrow(const NetworkException());

    final result = await repository.getNodes();

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
  });
}
