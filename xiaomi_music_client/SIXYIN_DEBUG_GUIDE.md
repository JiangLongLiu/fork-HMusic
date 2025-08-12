# 六音JS音源调试指南

## 问题分析

通过代码分析，发现六音JS音源无法加载的可能原因：

### 1. 错误被静默处理
原代码中使用了 `catch (_)` 来捕获所有异常，但没有输出错误信息，导致无法定位具体问题。

### 2. JS执行环境问题
- **flutter_js**: 可能存在JS引擎兼容性问题
- **WebView**: 可能存在跨域或安全策略限制

### 3. 脚本依赖问题
六音JS脚本可能依赖某些浏览器特有的API或环境。

## 已实施的修复

### 1. 增加详细日志 ✅
为 `LocalJsSourceService` 和 `WebViewJsSourceService` 添加了详细的调试日志：
- 脚本加载过程
- JS执行状态
- 错误信息输出
- 搜索执行结果

### 2. 创建测试工具 ✅
创建了 `test_sixyin_js.dart` 用于独立测试JS音源功能。

## 调试步骤

### 1. 查看日志输出
运行应用并尝试使用音源搜索，查看控制台输出：
```
🔧 [LocalJsSource] 开始加载JS音源
🔧 [LocalJsSource] 启用状态: true
🔧 [LocalJsSource] 脚本URL: xxx
🌐 [LocalJsSource] 正在请求: xxx
📥 [LocalJsSource] 脚本下载成功，长度: xxx 字符
🔄 [LocalJsSource] 开始执行JS脚本...
```

### 2. 运行独立测试
在应用中添加测试页面调用 `SixyinJsTest.testJsExecution()`。

### 3. 检查网络连接
确认设备能正常访问：
- https://cdn.jsdelivr.net/gh/pdone/lx-music-source/sixyin/latest.js
- 其他备用镜像地址

## 可能的解决方案

### 方案1: 修复JS执行环境
如果是flutter_js兼容性问题，可以：
1. 更新flutter_js版本
2. 使用WebView方式代替
3. 预处理JS脚本，移除不兼容的代码

### 方案2: 简化JS脚本
1. 分析六音JS脚本的核心功能
2. 重写为更简单的、兼容性更好的版本
3. 直接调用音源API而非执行复杂JS

### 方案3: 网络代理
如果是网络连接问题：
1. 使用国内镜像
2. 添加代理支持
3. 本地缓存脚本文件

## 下一步调试

### 方法1: 查看搜索日志
1. 重新运行应用
2. 尝试搜索任意歌曲
3. 查看控制台输出，现在会显示详细过程：
   ```
   🔧 [MusicSearch] 音源设置 - 启用: true, URL: xxx
   🌐 [MusicSearch] 尝试WebView音源...
   🌐 [MusicSearch] WebView服务状态: 可用/null
   🔧 [MusicSearch] 尝试LocalJS音源...
   🔧 [MusicSearch] LocalJS服务状态: 可用/null
   ✅ [MusicSearch] JS音源搜索成功，找到 X 个结果
   或
   ❌ [MusicSearch] JS音源都失败了，回退到腾讯QQ音乐
   ```

### 方法2: 使用专用调试工具
1. 在应用的任意页面添加调试按钮：
   ```dart
   import '../debug_sixyin.dart';
   
   // 在页面中添加按钮
   SixyinDebugButton(),
   
   // 或直接调用
   debugSixyinSource(ref);
   ```
2. 点击按钮查看详细的音源状态报告

### 方法3: 检查音源设置
1. 进入应用设置 → 音源设置（JS）
2. 确认"启用自定义音源脚本"已开启
3. 确认脚本URL不为空（默认应该是jsDelivr地址）
4. 保存设置

## 快速测试命令

```bash
# 测试网络连接
curl -I "https://cdn.jsdelivr.net/gh/pdone/lx-music-source/sixyin/latest.js"

# 在浏览器中测试JS脚本
# 打开浏览器控制台，粘贴脚本内容并执行
```
