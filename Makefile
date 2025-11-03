android_app:
	dart ./setup.dart android --env stable
	@echo "✓ Android APK built in dist/ directory"

# Android 构建 - 生成 APK 并复制到 Downloads
android_downloads:
	@echo "🧹 清理旧的 APK 文件..."
	@rm -f /Users/lhie1/Downloads/"Dler Cloud (FlClash)"*.apk 2>/dev/null || true
	@rm -f dist/"Dler Cloud (FlClash)"*.apk 2>/dev/null || true
	dart ./setup.dart android --env stable
	@echo "📦 复制 APK 文件到 Downloads..."
	@mkdir -p /Users/lhie1/Downloads
	@if [ -d "dist" ]; then \
		cp -v dist/*.apk /Users/lhie1/Downloads/ 2>/dev/null || echo "未找到 APK 文件"; \
		echo "✓ Android APK files copied to /Users/lhie1/Downloads"; \
	else \
		echo "⚠️  dist 目录不存在，构建可能失败"; \
	fi
macos_downloads:
	@echo "🏗️  构建 macOS Universal Binary 版本（包含 arm64 和 x86_64）..."
	@flutter build macos --release --dart-define=APP_ENV=stable
	@echo "📦 创建 DMG 文件..."
	@rm -rf /Users/lhie1/Downloads/FlClash.app
	@rm -f /Users/lhie1/Downloads/FlClash.dmg
	@rm -f "/Users/lhie1/Downloads/FlClash (Dler Cloud).dmg"
	@rm -f "/Users/lhie1/Downloads/Dler Cloud (FlClash)"*.dmg 2>/dev/null || true
	@mkdir -p /tmp/FlClash_dmg
	@cp -R build/macos/Build/Products/Release/FlClash.app /tmp/FlClash_dmg/
	@ln -s /Applications /tmp/FlClash_dmg/Applications
	@hdiutil create -volname "FlClash (Dler Cloud)" -srcfolder /tmp/FlClash_dmg -ov -format UDZO "/Users/lhie1/Downloads/FlClash (Dler Cloud).dmg"
	@rm -rf /tmp/FlClash_dmg
	@echo "✓ 已创建 Universal Binary DMG: /Users/lhie1/Downloads/FlClash (Dler Cloud).dmg"