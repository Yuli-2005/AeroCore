import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_client.dart';

/// Conecta al endpoint SSE y emite eventos { flightClassId, flightId, availableSeats }.
/// Se desconecta automáticamente cuando se cancela el StreamSubscription.
Stream<Map<String, dynamic>> sseAvailability(String flightId) async* {
  final controller = StreamController<Map<String, dynamic>>();

  dio.get(
    '/flights/$flightId/availability/stream',
    options: Options(
      responseType: ResponseType.stream,
      receiveTimeout: const Duration(hours: 1),
    ),
  ).then((response) {
    final stream = response.data.stream as Stream<List<int>>;
    final buffer = StringBuffer();

    stream.listen(
      (bytes) {
        buffer.write(utf8.decode(bytes, allowMalformed: true));
        final raw = buffer.toString();
        final lines = raw.split('\n');
        buffer.clear();
        // Si la última línea no termina en \n la guardamos para el siguiente chunk
        if (!raw.endsWith('\n')) {
          buffer.write(lines.removeLast());
        }
        for (final line in lines) {
          if (line.startsWith('data:')) {
            final json = line.substring(5).trim();
            if (json.isNotEmpty) {
              try {
                final decoded = jsonDecode(json) as Map<String, dynamic>;
                if (!controller.isClosed) controller.add(decoded);
              } catch (_) {}
            }
          }
        }
      },
      onDone: () => controller.close(),
      onError: (_) => controller.close(),
      cancelOnError: true,
    );
  }).catchError((_) { controller.close(); });

  yield* controller.stream;
}