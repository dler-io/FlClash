import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/dler_cloud.dart';
import 'package:fl_clash/providers/dler_cloud.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dler_cloud_login_dialog.dart';
import 'dler_cloud_user_info.dart';

class DlerCloudView extends ConsumerWidget {
  const DlerCloudView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(dlerCloudAccountProvider);

    return accountState.when(
      data: (state) {
        if (state.token == null) {
          return _buildNotLoggedInView(context, ref);
        }
        return _buildLoggedInView(context, ref, state);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('错误: $error'),
      ),
    );
  }

  Widget _buildNotLoggedInView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Dler Cloud',
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可查看账户信息和流量使用情况',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const DlerCloudLoginDialog(),
              );
            },
            icon: const Icon(Icons.login),
            label: const Text('登录'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedInView(
    BuildContext context,
    WidgetRef ref,
    DlerCloudAccountState state,
  ) {
    final accountNotifier = ref.read(dlerCloudAccountProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return CommonScaffold(
      title: l10n.dlerCloud,
      actions: _buildAppBarActions(context, ref, state, accountNotifier),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息卡片
            if (state.userInfo != null)
              DlerCloudUserInfoWidget(userInfo: state.userInfo!),
            
            const SizedBox(height: 16),
            
            // 订阅地址卡片
            if (state.managedData != null)
              _buildManagedCard(context, ref, state.managedData!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    DlerCloudAccountState state,
    DlerCloudAccount accountNotifier,
  ) {
    return [
      IconButton(
        icon: state.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        onPressed: state.isLoading
            ? null
            : () async {
                final result = await accountNotifier.refreshUserInfo();
                if (context.mounted) {
                  if (result.type == ResultType.success) {
                    context.showNotifier('刷新成功');
                  } else {
                    context.showNotifier('刷新失败: ${result.message}');
                  }
                }
              },
        tooltip: '刷新信息',
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: state.isLoading
            ? null
            : () async {
                final confirm = await globalState.showMessage(
                  title: '确认注销',
                  message: const TextSpan(
                    text: '确定要注销当前账户吗？',
                  ),
                );
                if (confirm == true && context.mounted) {
                  final result = await accountNotifier.logout();
                  if (context.mounted) {
                    if (result.type == ResultType.success) {
                      context.showNotifier('注销成功');
                    } else {
                      context.showNotifier('注销失败: ${result.message}');
                    }
                  }
                }
              },
        tooltip: '注销',
      ),
    ];
  }

  Widget _buildManagedCard(
    BuildContext context,
    WidgetRef ref,
    DlerCloudManagedData managedData,
  ) {
    final accountNotifier = ref.read(dlerCloudAccountProvider.notifier);
    final accountState = ref.watch(dlerCloudAccountProvider);

    return CommonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.subscriptions,
                  size: 24,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '订阅地址',
                    style: context.textTheme.titleMedium,
                  ),
                ),
                accountState.when(
                  data: (state) => _buildRefreshManagedButton(
                    context,
                    accountNotifier,
                    isLoading: state.isLoading,
                  ),
                  loading: () => const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, stackTrace) => _buildRefreshManagedButton(
                    context,
                    accountNotifier,
                    isLoading: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSubscriptionItem(
              context,
              'Smart (荐)',
              managedData.smart,
              Icons.auto_awesome,
            ),
            const SizedBox(height: 12),
            _buildSubscriptionItem(
              context,
              'SS2022',
              managedData.ss2022!,
              Icons.security,
            ),
            const SizedBox(height: 12),
            _buildSubscriptionItem(
              context,
              'VMess',
              managedData.vmess,
              Icons.vpn_key,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshManagedButton(
    BuildContext context,
    DlerCloudAccount accountNotifier, {
    required bool isLoading,
  }) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: isLoading
          ? null
          : () async {
              final result = await accountNotifier.getManaged();
              if (context.mounted) {
                if (result.type == ResultType.success) {
                  context.showNotifier('刷新成功');
                } else {
                  context.showNotifier('刷新失败: ${result.message}');
                }
              }
            },
      tooltip: '刷新订阅地址',
    );
  }

  Widget _buildSubscriptionItem(
    BuildContext context,
    String label,
    String url,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: context.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                url,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.copy),
          iconSize: 20,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              context.showNotifier('已复制到剪贴板');
            }
          },
          tooltip: '复制',
        ),
        IconButton(
          icon: const Icon(Icons.swap_horiz),
          iconSize: 20,
          onPressed: () {
            globalState.appController.addProfileFormURL(url);
            if (context.mounted) {
              context.showNotifier('正在切换订阅...');
            }
          },
          tooltip: '切换',
        ),
      ],
    );
  }
}

