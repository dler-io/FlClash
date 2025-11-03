import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/models/models.dart';

/// Dler Cloud API 客户端
/// API 文档: https://docs.dler.io/black-hole/api/v1/account
class DlerCloudApi {
  static const String baseUrl = 'https://dler.cloud/api/v1';
  final Dio _dio;

  DlerCloudApi({Dio? dio}) : _dio = dio ?? Dio();

  /// 登录（获取 Token）
  /// 
  /// [email] 用户邮箱
  /// [passwd] 用户密码
  /// [tokenExpire] Token 过期时间（单位：天，默认 30 天）
  /// 
  /// 返回: 登录响应，包含 token 和用户信息
  Future<Result<DlerCloudLoginData>> login({
    required String email,
    required String passwd,
    int? tokenExpire,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/login',
        data: {
          'email': email,
          'passwd': passwd,
          if (tokenExpire != null) 'token_expire': tokenExpire,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != HttpStatus.ok || response.data == null) {
        return Result.error('请求失败: ${response.statusCode}');
      }

      final json = response.data!;
      final ret = json['ret'] as int?;

      if (ret != 200) {
        final msg = json['msg'] as String? ?? '未知错误';
        return Result.error(msg);
      }

      final dataJson = json['data'] as Map<String, dynamic>?;
      if (dataJson == null) {
        return Result.error('响应数据为空');
      }

      final data = DlerCloudLoginData.fromJson(dataJson);
      return Result.success(data);
    } on DioException catch (e) {
      return Result.error('网络错误: ${e.message}');
    } catch (e) {
      return Result.error('登录失败: $e');
    }
  }

  /// 注销 (删除 Token)
  /// 
  /// [accessToken] 访问令牌
  /// 
  /// 返回: 是否成功
  Future<Result<bool>> logout({
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/logout',
        data: {
          'access_token': accessToken,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != HttpStatus.ok || response.data == null) {
        return Result.error('请求失败: ${response.statusCode}');
      }

      final json = response.data!;
      final ret = json['ret'] as int?;

      if (ret != 200) {
        final msg = json['msg'] as String? ?? '未知错误';
        return Result.error(msg);
      }

      return Result.success(true);
    } on DioException catch (e) {
      return Result.error('网络错误: ${e.message}');
    } catch (e) {
      return Result.error('注销失败: $e');
    }
  }

  /// 获取用户信息
  /// 
  /// [accessToken] 访问令牌
  /// 
  /// 返回: 用户信息
  Future<Result<DlerCloudUserInfo>> getUserInfo({
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/information',
        data: {
          'access_token': accessToken,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != HttpStatus.ok || response.data == null) {
        return Result.error('请求失败: ${response.statusCode}');
      }

      final json = response.data!;
      final ret = json['ret'] as int?;

      if (ret != 200) {
        final msg = json['msg'] as String? ?? '未知错误';
        return Result.error(msg);
      }

      final dataJson = json['data'] as Map<String, dynamic>?;
      if (dataJson == null) {
        return Result.error('响应数据为空');
      }

      final data = DlerCloudUserInfo.fromJson(dataJson);
      return Result.success(data);
    } on DioException catch (e) {
      return Result.error('网络错误: ${e.message}');
    } catch (e) {
      return Result.error('获取用户信息失败: $e');
    }
  }

  /// 获取订阅地址
  /// 
  /// API 文档: https://docs.dler.io/black-hole/api/v1/managed
  /// 
  /// [accessToken] 访问令牌
  /// 
  /// 返回: 订阅地址信息
  Future<Result<DlerCloudManagedData>> getManaged({
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/managed/clash',
        data: {
          'access_token': accessToken,
        },
        options: Options(
          responseType: ResponseType.json,
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != HttpStatus.ok || response.data == null) {
        return Result.error('请求失败: ${response.statusCode}');
      }

      final json = response.data!;
      final ret = json['ret'] as int?;

      if (ret != 200) {
        final msg = json['msg'] as String? ?? '未知错误';
        return Result.error(msg);
      }

      // 注意：根据 API 文档，响应直接包含 name, smart, ss 等字段，不在 data 中
      final data = DlerCloudManagedData.fromJson(json);
      return Result.success(data);
    } on DioException catch (e) {
      return Result.error('网络错误: ${e.message}');
    } catch (e) {
      return Result.error('获取订阅地址失败: $e');
    }
  }
}

/// 全局 Dler Cloud API 实例
final dlerCloudApi = DlerCloudApi();

