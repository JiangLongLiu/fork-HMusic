# YouTube代理API集成说明

## 概述

本文档说明了如何将 `api.dlsrv.online` YouTube代理API集成到小爱音乐客户端中作为新的音源选项。

## API 分析

### 接口信息
- **URL**: `https://api.dlsrv.online/api/search`
- **方法**: POST
- **Content-Type**: application/json
- **请求格式**: `{"query": "搜索词"}`

### 响应格式
```json
{
  "data": [
    {
      "title": "周杰倫 Jay Chou【花海 Floral Sea】-Official Music Video",
      "videoId": "q1ww6bDjfiI",
      "url": "https://www.youtube.com/watch?v=q1ww6bDjfiI",
      "thumbnail": "https://i.ytimg.com/vi/q1ww6bDjfiI/hqdefault.jpg",
      "views": "14.0M",
      "duration": "4:24"
    }
  ]
}
```

### 特点
- ✅ 简单的JSON API，易于集成
- ✅ 返回丰富的视频信息（标题、时长、缩略图、播放量）
- ⚠️ **需要翻墙**才能正常使用
- ⚠️ 返回的是YouTube视频链接，需要进一步处理才能播放音频

## 集成架构

### 1. 服务层 (`YouTubeProxyService`)
位置: `lib/data/services/youtube_proxy_service.dart`

主要功能：
- **搜索音乐**: `searchMusic(query, maxResults)`
- **获取播放链接**: `getMusicUrl(videoId, quality)` *(目前返回YouTube原链接)*
- **测试连接**: `testConnection()`
- **标题解析**: 自动从视频标题中提取艺术家和歌曲名

### 2. 数据模型扩展
位置: `lib/data/models/online_music_result.dart`

新增：
- `OnlineMusicResult.fromYouTubeProxy()` 工厂方法
- 标题清理和艺术家提取的静态方法
- 时长解析功能

### 3. 状态管理集成
位置: `lib/presentation/providers/`

- **`source_settings_provider.dart`**: 添加 `useYouTubeProxy` 设置选项
- **`music_search_provider.dart`**: 集成YouTube代理搜索逻辑

### 4. 用户界面
位置: `lib/presentation/pages/settings/source_settings_page.dart`

新增功能：
- YouTube代理选项的单选按钮
- 网络要求提示界面
- 连接测试功能

## 使用流程

### 1. 用户设置
1. 进入"设置" → "音源设置"
2. 选择"YouTube 代理搜索"
3. 系统显示翻墙要求提示
4. 点击"测试网络连接"验证环境
5. 保存设置

### 2. 搜索流程
```
用户输入搜索词
    ↓
检查设置（useYouTubeProxy = true）
    ↓
调用 YouTubeProxyService.searchMusic()
    ↓
发送POST请求到 api.dlsrv.online
    ↓
解析响应，提取视频信息
    ↓
标题清理和艺术家提取
    ↓
返回 OnlineMusicResult 列表
    ↓
显示搜索结果
```

### 3. 播放流程
✅ **已实现**: 多源音频下载功能

**播放流程**:
```
用户点击播放
    ↓
检查音源类型 (sourceApi == 'youtube_proxy')
    ↓
调用 YouTubeProxyService.getMusicUrl()
    ↓
根据用户设置选择下载源
    ↓
尝试多个下载源 (OceanSaver, YTMP3, Y2mate)
    ↓
获取实际音频播放链接
    ↓
播放音频
```

**支持的下载源**:
1. **OceanSaver** - 快速稳定，支持多种格式
2. **YTMP3** - 高音质MP3下载  
3. **Y2mate** - 多格式支持，音质可选

**音质智能降级机制**:
- 优先尝试用户选择的音质（如256k）
- 失败时尝试更高音质（320k）作为升级备选
- 再失败则按质量递减尝试（192k → 128k → 64k）
- 确保用户总能获得最佳可用音质

## 网络要求

### 必要条件
- ✅ 可访问 `api.dlsrv.online`
- ✅ 可访问 `i.ytimg.com` (缩略图)
- ✅ VPN或代理服务器

### 推荐配置
- 稳定的国际网络连接
- 低延迟的代理服务器
- 支持HTTPS的代理

## 错误处理

### 网络错误
- **连接超时**: 提示检查代理状态
- **403/429错误**: 建议更换代理或稍后重试
- **其他网络错误**: 显示具体错误信息

### 数据处理错误
- **解析失败**: 静默处理，返回默认值
- **标题提取失败**: 使用原始标题
- **时长解析失败**: 返回0

## 配置选项

### SourceSettings 新增字段
```dart
final bool useYouTubeProxy; // 是否使用YouTube代理搜索
final String youTubeDownloadSource; // YouTube下载源选择
final String youTubeAudioQuality; // YouTube音频质量选择
```

### SharedPreferences 存储
- `source_use_youtube_proxy`: `bool` - 是否启用YouTube代理 (默认: `false`)
- `source_youtube_download_source`: `String` - 下载源选择 (默认: `'oceansaver'`)
- `source_youtube_audio_quality`: `String` - 音频质量选择 (默认: `'320k'`)

## 测试建议

### 功能测试
1. **基础连接测试**: 使用设置页面的"测试网络连接"
2. **搜索测试**: 搜索常见歌曲如"花海"、"夜曲"等
3. **播放测试**: 测试不同下载源的音频获取功能
4. **下载源切换**: 验证不同下载源之间的切换和降级
5. **音频质量测试**: 测试不同音质选择(64k/128k/192k/256k/320k)
6. **质量降级测试**: 验证高质量请求失败时的降级机制
   - 选择320k测试是否能获得最高可用音质
   - 选择192k测试降级顺序: 192k → 256k → 320k → 128k → 64k
   - 模拟特定音质不可用的情况
7. **智能降级日志**: 验证控制台日志正确显示降级过程
8. **边界测试**: 测试特殊字符、空搜索词等

### 网络环境测试
1. **有代理环境**: 验证正常搜索功能
2. **无代理环境**: 验证错误提示和降级处理
3. **网络不稳定**: 验证超时处理

### 用户体验测试
1. **设置切换**: 验证各种音源选项之间的切换
2. **提示信息**: 验证警告和提示的显示
3. **错误反馈**: 验证各种错误情况下的用户反馈

## 未来改进方向

### 已完成功能
- [x] 多源音频直链获取功能
- [x] 智能标题解析和艺术家提取
- [x] 完整的错误处理和降级机制
- [x] 用户友好的下载源选择界面
- [x] 多音质选择 (64k, 128k, 192k, 256k, 320k)
- [x] 美观的音质卡片选择器界面
- [x] **音质智能降级机制** - 自动选择最佳可用音质
- [x] **用户反馈系统** - 实时提示使用的音质和状态

### 短期改进
- [ ] 优化下载源的成功率和速度
- [ ] 实现下载源性能监控和自动优选
- [ ] 添加FLAC无损音质支持
- [ ] 返回实际使用的音质信息给UI显示

### 长期规划
- [ ] 支持自定义代理设置
- [ ] 集成更多YouTube音频提取服务
- [ ] 支持YouTube播放列表批量处理
- [ ] 添加音频缓存机制

## 安全注意事项

### 用户隐私
- 搜索词会发送到第三方API
- 建议在隐私政策中说明

### 网络安全
- 使用HTTPS确保传输安全
- 验证API响应的合法性
- 防止恶意代理攻击

### 合规性
- 遵守YouTube服务条款
- 注意版权相关法律法规
- 建议用户自行承担使用责任

---

*最后更新: 2024年12月*
