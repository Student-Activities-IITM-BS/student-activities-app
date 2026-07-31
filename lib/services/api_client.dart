import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:student_activities/core/constants.dart';
import 'package:student_activities/services/auth_service.dart';
import 'package:student_activities/screens/auth/login_screen.dart';

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = AuthService.instance.token;
          if (token != null &&
              token.isNotEmpty &&
              !options.extra.containsKey('unauth')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Origin'] = 'https://iitmbs.org';
          options.headers['Content-Type'] = 'application/json';
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final requestPath = e.requestOptions.path;
            if (requestPath != '/auth/logout' &&
                AuthService.instance.token != null) {
              await AuthService.instance.signOut();
              final navState = AuthService.instance.navigatorKey.currentState;
              if (navState != null) {
                navState.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParams);
      return ApiResponse(
        success: true,
        data: response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse> post(String path, {Object? body}) async {
    try {
      final response = await _dio.post(path, data: body);
      return ApiResponse(
        success: true,
        data: response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse> patch(String path, {Object? body}) async {
    try {
      final response = await _dio.patch(path, data: body);
      return ApiResponse(
        success: true,
        data: response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse> put(String path, {Object? body}) async {
    try {
      final response = await _dio.put(path, data: body);
      return ApiResponse(
        success: true,
        data: response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse> delete(String path) async {
    try {
      final response = await _dio.delete(path);
      return ApiResponse(
        success: true,
        data: response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse> postUnauth(String path, {Object? body}) async {
    try {
      final response = await _dio.post(
        path,
        data: body,
        options: Options(extra: {'unauth': true}),
      );
      return ApiResponse(
        success: true,
        data: response.data,
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  ApiResponse _handleDioError(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode;
    final data = response?.data;

    String errorMsg = 'Request failed';
    if (data is Map) {
      errorMsg = (data['error'] ?? data['message'] ?? 'Request failed')
          .toString();
    } else if (response?.statusMessage != null) {
      errorMsg = response!.statusMessage!;
    } else {
      errorMsg = e.message ?? 'Connection error';
    }

    return ApiResponse(
      success: false,
      error: errorMsg,
      statusCode: statusCode,
      data: data,
    );
  }
}

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int? statusCode;

  ApiResponse({required this.success, this.data, this.error, this.statusCode});
}
