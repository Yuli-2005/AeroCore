import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

const _baseUrl = 'https://aerocore-api-issd.onrender.com/api/v1/yulieth-galarza';

final dio = Dio(BaseOptions(
  baseUrl: _baseUrl,
  connectTimeout: const Duration(seconds: 90),
  receiveTimeout: const Duration(seconds: 90),
))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await TokenStorage.read();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      handler.next(error);
    },
  ));