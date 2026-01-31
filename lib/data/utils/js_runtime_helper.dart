import 'package:flutter_js/flutter_js.dart';

// 🔧 需要显式导入 fetch 扩展（flutter_js.dart 未导出此扩展）
// ignore: implementation_imports
import 'package:flutter_js/extensions/fetch.dart';

/// 创建统一的 JS 运行时
///
/// iOS/Android 统一使用 QuickJsRuntime2，
/// 避免 iOS 上 JavaScriptCore 对 LX Music 脚本的兼容性问题。
JavascriptRuntime createUnifiedJsRuntime() {
  JavascriptRuntime runtime = QuickJsRuntime2();
  runtime.enableFetch();
  runtime.enableHandlePromises();
  return runtime;
}
