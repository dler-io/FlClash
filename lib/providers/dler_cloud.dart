import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/dler_cloud.g.dart';

const String _dlerCloudTokenKey = 'dler_cloud_token';
const String _dlerCloudUserInfoKey = 'dler_cloud_user_info';
const String _dlerCloudManagedKey = 'dler_cloud_managed';

/// Dler Cloud 账户状态
class DlerCloudAccountState {
  final String? token;
  final DlerCloudUserInfo? userInfo;
  final DlerCloudManagedData? managedData;
  final bool isLoading;
  final DateTime? lastRefreshTime;

  const DlerCloudAccountState({
    this.token,
    this.userInfo,
    this.managedData,
    this.isLoading = false,
    this.lastRefreshTime,
  });

  DlerCloudAccountState copyWith({
    String? token,
    DlerCloudUserInfo? userInfo,
    DlerCloudManagedData? managedData,
    bool? isLoading,
    DateTime? lastRefreshTime,
  }) {
    return DlerCloudAccountState(
      token: token ?? this.token,
      userInfo: userInfo ?? this.userInfo,
      managedData: managedData ?? this.managedData,
      isLoading: isLoading ?? this.isLoading,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }
}

/// Dler Cloud 账户 Provider
@riverpod
class DlerCloudAccount extends _$DlerCloudAccount {
  @override
  Future<DlerCloudAccountState> build() async {
    return await _loadState();
  }

  Future<DlerCloudAccountState> _loadState() async {
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      final token = prefs?.getString(_dlerCloudTokenKey);
      final userInfoJson = prefs?.getString(_dlerCloudUserInfoKey);
      final managedJson = prefs?.getString(_dlerCloudManagedKey);
      
      DlerCloudUserInfo? userInfo;
      if (userInfoJson != null) {
        final json = jsonDecode(userInfoJson) as Map<String, dynamic>;
        userInfo = DlerCloudUserInfo.fromJson(json);
      }

      DlerCloudManagedData? managedData;
      if (managedJson != null) {
        final json = jsonDecode(managedJson) as Map<String, dynamic>;
        managedData = DlerCloudManagedData.fromJson(json);
      }

      return DlerCloudAccountState(
        token: token,
        userInfo: userInfo,
        managedData: managedData,
      );
    } catch (e) {
      return const DlerCloudAccountState();
    }
  }

  Future<void> _saveState(
    String? token,
    DlerCloudUserInfo? userInfo,
    DlerCloudManagedData? managedData,
  ) async {
    try {
      final prefs = await preferences.sharedPreferencesCompleter.future;
      if (token != null) {
        await prefs?.setString(_dlerCloudTokenKey, token);
      } else {
        await prefs?.remove(_dlerCloudTokenKey);
      }
      
      if (userInfo != null) {
        await prefs?.setString(_dlerCloudUserInfoKey, jsonEncode(userInfo.toJson()));
      } else {
        await prefs?.remove(_dlerCloudUserInfoKey);
      }

      if (managedData != null) {
        await prefs?.setString(_dlerCloudManagedKey, jsonEncode(managedData.toJson()));
      } else {
        await prefs?.remove(_dlerCloudManagedKey);
      }
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 登录
  Future<Result<DlerCloudLoginData>> login({
    required String email,
    required String passwd,
    int? tokenExpire,
  }) async {
    state = AsyncValue.data(
      (await _loadState()).copyWith(isLoading: true),
    );

    try {
      final result = await dlerCloudApi.login(
        email: email,
        passwd: passwd,
        tokenExpire: tokenExpire,
      );

      if (result.type == ResultType.success && result.data != null) {
        final loginData = result.data!;
        final userInfo = DlerCloudUserInfo(
          plan: loginData.plan,
          planTime: loginData.planTime,
          money: loginData.money,
          affMoney: loginData.affMoney,
          todayUsed: loginData.todayUsed,
          used: loginData.used,
          unused: loginData.unused,
          traffic: loginData.traffic,
          integral: loginData.integral,
        );

        // 登录成功后自动获取订阅地址
        DlerCloudManagedData? managedData;
        final managedResult = await dlerCloudApi.getManaged(
          accessToken: loginData.token,
        );
        if (managedResult.type == ResultType.success && managedResult.data != null) {
          managedData = managedResult.data!;
          
          // 自动导入 Smart 订阅
          try {
            await globalState.appController.addProfileFormURL(managedData.smart);
          } catch (e) {
            // 忽略导入错误，不影响登录流程
          }
        }

        await _saveState(loginData.token, userInfo, managedData);
        state = AsyncValue.data(
          DlerCloudAccountState(
            token: loginData.token,
            userInfo: userInfo,
            managedData: managedData,
            isLoading: false,
            lastRefreshTime: DateTime.now(),
          ),
        );
      } else {
        state = AsyncValue.data(
          (await _loadState()).copyWith(isLoading: false),
        );
      }

      return result;
    } catch (e) {
      state = AsyncValue.data(
        (await _loadState()).copyWith(isLoading: false),
      );
      return Result.error('登录失败: $e');
    }
  }

  /// 使用 Access Token 登录
  Future<Result<DlerCloudLoginData>> loginWithToken({
    required String token,
  }) async {
    state = AsyncValue.data(
      (await _loadState()).copyWith(isLoading: true),
    );

    try {
      // 使用 token 获取用户信息
      final userInfoResult = await dlerCloudApi.getUserInfo(
        accessToken: token,
      );

      if (userInfoResult.type != ResultType.success || userInfoResult.data == null) {
        state = AsyncValue.data(
          (await _loadState()).copyWith(isLoading: false),
        );
        return Result.error(userInfoResult.message);
      }

      final userInfo = userInfoResult.data!;

      // 获取订阅地址
      DlerCloudManagedData? managedData;
      final managedResult = await dlerCloudApi.getManaged(
        accessToken: token,
      );
      if (managedResult.type == ResultType.success && managedResult.data != null) {
        managedData = managedResult.data!;

        // 自动导入 Smart 订阅
        try {
          await globalState.appController.addProfileFormURL(managedData.smart);
        } catch (e) {
          // 忽略导入错误，不影响登录流程
        }
      }

      // 保存状态
      await _saveState(token, userInfo, managedData);
      state = AsyncValue.data(
        DlerCloudAccountState(
          token: token,
          userInfo: userInfo,
          managedData: managedData,
          isLoading: false,
          lastRefreshTime: DateTime.now(),
        ),
      );

      // 返回一个 DlerCloudLoginData 格式的数据
      // 注意：由于使用 token 登录，某些字段可能不可用，使用默认值
      final loginData = DlerCloudLoginData(
        token: token,
        tokenExpire: '',
        plan: userInfo.plan,
        planTime: userInfo.planTime,
        money: userInfo.money,
        affMoney: userInfo.affMoney,
        todayUsed: userInfo.todayUsed,
        used: userInfo.used,
        unused: userInfo.unused,
        traffic: userInfo.traffic,
        integral: userInfo.integral,
      );

      return Result.success(loginData);
    } catch (e) {
      state = AsyncValue.data(
        (await _loadState()).copyWith(isLoading: false),
      );
      return Result.error('登录失败: $e');
    }
  }

  /// 注销
  Future<Result<bool>> logout() async {
    final currentState = await _loadState();
    final token = currentState.token;

    if (token == null) {
      return Result.error('未登录');
    }

    state = AsyncValue.data(
      currentState.copyWith(isLoading: true),
    );

    try {
      final result = await dlerCloudApi.logout(accessToken: token);

      if (result.type == ResultType.success) {
        await _saveState(null, null, null);
        state = const AsyncValue.data(
          DlerCloudAccountState(isLoading: false),
        );
      } else {
        state = AsyncValue.data(
          currentState.copyWith(isLoading: false),
        );
      }

      return result;
    } catch (e) {
      state = AsyncValue.data(
        currentState.copyWith(isLoading: false),
      );
      return Result.error('注销失败: $e');
    }
  }

  /// 刷新用户信息
  Future<Result<DlerCloudUserInfo>> refreshUserInfo() async {
    final currentState = await _loadState();
    final token = currentState.token;

    if (token == null) {
      return Result.error('未登录');
    }

    state = AsyncValue.data(
      currentState.copyWith(isLoading: true),
    );

    try {
      final result = await dlerCloudApi.getUserInfo(accessToken: token);

      if (result.type == ResultType.success && result.data != null) {
        final userInfo = result.data!;
        await _saveState(token, userInfo, currentState.managedData);
        state = AsyncValue.data(
          DlerCloudAccountState(
            token: token,
            userInfo: userInfo,
            managedData: currentState.managedData,
            isLoading: false,
            lastRefreshTime: DateTime.now(),
          ),
        );
      } else {
        state = AsyncValue.data(
          currentState.copyWith(isLoading: false),
        );
      }

      return result;
    } catch (e) {
      state = AsyncValue.data(
        currentState.copyWith(isLoading: false),
      );
      return Result.error('获取用户信息失败: $e');
    }
  }

  /// 获取订阅地址
  Future<Result<DlerCloudManagedData>> getManaged() async {
    final currentState = await _loadState();
    final token = currentState.token;

    if (token == null) {
      return Result.error('未登录');
    }

    state = AsyncValue.data(
      currentState.copyWith(isLoading: true),
    );

    try {
      final result = await dlerCloudApi.getManaged(accessToken: token);

      if (result.type == ResultType.success && result.data != null) {
        final managedData = result.data!;
        await _saveState(token, currentState.userInfo, managedData);
        state = AsyncValue.data(
          DlerCloudAccountState(
            token: token,
            userInfo: currentState.userInfo,
            managedData: managedData,
            isLoading: false,
          ),
        );
      } else {
        state = AsyncValue.data(
          currentState.copyWith(isLoading: false),
        );
      }

      return result;
    } catch (e) {
      state = AsyncValue.data(
        currentState.copyWith(isLoading: false),
      );
      return Result.error('获取订阅地址失败: $e');
    }
  }
}

