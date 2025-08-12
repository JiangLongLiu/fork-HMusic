import 'dart:async';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../presentation/providers/source_settings_provider.dart';

class WebViewJsSourceService {
  final WebViewController controller;
  final Completer<void> _ready = Completer<void>();
  bool _inited = false;
  bool _hasValidAdapter = false;
  List<String> _lastFoundFunctions = <String>[];
  Completer<List<String>>? _pendingProbe;
  Completer<List<Map<String, dynamic>>>? _pendingSearchCompleter;
  Completer<String>? _pendingUrlCompleter;

  WebViewJsSourceService(this.controller);

  void _completeSearchResult(List<Map<String, dynamic>> results) {
    if (_pendingSearchCompleter != null &&
        !_pendingSearchCompleter!.isCompleted) {
      _pendingSearchCompleter!.complete(results);
      _pendingSearchCompleter = null;
    }
  }

  void _completeUrlResult(String url) {
    if (_pendingUrlCompleter != null && !_pendingUrlCompleter!.isCompleted) {
      print('🔗 [WebViewJsSource] 完成URL解析: $url');
      _pendingUrlCompleter!.complete(url);
    }
  }

  Future<String?> _downloadScriptWithFallback(List<String> urls) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 6),
        responseType: ResponseType.plain,
        validateStatus: (code) => code != null && code >= 200 && code < 400,
        headers: {
          'Accept': 'text/javascript,application/javascript;q=0.9,*/*;q=0.1',
          'User-Agent': 'xiaoaitongxue-webview-loader',
        },
      ),
    );
    for (final u in urls) {
      try {
        final res = await dio.get<String>(u);
        final text = res.data ?? '';
        if (text.isNotEmpty) return text;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> init(SourceSettings settings) async {
    print('🔧 [WebViewJsSource] 开始初始化WebView音源');
    print('🔧 [WebViewJsSource] 启用状态: ${settings.enabled}');
    print('🔧 [WebViewJsSource] 脚本URL长度: ${settings.scriptUrl.length}');
    print('🔧 [WebViewJsSource] 脚本URL: ${settings.scriptUrl}');
    // 分段打印长URL，避免截断
    if (settings.scriptUrl.length > 100) {
      print(
        '🔧 [WebViewJsSource] URL前半部分: ${settings.scriptUrl.substring(0, settings.scriptUrl.length ~/ 2)}',
      );
      print(
        '🔧 [WebViewJsSource] URL后半部分: ${settings.scriptUrl.substring(settings.scriptUrl.length ~/ 2)}',
      );
    }

    if (_inited) {
      print('ℹ️ [WebViewJsSource] 已经初始化过了');
      return;
    }

    print('⚙️ [WebViewJsSource] 配置WebView...');
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0x00000000));

    // 配置导航代理，允许所有请求
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          return NavigationDecision.navigate;
        },
      ),
    );

    // 设置用户代理，模拟真实浏览器
    await controller.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    // 先注册 JS Channel，再加载页面，保证页面侧可见
    print('📡 [WebViewJsSource] 注册JS桥接器...');

    // 注册适配器状态桥接器
    await controller.addJavaScriptChannel(
      'SixyinBridge',
      onMessageReceived: (msg) {
        print('📨 [SixyinBridge] 收到消息: ${msg.message}');
        // 检查适配器状态
        if (msg.message.startsWith('adapter_found:')) {
          final adapter = msg.message.substring('adapter_found:'.length);
          _hasValidAdapter = adapter.isNotEmpty;
          _lastFoundFunctions =
              adapter
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
          print(
            '🔍 [WebViewJsSource] 适配器检测结果: ${_hasValidAdapter ? "有效" : "无效"}',
          );
          if (_pendingProbe != null && !(_pendingProbe!.isCompleted)) {
            _pendingProbe!.complete(_lastFoundFunctions);
          }
        }
        if (msg.message.startsWith('ready_state:')) {
          final state = msg.message.substring('ready_state:'.length);
          print('🧩 [WebViewJsSource] ReadyState: ' + state);
        }
        // 处理搜索结果事件
        if (msg.message.startsWith('search_result:')) {
          final resultJson = msg.message.substring('search_result:'.length);
          print('🔍 [SixyinBridge] 收到搜索结果: ${resultJson.length} 字符');
          try {
            final parsed = jsonDecode(resultJson);
            if (parsed is List) {
              final results =
                  parsed
                      .where((e) => e is Map)
                      .map((e) => (e as Map).cast<String, dynamic>())
                      .toList();
              print('✅ [SixyinBridge] 解析搜索结果: ${results.length} 项');
              // 如果有等待中的搜索，完成它
              _completeSearchResult(results);
            }
          } catch (e) {
            print('⚠️ [SixyinBridge] 解析搜索结果失败: $e');
            _completeSearchResult(<Map<String, dynamic>>[]);
          }
        }
        // 处理URL解析结果事件
        else if (msg.message.startsWith('url_result:')) {
          final url = msg.message.substring('url_result:'.length);

          // 检查版权问题
          if (url == 'COPYRIGHT_ERROR') {
            print('❌ [WebViewJsSource] 版权错误：该歌曲在当前音源没有播放权限');
            print('💡 [WebViewJsSource] 建议：尝试搜索其他版本或使用不同音源');
            _completeUrlResult(''); // 返回空结果
            return;
          }

          print('🔗 [SixyinBridge] 收到URL解析结果: $url');

          // 检查是否是回退的酷我音乐链接
          if (url.contains('kuwo.cn')) {
            print('⚠️ [WebViewJsSource] 注意：QQ音乐直链获取失败，使用酷我音乐作为备用播放源');
          }

          _completeUrlResult(url);
        }
      },
    );

    // 注册网络请求代理桥接器
    await controller.addJavaScriptChannel(
      'NetworkBridge',
      onMessageReceived: (msg) async {
        try {
          final data = jsonDecode(msg.message);
          final requestId = data['id'] as String;
          final url = data['url'] as String;
          final method = data['method'] as String? ?? 'GET';
          final headers = Map<String, String>.from(data['headers'] ?? {});
          final body = data['body'] as String?;

          print('🌐 [NetworkBridge] 代理请求: $method $url');

          // 添加常用请求头，绕过反爬虫
          headers.putIfAbsent(
            'User-Agent',
            () =>
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          );
          headers.putIfAbsent(
            'Accept',
            () => 'application/json, text/plain, */*',
          );
          headers.putIfAbsent(
            'Accept-Language',
            () => 'zh-CN,zh;q=0.9,en;q=0.8',
          );
          headers.putIfAbsent('Cache-Control', () => 'no-cache');
          headers.putIfAbsent('Pragma', () => 'no-cache');

          // 使用Dio执行请求
          final dio = Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 15),
              validateStatus: (status) => status != null && status < 500,
              followRedirects: true,
              maxRedirects: 3,
              // 禁用自动JSON解析，避免content-type问题
              contentType: 'application/json',
            ),
          );

          // 设置transformer为只处理plain text，不自动解析JSON
          dio.transformer = BackgroundTransformer();

          final response = await dio.request(
            url,
            options: Options(
              method: method,
              headers: headers,
              responseType: ResponseType.plain,
            ),
            data: body,
          );

          print('✅ [NetworkBridge] 请求成功: ${response.statusCode}');
          print(
            '📦 [NetworkBridge] 响应长度: ${response.data?.toString().length ?? 0}',
          );

          // 返回结果给JS
          final result = {
            'id': requestId,
            'success': true,
            'status': response.statusCode,
            'data': response.data,
            'headers': response.headers.map,
          };

          await controller.runJavaScript(
            'window.__networkCallback && window.__networkCallback(${jsonEncode(result)})',
          );
        } catch (e) {
          print('❌ [NetworkBridge] 请求失败: $e');
          // 返回错误给JS
          try {
            final data = jsonDecode(msg.message);
            final requestId = data['id'] as String;
            final result = {
              'id': requestId,
              'success': false,
              'error': e.toString(),
            };
            await controller.runJavaScript(
              'window.__networkCallback && window.__networkCallback(${jsonEncode(result)})',
            );
          } catch (_) {}
        }
      },
    );

    // 空白页作为容器
    print('📄 [WebViewJsSource] 加载HTML容器...');
    await controller.loadHtmlString(
      '<html><head><meta name="viewport" content="width=device-width, initial-scale=1"/></head><body></body></html>',
    );

    // 注入 Cookie 全局变量
    print('🍪 [WebViewJsSource] 注入Cookie变量...');
    final cookieInit =
        "var MUSIC_U='${settings.cookieNetease}'; var ts_last='${settings.cookieTencent}';";
    await controller.runJavaScript(cookieInit);

    // 拉取并注入脚本（带多镜像自动降级）
    if (settings.scriptUrl.isNotEmpty) {
      print('🌐 [WebViewJsSource] 开始加载JS脚本...');

      // 检查URL是否被截断，如果是xiaoqiu相关且不以.js结尾，尝试修复
      String finalUrl = settings.scriptUrl;
      if (finalUrl.contains('xiaoqiu') &&
          !finalUrl.endsWith('.js') &&
          !finalUrl.endsWith('/')) {
        if (finalUrl.endsWith('.j')) {
          finalUrl = finalUrl + 's';
          print('🔧 [WebViewJsSource] 检测到URL截断，自动修复: $finalUrl');
        }
      }

      final List<String> urls = <String>[finalUrl]; // 使用修复后的URL
      // 当为六音默认地址时，追加 jsDelivr 镜像
      // 添加多个可靠的镜像源，优先使用支持完整功能的脚本
      final fallbackUrls = [
        // xiaoqiu.js - 支持完整的搜索和URL解析功能
        'https://fastly.jsdelivr.net/gh/Huibq/keep-alive/Music_Free/xiaoqiu.js',
        'https://cdn.jsdelivr.net/gh/Huibq/keep-alive/Music_Free/xiaoqiu.js',
        'https://raw.githubusercontent.com/Huibq/keep-alive/main/Music_Free/xiaoqiu.js',
        // sixyin - 仅搜索功能，作为备用
        'https://cdn.jsdelivr.net/gh/pdone/lx-music-source/sixyin/latest.js',
        'https://fastly.jsdelivr.net/gh/pdone/lx-music-source/sixyin/latest.js',
        'https://gcore.jsdelivr.net/gh/pdone/lx-music-source/sixyin/latest.js',
        'https://testingcf.jsdelivr.net/gh/pdone/lx-music-source/sixyin/latest.js',
        // GitHub原始文件（备用）
        'https://raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js',
        // 自定义CDN（备用）
        'https://gitee.com/pdone/lx-music-source/raw/main/sixyin/latest.js',
      ];

      // 如果当前URL不在fallback列表中，则添加所有fallback
      if (!fallbackUrls.contains(finalUrl)) {
        urls.addAll(fallbackUrls);
      } else {
        // 如果当前URL在fallback中，将其他的也加上
        urls.addAll(fallbackUrls.where((u) => u != finalUrl));
      }
      // 优先由 Dart 侧下载脚本，避免 WebView 内的网络限制
      final scriptText = await _downloadScriptWithFallback(urls);
      if (scriptText != null && scriptText.isNotEmpty) {
        print('📥 [WebViewJsSource] 脚本已通过 Dart 下载，直接注入执行');
        const String lxShim = r'''(function(){
          try{
            var g = (typeof globalThis !== 'undefined') ? globalThis : (this||{});
            // 基础 polyfill
            if (typeof g.atob !== 'function') {
              g.atob = function(input){
                var chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
                input = String(input).replace(/=+$/, '');
                var str='';
                for (var bc=0, bs, buffer, idx=0; buffer = input.charAt(idx++); ~buffer && (bs = bc % 4 ? bs * 64 + buffer : buffer, bc++ % 4) ? str += String.fromCharCode(255 & (bs >> (-2 * bc & 6))) : 0) {
                  buffer = chars.indexOf(buffer);
                }
                return str;
              };
            }
            if (typeof g.btoa !== 'function') {
              g.btoa = function(input){
                var chars='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
                var str = String(input);
                var output='';
                for (var block, charCode, idx=0, map=chars; str.charAt(idx | 0) || (map='=', idx % 1); output += map.charAt(63 & block >> 8 - idx % 1 * 8)) {
                  charCode = str.charCodeAt(idx += 3/4);
                  if (charCode > 0xFF) throw new Error('btoa polyfill: invalid char');
                  block = block << 8 | charCode;
                }
                return output;
              };
            }
            if (typeof g.Buffer === 'undefined') {
              g.Buffer = {
                from: function(input, enc){
                  if (enc === 'base64') {
                    var bin = g.atob(input);
                    var len = bin.length;
                    var bytes = new Uint8Array(len);
                    for (var i=0;i<len;i++) bytes[i] = bin.charCodeAt(i) & 0xff;
                    return bytes;
                  }
                  if (typeof input === 'string') {
                    var utf8 = unescape(encodeURIComponent(input));
                    var arr = new Uint8Array(utf8.length);
                    for (var i=0;i<utf8.length;i++) arr[i] = utf8.charCodeAt(i);
                    return arr;
                  }
                  if (input && input.buffer) return new Uint8Array(input);
                  if (Array.isArray(input)) return new Uint8Array(input);
                  return new Uint8Array(0);
                }
              };
            }

            // LX 运行时最小模拟
            g.__lx_events = g.__lx_events || {};
            var evt = {
              SOURCE_LIST: 'SOURCE_LIST',
              SOURCE_SEARCH: 'SOURCE_SEARCH',
              SOURCE_SONG_URL: 'SOURCE_SONG_URL',
              SOURCE_LRC: 'SOURCE_LRC',
              SOURCE_ALBUM: 'SOURCE_ALBUM',
              SOURCE_ARTIST: 'SOURCE_ARTIST',
              REQUEST: 'REQUEST',
            };
            if(!g.lx){
              g.lx = {
                EVENT_NAMES: evt,
                APP_EVENT_NAMES: {},
                CURRENT_PLATFORM: 'desktop',
                APP_SETTING: {},
                version: '2.4.0',
                isDev: false,
                on: function(name, handler){ try{ g.__lx_events[name]=handler; }catch(_){} },
                off: function(name){ try{ delete g.__lx_events[name]; }catch(_){} },
                emit: function(name, payload){ try{ var h=g.__lx_events[name]; if (typeof h==='function') return h(payload); }catch(_){} },
                request: function(url, options){ return fetch(url, options||{}); },
                utils: {
                  buffer: {
                    from: function(input, enc){ return g.Buffer.from(input, enc); },
                    bufToString: function(buf, enc){
                      try{ if (buf && buf.buffer) { return new TextDecoder().decode(buf); } }catch(_){ }
                      return '';
                    },
                  },
                  crypto: {
                    md5: function(s){ return (s||'').length.toString(16); },
                  },
                },
                env: 'mobile',
                currentScriptInfo: { name: 'custom', description: 'custom', rawScript: '' },
              };
            }
          }catch(e){}
        })()''';
        await controller.runJavaScript(lxShim);

        // 注入网络代理，替换fetch函数
        const String networkProxy = r'''(function(){
          try{
            // 保存原始fetch
            const originalFetch = window.fetch;
            
            // 网络请求回调管理
            window.__networkCallbacks = {};
            window.__networkCallback = function(result) {
              const callback = window.__networkCallbacks[result.id];
              if (callback) {
                delete window.__networkCallbacks[result.id];
                if (result.success) {
                  callback.resolve(result);
                } else {
                  callback.reject(new Error(result.error || 'Network request failed'));
                }
              }
            };
            
            // 替换fetch函数
            window.fetch = function(url, options = {}) {
              return new Promise((resolve, reject) => {
                try {
                  const requestId = 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                  
                  // 构建请求数据
                  const requestData = {
                    id: requestId,
                    url: url,
                    method: options.method || 'GET',
                    headers: options.headers || {},
                    body: options.body || null
                  };
                  
                  console.log('[NetworkProxy] 代理fetch请求:', url);
                  console.log('[NetworkProxy] 请求数据:', requestData);
                  
                  // 添加超时处理
                  const timeoutId = setTimeout(() => {
                    console.warn('[NetworkProxy] 请求超时，ID:', requestId);
                    delete window.__networkCallbacks[requestId];
                    reject(new Error('Request timeout'));
                  }, 20000); // 20秒超时
                  
                  // 更新回调，添加超时清理
                  window.__networkCallbacks[requestId] = {
                    resolve: (result) => {
                      clearTimeout(timeoutId);
                      // 模拟Response对象
                      const response = {
                        ok: result.status >= 200 && result.status < 300,
                        status: result.status,
                        statusText: 'OK',
                        headers: new Map(Object.entries(result.headers || {})),
                        text: () => Promise.resolve(result.data),
                        json: () => {
                          try {
                            return Promise.resolve(JSON.parse(result.data));
                          } catch (e) {
                            console.warn('[NetworkProxy] JSON解析失败:', e);
                            return Promise.reject(new Error('Invalid JSON'));
                          }
                        },
                        blob: () => Promise.resolve(new Blob([result.data])),
                        arrayBuffer: () => Promise.resolve(new ArrayBuffer(0)),
                      };
                      console.log('[NetworkProxy] 请求成功，状态:', result.status);
                      resolve(response);
                    },
                    reject: (error) => {
                      clearTimeout(timeoutId);
                      console.error('[NetworkProxy] 请求失败:', error);
                      reject(error);
                    }
                  };
                  
                  // 发送到NetworkBridge
                  if (window.NetworkBridge && NetworkBridge.postMessage) {
                    NetworkBridge.postMessage(JSON.stringify(requestData));
                  } else {
                    // 回退到原始fetch
                    console.warn('[NetworkProxy] NetworkBridge不可用，回退到原始fetch');
                    clearTimeout(timeoutId);
                    delete window.__networkCallbacks[requestId];
                    originalFetch(url, options).then(resolve).catch(reject);
                  }
                  
                } catch (e) {
                  console.error('[NetworkProxy] fetch代理错误:', e);
                  reject(e);
                }
              });
            };
            
            console.log('[NetworkProxy] fetch函数已被代理');
            
          }catch(e){
            console.warn('NetworkProxy initialization error:', e);
          }
        })()''';
        await controller.runJavaScript(networkProxy);

        // 优先注入CommonJS环境，避免脚本中过早使用exports
        const String commonJsShim = r'''(function(){
          try{
            // 确保全局环境下就有这些变量
            if (typeof window !== 'undefined') {
              // 先定义exports和module，防止脚本立即使用
              if (typeof window.exports === 'undefined') {
                window.exports = {};
              }
              if (typeof window.module === 'undefined') {
                window.module = { exports: window.exports };
              }
            }
            if (typeof globalThis !== 'undefined') {
              if (typeof globalThis.exports === 'undefined') {
                globalThis.exports = globalThis.exports || {};
              }
              if (typeof globalThis.module === 'undefined') {
                globalThis.module = { exports: globalThis.exports };
              }
            }
            
            if (typeof require !== 'function'){
              var axios = function(opts){
                opts = opts || {};
                var method = (opts.method || 'GET').toUpperCase();
                var headers = opts.headers || {};
                var body = (opts.data!=null) ? (typeof opts.data==='string' ? opts.data : JSON.stringify(opts.data)) : undefined;
                return fetch(opts.url, { method: method, headers: headers, body: body, credentials: 'include' })
                  .then(function(r){ 
                    return r.text().then(function(t){ 
                      var d; 
                      try{ 
                        d = JSON.parse(t);
                      }catch(_){ 
                        d = t;
                      } 
                      return { data: d, status: r.status, statusText: r.statusText }; 
                    }); 
                  });
              };
              axios.get = function(url, opts){ opts=opts||{}; return axios({ url: url, method: 'GET', headers: (opts.headers||{}) }); };
              axios.post = function(url, data, opts){ opts=opts||{}; return axios({ url: url, method: 'POST', headers: (opts.headers||{}), data: data }); };
              axios.default = axios;
              
              var CryptoJs = { 
                enc: { 
                  Base64: { 
                    parse: function(s){ 
                      return { 
                        toString: function(){ 
                          try{ return atob(s);}catch(e){ return ''; } 
                        } 
                      }; 
                    } 
                  }, 
                  Utf8: {
                    parse: function(s){ return { toString: function(){ return s || ''; } }; }
                  }
                },
                AES: {
                  decrypt: function(){ return { toString: function(){ return ''; } }; }
                }
              };
              var he = { 
                decode: function(s){ 
                  try{ 
                    return s.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#39;/g,"'").replace(/&quot;/g,'"'); 
                  }catch(e){ 
                    return s; 
                  } 
                } 
              };
              
              function require(name){ 
                if(name==='axios') return axios; 
                if(name==='crypto-js') return CryptoJs; 
                if(name==='he') return he; 
                return {}; 
              }
              
              // 再次确保全局可访问
              try{ window.require = require; }catch(_){ }
              try{ globalThis.require = require; }catch(_){ }
            }
          }catch(e){
            console.warn('CommonJS shim error:', e);
          }
        })()''';
        await controller.runJavaScript(commonJsShim);
        await controller.runJavaScript(scriptText);
        // 触发一次探测
        await controller.runJavaScript(
          "(function(){ try{ const found=[]; const c=['sixyinSearch','sixyinSearchImpl','search','musicSearch','searchMusic']; for(const n of c){ try{ const f=eval(n); if(typeof f==='function'){ found.push(n);} }catch(e){} } try{ if (typeof module!=='undefined' && module && module.exports && typeof module.exports.search==='function'){ found.push('module.exports.search'); } }catch(e){} if(found.length){ SixyinBridge.postMessage('adapter_found:'+found.join(',')); return;} const g=[]; for(const k in window){ try{ if(typeof window[k]==='function' && k.toLowerCase().includes('search')) g.push(k);}catch(e){} } SixyinBridge.postMessage('adapter_found:'+g.join(',')); }catch(e){ SixyinBridge.postMessage('adapter_found:'); } })()",
        );
      } else {
        // 兜底：仍然尝试在页面里用 fetch 注入
        print('⚠️ [WebViewJsSource] Dart 下载失败，回退到 WebView 内 fetch 尝试');
        final escapedList = urls
            .map((u) => "'" + u.replaceAll("'", "") + "'")
            .join(',');
        final js =
            "(async()=>{const urls=[" +
            escapedList +
            "]; const safePost=(m)=>{try{ if(window.SixyinBridge && SixyinBridge.postMessage){ SixyinBridge.postMessage(m);} }catch(_){}}; const fetchWithTimeout=async(u,ms)=>{const ctrl=new AbortController(); const t=setTimeout(()=>ctrl.abort(),ms); try{const res=await fetch(u,{cache:'no-store',signal:ctrl.signal}); clearTimeout(t); return res}catch(e){clearTimeout(t); throw e}}; const injectLX=()=>{ try{ var g = (typeof globalThis !== 'undefined') ? globalThis : (this||{}); if(!g.lx){ g.lx = { EVENT_NAMES:{}, APP_EVENT_NAMES:{}, CURRENT_PLATFORM:'desktop', APP_SETTING:{}, version:'2.4.0', isDev:false, on:function(){}, off:function(){}, emit:function(){}, }; } }catch(e){} }; for (const u of urls){ try{ const res = await fetchWithTimeout(u, 8000); const t = await res.text(); injectLX(); eval(t); safePost('loaded:'+u); window.__sixyin_loaded = true; break; }catch(e){ safePost('load_fail:'+u); }} safePost('adapter_probe:start'); try{ const found=[]; const cands=['sixyinSearch','sixyinSearchImpl','search','musicSearch','searchMusic']; for(const n of cands){ try{ const f = eval(n); if(typeof f==='function'){ found.push(n);} }catch(e){} } if(found.length===0){ try{ const globals=[]; for (const k in window){ try{ if(typeof window[k]==='function' && k.toLowerCase().includes('search')) globals.push(k);}catch(e){} } safePost('adapter_found:'+globals.join(',')); }catch(e){ safePost('adapter_found:'); } } else { safePost('adapter_found:'+found.join(',')); } }catch(e){ safePost('adapter_found:'); } })()";
        await controller.runJavaScript(js);
      }
    }

    // 注入统一搜索适配器（静默模式，避免大量 console 消息导致 OOM）
    const adapter = r'''
      if (!window.__sixyin_adapter_injected__) {
        window.__sixyin_adapter_injected__ = true;
        window.sixyinSearch = async function(platform, keyword, page){
          console.log('[Adapter] 搜索调用:', platform, keyword, page);
          // 优先尝试明确候选
          const candidates = [
            'sixyinSearchImpl', 'search', 'musicSearch', 'searchMusic'
          ];
          for(const fnName of candidates) {
            try {
              const fn = eval(fnName);
              if(typeof fn === 'function') {
                console.log('[Adapter] 尝试函数:', fnName);
                
                // 尝试不同的参数组合适配不同的函数签名
                let result = null;
                const paramCombos = [
                  // xiaoqiu.js/MusicFree 格式: searchMusic(query, page)
                  [keyword, page||1],
                  // 标准格式: searchMusic(platform, keyword, page) 
                  [platform, keyword, page||1],
                  // 简化格式: searchMusic(keyword)
                  [keyword],
                  // 对象格式: searchMusic({query, page, platform})
                  [{query: keyword, page: page||1, platform: platform}]
                ];
                
                for(let i = 0; i < paramCombos.length; i++) {
                  const params = paramCombos[i];
                  try {
                    console.log('[Adapter] 尝试参数组合', i+1, ':', JSON.stringify(params));
                    result = await fn(...params);
                    console.log('[Adapter] 参数组合', i+1, '成功，结果:', result);
                    
                    // 检查结果是否有效
                    if(result && (Array.isArray(result) || (result.data && Array.isArray(result.data)))) {
                      console.log('[Adapter] 找到有效结果，使用参数组合', i+1);
                      break;
                    }
                  } catch(e) {
                    console.log('[Adapter] 参数组合', i+1, '失败:', e.toString());
                    continue;
                  }
                }
                
                console.log('[Adapter] 函数结果:', fnName, result);
                
                // 处理Promise返回值
                if (result && typeof result.then === 'function') {
                  console.log('[Adapter] 检测到Promise，等待结果...');
                  try {
                    const promiseResult = await result;
                    console.log('[Adapter] Promise解析结果:', promiseResult);
                    result = promiseResult;
                  } catch (promiseError) {
                    console.warn('[Adapter] Promise失败:', promiseError);
                    continue;
                  }
                }
                
                // 标准化返回格式
                if (result) {
                  if (Array.isArray(result)) {
                    console.log('[Adapter] 返回数组，长度:', result.length);
                    return result;
                  }
                  if (result.data && Array.isArray(result.data)) {
                    console.log('[Adapter] 返回result.data，长度:', result.data.length);
                    return result.data;
                  }
                  if (result.list && Array.isArray(result.list)) {
                    console.log('[Adapter] 返回result.list，长度:', result.list.length);
                    return result.list;
                  }
                  // 如果是对象但不是数组，尝试转换
                  if (typeof result === 'object' && result !== null) {
                    const keys = Object.keys(result);
                    console.log('[Adapter] 对象结果，键值:', keys);
                    if (keys.length > 0) {
                      for (const key of ['songs', 'data', 'list', 'result', 'items']) {
                        if (result[key] && Array.isArray(result[key])) {
                          console.log('[Adapter] 找到数组字段:', key, '长度:', result[key].length);
                          return result[key];
                        }
                      }
                    }
                  }
                }
              }
            } catch(e) {
              console.warn('[Adapter] 函数调用失败:', fnName, e);
            }
          }
          
          // CommonJS: module.exports.search(query, page, type) 
          try {
            if (typeof module !== 'undefined' && module && module.exports && typeof module.exports.search === 'function') {
              console.log('[Adapter] 尝试 module.exports.search');
              const res = await module.exports.search(keyword, page||1, 'music');
              console.log('[Adapter] module.exports.search 结果:', res);
              
              if (res) {
                if (Array.isArray(res)) return res;
                if (res.data && Array.isArray(res.data)) return res.data;
                if (res.list && Array.isArray(res.list)) return res.list;
              }
            }
          } catch(e) {
            console.warn('[Adapter] module.exports.search 失败:', e);
          }
          
          // MusicFree format: 特殊处理xiaoqiu等MusicFree格式脚本
          try {
            if (typeof module !== 'undefined' && module && module.exports) {
              // 检查是否是MusicFree格式
              const exp = module.exports;
              if (exp.platform && (exp.search || exp.searchMusic)) {
                console.log('[Adapter] 检测到MusicFree格式，尝试搜索');
                const searchFn = exp.search || exp.searchMusic;
                if (typeof searchFn === 'function') {
                  // MusicFree格式通常需要特定的查询对象
                  const query = { 
                    keyword: keyword, 
                    page: page || 1,
                    type: 'music' // 添加类型参数
                  };
                  
                  // 调用搜索函数
                  const res = await searchFn(query);
                  console.log('[Adapter] MusicFree搜索结果:', res);
                  
                  // 处理不同的返回格式
                  if (res) {
                    // 直接是数组
                    if (Array.isArray(res) && res.length > 0) {
                      return res;
                    }
                    
                    // 包装在对象中
                    if (typeof res === 'object') {
                      const keys = ['data', 'list', 'songs', 'result', 'items'];
                      for (const key of keys) {
                        if (res[key] && Array.isArray(res[key]) && res[key].length > 0) {
                          console.log('[Adapter] 找到MusicFree结果数组:', key, res[key].length);
                          return res[key];
                        }
                      }
                      
                      // 检查是否有嵌套结构
                      if (res.code === 0 || res.success) {
                        for (const key of keys) {
                          if (res[key] && Array.isArray(res[key]) && res[key].length > 0) {
                            return res[key];
                          }
                        }
                      }
                    }
                    
                    // 如果是Promise，等待结果
                    if (res && typeof res.then === 'function') {
                      console.log('[Adapter] MusicFree返回Promise，等待结果...');
                      const promiseRes = await res;
                      if (promiseRes && Array.isArray(promiseRes)) {
                        return promiseRes;
                      }
                    }
                  }
                }
              }
            }
          } catch(e) {
            console.warn('[Adapter] MusicFree格式搜索失败:', e);
          }
          
          console.log('[Adapter] 所有方法都失败，返回空数组');
          return [];
        };
        window.sixyinAutoSearch = async function(keyword, page){
          const plats=['qq','netease','kuwo','kugou'];
          for(const p of plats){ 
            try{ 
              const r=await window.sixyinSearch(p, keyword, page||1); 
              if(r && Array.isArray(r) && r.length > 0) return r; 
            }catch(e){
              console.warn('[Adapter] 平台搜索失败:', p, e);
            } 
          }
          return [];
        };
      }
      ''';
    await controller.runJavaScript(adapter);
    await controller.runJavaScript(
      "try{SixyinBridge.postMessage('adapter_injected')}catch(e){}",
    );

    print('✅ [WebViewJsSource] WebView音源初始化完成！');
    _inited = true;
    if (!_ready.isCompleted) _ready.complete();
  }

  /// 轻量探测：在 WebView 中重新扫描可用搜索函数
  Future<Map<String, dynamic>> detectAdapterFunctions() async {
    await _ready.future;
    try {
      _pendingProbe = Completer<List<String>>();
      const String probeJs = r'''(function(){
        const safePost=(m)=>{try{ if(window.SixyinBridge && SixyinBridge.postMessage){ SixyinBridge.postMessage(m);} }catch(_){}};
        try{
          const found=[];
          const cands=['sixyinSearch','sixyinSearchImpl','search','musicSearch','searchMusic'];
          for(const n of cands){ try{ const f = eval(n); if(typeof f==='function'){ found.push(n);} }catch(e){} }
          if(found.length===0){
            try{
              const globals=[];
              for(const k in window){ try{ if(typeof window[k]==='function' && k.toLowerCase().includes('search')) globals.push(k);}catch(e){} }
              safePost('adapter_found:'+globals.join(','));
            }catch(e){ safePost('adapter_found:'); }
          } else {
            safePost('adapter_found:'+found.join(','));
          }
        }catch(e){ safePost('adapter_found:'); }
      })()''';
      await controller.runJavaScript(probeJs);
      final List<String> names = await _pendingProbe!.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => <String>[],
      );
      return {'ok': names.isNotEmpty, 'functions': names};
    } catch (_) {
      return {'ok': false, 'functions': <String>[]};
    } finally {
      _pendingProbe = null;
    }
  }

  Future<List<Map<String, dynamic>>> search(
    String keyword, {
    String platform = 'auto',
    int page = 1,
  }) async {
    print('🔍 [WebViewJsSource] 开始搜索: $keyword, 平台: $platform, 页面: $page');
    await _ready.future;

    final escaped = keyword.replaceAll("'", " ");
    // 优先尝试标准函数；若不可用，尝试 LX 事件总线协议
    if (!_hasValidAdapter) {
      print('⚠️ [WebViewJsSource] 未发现标准函数，尝试 LX 事件协议');
      final String p = platform == 'auto' ? 'qq' : platform;
      final escapedEvt = escaped;
      final String jsEvt =
          "(async()=>{try{ if(window.lx && lx.EVENT_NAMES && typeof lx.emit==='function'){ const evt = lx.EVENT_NAMES.SOURCE_SEARCH || 'SOURCE_SEARCH'; const payload={ source: '" +
          p +
          "', text: '" +
          escapedEvt +
          "', page: " +
          page.toString() +
          " }; const r = await lx.emit(evt, payload); return JSON.stringify(r||[]);} return '[]'; }catch(e){ return '[]'; } })()";
      final resEvt = await controller.runJavaScriptReturningResult(jsEvt);
      final textEvt = resEvt is String ? resEvt : resEvt.toString();
      try {
        final data = jsonDecode(textEvt);
        if (data is List) {
          return data
              .where((e) => e is Map)
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
        }
      } catch (_) {}
      return const [];
    }
    // moved earlier
    final fn =
        platform == 'auto'
            ? "window.sixyinAutoSearch('" +
                escaped +
                "'," +
                page.toString() +
                ")"
            : "window.sixyinSearch('" +
                platform +
                "','" +
                escaped +
                "'," +
                page.toString() +
                ")";
    // 使用事件机制代替同步返回，解决异步 Promise 问题
    final js = """
      (function(){
        try{
          console.log('[WebView] 开始异步搜索，使用事件回调');
          function sendResult(data) {
            try {
              window.SixyinBridge.postMessage('search_result:' + JSON.stringify(data));
            } catch(e) {
              console.error('[WebView] 发送结果失败:', e);
            }
          }
          
          async function doSearch() {
            try {
              console.log('[WebView] 开始执行搜索函数');
              const r = await ($fn);
              console.log('[WebView] 搜索函数返回:', r);
              
              const norm=(x)=>{try{if(Array.isArray(x)){console.log('[WebView] 返回数组，长度:', x.length);return x;} if(x&&Array.isArray(x.data)){console.log('[WebView] 返回x.data，长度:', x.data.length);return x.data;} if(x&&Array.isArray(x.list)){console.log('[WebView] 返回x.list，长度:', x.list.length);return x.list;} if(x&&Array.isArray(x.songs)){console.log('[WebView] 返回x.songs，长度:', x.songs.length);return x.songs;} if(typeof x === 'object' && x !== null){const keys = Object.keys(x); console.log('[WebView] 对象键值:', keys); for(const key of ['data','list','songs','result','items']){if(x[key] && Array.isArray(x[key])){console.log('[WebView] 找到数组字段:', key, '长度:', x[key].length);return x[key];}}}}catch(e){console.warn('[WebView] norm错误:', e);} return [];};
              
              const result = norm(r);
              console.log('[WebView] 最终结果数量:', result.length);
              
              const safeResult = result.map((item,index)=>{try{console.log('[WebView] 原始项目',index,':', JSON.stringify(item)); const safe={};if(item.title||item.name)safe.title=item.title||item.name;if(item.artist||item.singer)safe.artist=item.artist||item.singer;if(item.album)safe.album=item.album;if(item.duration)safe.duration=item.duration;if(item.url||item.link)safe.url=item.url||item.link;if(item.id)safe.id=item.id;if(item.platform)safe.platform=item.platform; else safe.platform='$platform';if(item.songmid)safe.songmid=item.songmid;if(item.hash)safe.hash=item.hash;console.log('[WebView] 映射后项目',index,':', JSON.stringify(safe));return safe;}catch(e){console.warn('[WebView] 项目',index,'序列化失败:', e);return {title:'Unknown',artist:'Unknown'};}});
              
              console.log('[WebView] 安全结果数量:', safeResult.length);
              window.__sixyin_last_json = safeResult;
              sendResult(safeResult);
            } catch(e) {
              console.error('[WebView] 搜索异常:', e);
              window.__sixyin_last_json = [];
              sendResult([]);
            }
          }
          
          doSearch();
          return 'async_started';
        } catch(e) {
          console.error('[WebView] 启动搜索失败:', e);
          return '[]';
        }
      })()
    """.replaceAll('\$fn', fn);
    print('🔄 [WebViewJsSource] 启动异步搜索...');

    // 准备接收搜索结果的 Completer
    _pendingSearchCompleter = Completer<List<Map<String, dynamic>>>();

    // 启动搜索
    await controller.runJavaScript(js);
    print('🔄 [WebViewJsSource] 搜索已启动，等待结果...');

    // 等待搜索结果事件（带超时）
    try {
      final result = await _pendingSearchCompleter!.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          print('⏰ [WebViewJsSource] 搜索超时，尝试读取备份变量');
          // 超时时清理 Completer
          _pendingSearchCompleter = null;
          return <Map<String, dynamic>>[];
        },
      );

      if (result.isNotEmpty) {
        print('✅ [WebViewJsSource] 通过事件回调得到 ${result.length} 项');
        return result;
      }
    } catch (e) {
      print('⚠️ [WebViewJsSource] 等待搜索结果异常: $e');
      _pendingSearchCompleter = null;
    }

    // 兜底：从备份变量读取
    print('🔄 [WebViewJsSource] 从备份变量读取结果...');
    try {
      final backup = await controller.runJavaScriptReturningResult(
        "(function(){try{console.log('[BackupRead] 备份变量类型:', typeof window.__sixyin_last_json); console.log('[BackupRead] 备份变量长度:', window.__sixyin_last_json ? window.__sixyin_last_json.length : 'null'); return JSON.stringify(window.__sixyin_last_json||[]);}catch(e){console.error('[BackupRead] 错误:', e); return '[]'}})()",
      );

      if (backup is String && backup.isNotEmpty && backup != '[]') {
        final parsed = jsonDecode(backup);
        if (parsed is List) {
          final out =
              parsed
                  .where((e) => e is Map)
                  .map((e) => (e as Map).cast<String, dynamic>())
                  .toList();
          print('✅ [WebViewJsSource] 从备份变量成功解析 ${out.length} 项');
          return out;
        }
      }
    } catch (e) {
      print('⚠️ [WebViewJsSource] 备份读取失败: $e');
    }

    print('📤 [WebViewJsSource] 最终返回空结果');
    return const [];
  }

  Future<String?> resolveMusicUrl({
    required String platform,
    required String songId,
    String quality = '320k',
  }) async {
    await _ready.future;

    // 平台映射 (LX Music格式)
    String lxPlatform = platform;
    switch (platform.toLowerCase()) {
      case 'qq':
      case 'tencent':
        lxPlatform = 'tx';
        break;
      case 'netease':
      case '163':
        lxPlatform = 'wy';
        break;
      case 'kuwo':
        lxPlatform = 'kw';
        break;
      case 'kugou':
        lxPlatform = 'kg';
        break;
      case 'migu':
        lxPlatform = 'mg';
        break;
      case 'auto':
      default:
        // auto或未知平台默认使用腾讯QQ音乐
        lxPlatform = 'tx';
        print('🔄 [WebViewJsSource] 平台 "$platform" 映射到默认平台 "tx"');
        break;
    }

    print('🔗 [WebViewJsSource] 开始解析播放链接');
    print('🔗 原始平台: $platform -> LX平台: $lxPlatform');
    print('🔗 歌曲ID: $songId, 质量: $quality');

    final String js = """
      (async()=>{
        try{
          console.log('[URL解析] 开始解析，songId: $songId, platform: $lxPlatform, quality: $quality');
          
          // 优先尝试 Music Free 格式 (xiaoqiu.js)
          if(typeof getMediaSource === 'function'){
            console.log('[URL解析] 检测到 Music Free 格式，使用 getMediaSource');
            
            const musicItem = {
              id: $songId,
              songmid: '$songId'
            };
            
                            // xiaoqiu.js 的质量参数映射
                const qualityMap = {
                  '128k': 'low',
                  '320k': 'standard',
                  'flac': 'high',
                  'default': 'standard'
                };
                const mappedQuality = qualityMap['$quality'] || qualityMap['default'];
                
                console.log('[URL解析] 调用 getMediaSource，参数:', JSON.stringify(musicItem), '质量:', '$quality', '->', mappedQuality);
                const result = await getMediaSource(musicItem, mappedQuality);
                console.log('[URL解析] getMediaSource 返回结果:', result);
                
                // 检查返回结果是否包含警告信息和版权问题
                if(result && result.msg && result.msg.includes('无法获取播放链接')) {
                  console.warn('[URL解析] ⚠️ QQ音乐获取失败:', result.msg);
                  
                  if(result.url && result.url.includes('kuwo.cn')) {
                    console.warn('[URL解析] ⚠️ 检测到版权问题：API回退到酷我音乐，但该音源可能没有版权');
                    console.log('[URL解析] 为避免播放失败，拒绝使用有版权问题的链接');
                    
                    // 直接发送空结果，提示用户版权问题
                    window.SixyinBridge.postMessage('url_result:COPYRIGHT_ERROR');
                    return;
                  }
                }
            
            if(result) {
              let finalUrl = '';
              if(typeof result === 'string') {
                finalUrl = result;
              } else if(result.url && typeof result.url === 'string') {
                finalUrl = result.url;
              } else if(result.link && typeof result.link === 'string') {
                finalUrl = result.link;
              }
              
              if(finalUrl && finalUrl.length > 0) {
                console.log('[URL解析] Music Free 格式成功，返回URL:', finalUrl);
                window.SixyinBridge.postMessage('url_result:' + finalUrl);
                return;
              } else {
                console.log('[URL解析] Music Free 返回了无效结果:', JSON.stringify(result));
              }
            }
          }
          
          // 回退到 LX Music 格式  
          if(window.lx && lx.EVENT_NAMES && typeof lx.emit==='function'){ 
            console.log('[URL解析] 回退到 LX Music 格式');
            const payload = { 
              action: 'musicUrl', 
              source: '$lxPlatform', 
              info: { 
                type: '$quality', 
                musicInfo: { 
                  songmid: '$songId', 
                  hash: '$songId' 
                } 
              } 
            };
            console.log('[URL解析] LX请求参数:', JSON.stringify(payload));
            
            const url = await lx.emit(lx.EVENT_NAMES.request, payload);
            console.log('[URL解析] LX返回结果:', url);
            
            if(typeof url==='string' && url.length > 0) {
              console.log('[URL解析] LX成功获取字符串URL:', url);
              window.SixyinBridge.postMessage('url_result:' + url);
              return;
            }
            if(url && url.url && url.url.length > 0) {
              console.log('[URL解析] LX成功获取对象URL:', url.url);
              window.SixyinBridge.postMessage('url_result:' + url.url);
              return;
            }
          }
          
          console.error('[URL解析] 所有方法都失败了');
          console.log('[URL解析] getMediaSource存在:', typeof getMediaSource);
          console.log('[URL解析] window.lx存在:', !!window.lx);
          if(window.lx) {
            console.log('[URL解析] lx.EVENT_NAMES存在:', !!lx.EVENT_NAMES);  
            console.log('[URL解析] lx.emit类型:', typeof lx.emit);
          }
          window.SixyinBridge.postMessage('url_result:');
          return;
        } catch(e) {
          console.error('[URL解析] 异常:', e);
          window.SixyinBridge.postMessage('url_result:');
          return;
        }
      })()
    """;

    // 设置等待URL解析结果的 Completer
    _pendingUrlCompleter = Completer<String>();

    // 启动异步URL解析
    await controller.runJavaScript(js);

    // 等待结果，设置10秒超时
    try {
      final result = await _pendingUrlCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ [WebViewJsSource] URL解析超时');
          return '';
        },
      );

      _pendingUrlCompleter = null;

      if (result.isEmpty || result == 'null' || result == 'undefined') {
        print('❌ [WebViewJsSource] URL解析失败');
        return null;
      }

      print('✅ [WebViewJsSource] URL解析成功: $result');
      return result;
    } catch (e) {
      print('❌ [WebViewJsSource] URL解析异常: $e');
      _pendingUrlCompleter = null;
      return null;
    }
  }
}
