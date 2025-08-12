import 'dart:async';
import 'package:flutter_js/flutter_js.dart';
import 'package:dio/dio.dart';
import '../../presentation/providers/source_settings_provider.dart';
import 'dart:convert';

class LocalJsSourceService {
  final JavascriptRuntime _rt;
  final Dio _http;
  bool _loaded = false;

  LocalJsSourceService._(this._rt, this._http);

  static Future<LocalJsSourceService> create() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // 设置transformer为处理任意响应类型，避免content-type解析问题
    dio.transformer = BackgroundTransformer();

    return LocalJsSourceService._(getJavascriptRuntime(), dio);
  }

  Future<void> loadScript(SourceSettings settings) async {
    print('🔧 [LocalJsSource] 开始加载JS音源');
    print('🔧 [LocalJsSource] 启用状态: ${settings.enabled}');
    print('🔧 [LocalJsSource] 脚本URL长度: ${settings.scriptUrl.length}');
    print('🔧 [LocalJsSource] 脚本URL: ${settings.scriptUrl}');
    // 分段打印长URL，避免截断
    if (settings.scriptUrl.length > 100) {
      print(
        '🔧 [LocalJsSource] URL前半部分: ${settings.scriptUrl.substring(0, settings.scriptUrl.length ~/ 2)}',
      );
      print(
        '🔧 [LocalJsSource] URL后半部分: ${settings.scriptUrl.substring(settings.scriptUrl.length ~/ 2)}',
      );
    }

    if (!settings.enabled) {
      print('❌ [LocalJsSource] 音源未启用');
      _loaded = false;
      return;
    }
    if (settings.scriptUrl.isEmpty) {
      print('❌ [LocalJsSource] 脚本URL为空');
      _loaded = false;
      return;
    }

    // 检查URL是否被截断，如果是xiaoqiu相关且不以.js结尾，尝试修复
    String finalUrl = settings.scriptUrl;
    if (finalUrl.contains('xiaoqiu') &&
        !finalUrl.endsWith('.js') &&
        !finalUrl.endsWith('/')) {
      if (finalUrl.endsWith('.j')) {
        finalUrl = finalUrl + 's';
        print('🔧 [LocalJsSource] 检测到URL截断，自动修复: $finalUrl');
      }
    }
    // 定义多个镜像源，优先使用支持完整功能的脚本
    final fallbackUrls = [
      finalUrl, // 使用修复后的URL
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

    // 去重
    final uniqueUrls = fallbackUrls.toSet().toList();

    print('🔄 [LocalJsSource] 尝试加载 ${uniqueUrls.length} 个镜像源');

    for (final url in uniqueUrls) {
      print('🌐 [LocalJsSource] 正在请求: $url');
      try {
        final resp = await _http.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 8),
            validateStatus: (code) => code != null && code >= 200 && code < 400,
          ),
        );
        final script = resp.data ?? '';
        print('📥 [LocalJsSource] 脚本下载成功，长度: ${script.length} 字符');

        if (script.isEmpty) {
          print('⚠️ [LocalJsSource] 脚本内容为空，尝试下个镜像');
          continue; // 尝试下个镜像
        }

        print('🍪 [LocalJsSource] 注入Cookie变量');
        // 注入 cookie 变量
        final cookieInit =
            "var MUSIC_U='${settings.cookieNetease}'; var ts_last='${settings.cookieTencent}';";
        _rt.evaluate(cookieInit);

        print('🔄 [LocalJsSource] 开始执行JS脚本...');
        // 注入简易 LX 环境以兼容为 LX 定制的音源脚本
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
              request: 'request',
              inited: 'inited',
              REQUEST: 'request'
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
                request: function(url, options, cb){
                  try{
                    var opts = options || {};
                    fetch(url, opts).then(function(r){
                      return r.text().then(function(t){
                        var body; try{ body = JSON.parse(t); }catch(_){ body = t; }
                        var headers = {}; try{ if (r.headers && r.headers.forEach) { r.headers.forEach(function(v,k){ headers[k]=v; }); } }catch(_){ }
                        var resp = { statusCode: r.status, status: r.status, headers: headers, body: body };
                        if (typeof cb === 'function') cb(null, resp);
                      });
                    }).catch(function(err){ if (typeof cb === 'function') cb(err); });
                  }catch(e){ if (typeof cb === 'function') cb(e); }
                },
                send: function(){},
              };
            }
          }catch(e){}
        })()''';
        _rt.evaluate(lxShim);

        // 为LocalJS注入网络请求和Promise支持
        const String networkShim = r'''(function(){
          try{
            var g = (typeof globalThis !== 'undefined') ? globalThis : (typeof window !== 'undefined' ? window : this);
            
            // 注入基本的Promise支持
            if (typeof g.Promise !== 'function') {
              g.Promise = function(executor) {
                var self = this;
                self.state = 'pending';
                self.value = undefined;
                self.handlers = [];
                
                function resolve(value) {
                  if (self.state === 'pending') {
                    self.state = 'fulfilled';
                    self.value = value;
                    self.handlers.forEach(function(handler) {
                      handler.onFulfilled(value);
                    });
                  }
                }
                
                function reject(reason) {
                  if (self.state === 'pending') {
                    self.state = 'rejected';
                    self.value = reason;
                    self.handlers.forEach(function(handler) {
                      handler.onRejected(reason);
                    });
                  }
                }
                
                try {
                  executor(resolve, reject);
                } catch (e) {
                  reject(e);
                }
              };
              
              g.Promise.prototype.then = function(onFulfilled, onRejected) {
                var self = this;
                return new g.Promise(function(resolve, reject) {
                  function handle() {
                    if (self.state === 'fulfilled') {
                      if (typeof onFulfilled === 'function') {
                        try {
                          resolve(onFulfilled(self.value));
                        } catch (e) {
                          reject(e);
                        }
                      } else {
                        resolve(self.value);
                      }
                    } else if (self.state === 'rejected') {
                      if (typeof onRejected === 'function') {
                        try {
                          resolve(onRejected(self.value));
                        } catch (e) {
                          reject(e);
                        }
                      } else {
                        reject(self.value);
                      }
                    } else {
                      self.handlers.push({
                        onFulfilled: function(value) {
                          if (typeof onFulfilled === 'function') {
                            try {
                              resolve(onFulfilled(value));
                            } catch (e) {
                              reject(e);
                            }
                          } else {
                            resolve(value);
                          }
                        },
                        onRejected: function(reason) {
                          if (typeof onRejected === 'function') {
                            try {
                              resolve(onRejected(reason));
                            } catch (e) {
                              reject(e);
                            }
                          } else {
                            reject(reason);
                          }
                        }
                      });
                    }
                  }
                  handle();
                });
              };
              
              g.Promise.resolve = function(value) {
                return new g.Promise(function(resolve) {
                  resolve(value);
                });
              };
              
              g.Promise.reject = function(reason) {
                return new g.Promise(function(resolve, reject) {
                  reject(reason);
                });
              };
            }
            
            // 注入一个支持基本功能的fetch实现
            if (typeof g.fetch !== 'function') {
              g.fetch = function(url, options = {}) {
                console.log('[LocalJS] fetch请求:', url);
                
                // 对于xiaoqiu.js等脚本，提供模拟响应避免报错
                if (url.includes('qq.com') || url.includes('music')) {
                  return g.Promise.resolve({
                    ok: true,
                    status: 200,
                    statusText: 'OK',
                    text: function() { return g.Promise.resolve('{"code":0,"data":{"list":[]}}'); },
                    json: function() { return g.Promise.resolve({code: 0, data: {list: []}}); },
                  });
                }
                
                return g.Promise.resolve({
                  ok: false,
                  status: 0,
                  statusText: 'LocalJS环境网络请求受限',
                  text: function() { return g.Promise.resolve('{}'); },
                  json: function() { return g.Promise.resolve({}); },
                });
              };
            }
            
            // 为axios提供基本实现
            if (typeof g.axios !== 'function') {
              g.axios = function(config) {
                if (typeof config === 'string') {
                  return g.fetch(config);
                }
                return g.fetch(config.url || '', config);
              };
              g.axios.get = function(url, config) {
                return g.fetch(url, {method: 'GET', ...(config || {})});
              };
              g.axios.post = function(url, data, config) {
                return g.fetch(url, {method: 'POST', body: data, ...(config || {})});
              };
            }
            
            console.log('[LocalJS] 网络和Promise shim已注入');
            
          }catch(e){
            console.warn && console.warn('LocalJS NetworkShim error:', e);
          }
        })()''';
        _rt.evaluate(networkShim);

        // 优先注入CommonJS环境，确保exports和module在脚本执行前就存在
        const String commonJsShim = r'''(function(){
          try{
            var g = (typeof globalThis !== 'undefined') ? globalThis : (typeof window !== 'undefined' ? window : this);
            
            // 优先确保exports和module存在
            if (!g.exports) {
              g.exports = {};
            }
            if (!g.module) {
              g.module = { exports: g.exports };
            }
            
            if (typeof require !== 'function'){
              function __axios(opts){
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
              }
              __axios.get = function(url, opts){ opts=opts||{}; return __axios({ url: url, method: 'GET', headers: (opts.headers||{}) }); };
              __axios.post = function(url, data, opts){ opts=opts||{}; return __axios({ url: url, method: 'POST', headers: (opts.headers||{}), data: data }); };
              __axios.default = __axios;
              
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
                    return s.replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#39;/g,'\'').replace(/&quot;/g,'"'); 
                  }catch(e){ 
                    return s; 
                  } 
                } 
              };
              
              var __cjs_cache = {};
              function __wrapDefault(obj){ try{ obj.default = obj.default || obj; }catch(_){} return obj; }
              function require(name){
                if (__cjs_cache[name]) return __cjs_cache[name];
                if (name === 'axios') { __cjs_cache[name] = __axios; return __axios; }
                if (name === 'crypto-js') { var c = __wrapDefault(CryptoJs); __cjs_cache[name]=c; return c; }
                if (name === 'he') { var h = __wrapDefault(he); __cjs_cache[name]=h; return h; }
                var empty = {}; __wrapDefault(empty); __cjs_cache[name]=empty; return empty;
              }
              
              try{ g.require = require; }catch(_){ }
            }
          }catch(e){
            console.warn && console.warn('LocalJS CommonJS shim error:', e);
          }
        })()''';
        _rt.evaluate(commonJsShim);
        _rt.evaluate(script);

        // 若为 Huibq 系列并缺搜索，尝试注入 Music_Free 插件集合
        try {
          final listUrls = [
            'https://fastly.jsdelivr.net/gh/Huibq/keep-alive/Music_Free/myPlugins.json',
            'https://cdn.jsdelivr.net/gh/Huibq/keep-alive/Music_Free/myPlugins.json',
            'https://raw.githubusercontent.com/Huibq/keep-alive/main/Music_Free/myPlugins.json',
          ];
          String? listText;
          for (final lu in listUrls) {
            try {
              final r = await _http.get<String>(
                lu,
                options: Options(responseType: ResponseType.plain),
              );
              listText = r.data;
              if (listText != null && listText.isNotEmpty) break;
            } catch (_) {}
          }
          if (listText != null && listText.isNotEmpty) {
            print('📦 [LocalJsSource] 读取插件清单');
            final Map<String, dynamic> json = jsonDecode(listText);
            final List items = (json['plugins'] as List? ?? const []);
            for (final it in items) {
              final url = (it is Map ? it['url']?.toString() : null) ?? '';
              if (url.isEmpty) continue;
              try {
                final pr = await _http.get<String>(
                  url,
                  options: Options(responseType: ResponseType.plain),
                );
                final script = pr.data ?? '';
                if (script.isNotEmpty) {
                  print('📦 [LocalJsSource] 注入插件: ' + url);
                  _rt.evaluate(script);
                }
              } catch (_) {}
            }
          }
        } catch (e) {
          print('⚠️ [LocalJsSource] 加载插件清单失败: $e');
        }

        print('✅ [LocalJsSource] JS脚本执行成功！');
        _loaded = true;
        return; // 成功加载，退出
      } catch (e) {
        print('❌ [LocalJsSource] 加载失败: $url, 错误: $e');
        continue; // 尝试下一个镜像
      }
    }

    // 如果所有镜像都失败
    print('❌ [LocalJsSource] 所有镜像源都失败了！');
    _loaded = false;
  }

  bool get isReady => _loaded;

  // 安全执行小段 JS，返回字符串
  String evaluateToString(String js) {
    final res = _rt.evaluate(js);
    return res.stringResult;
  }

  /// 轻量级能力检测：检查脚本是否已正确注入可用的搜索函数
  /// 不实际发起网络请求，仅检测函数是否存在
  Future<Map<String, dynamic>> detectAdapterFunctions() async {
    if (!_loaded) {
      return {'ok': false, 'functions': <String>[]};
    }

    try {
      // 优先检测常见导出函数名
      final String checkJs = """
        (function(){
          var ok = [];
          try {
            var names = ${jsonEncode(<String>['sixyinSearch', 'sixyinSearchImpl', 'search', 'musicSearch', 'searchMusic'])};
            for (var i = 0; i < names.length; i++) {
              var n = names[i];
              try {
                var f = (typeof eval === 'function') ? eval(n) : (this && this[n]);
                if (typeof f === 'function') ok.push(n);
              } catch(e) {}
            }
          } catch(e) {}
          return JSON.stringify(ok);
        })()
      """;

      final res = _rt.evaluate(checkJs);
      final String text = res.stringResult;
      final List<dynamic> listDyn = jsonDecode(text) as List<dynamic>;
      final List<String> found = listDyn.map((e) => e.toString()).toList();

      // 若未发现常见函数，再宽松扫描所有包含 search 的全局函数名
      if (found.isEmpty) {
        final String scanJs = """
          (function(){
            var results = [];
            try {
              var g = this || global || {};
              for (var k in g) {
                try {
                  if (typeof g[k] === 'function' && (k+"" ).toLowerCase().indexOf('search') >= 0) {
                    results.push(k);
                  }
                } catch(e) {}
              }
            } catch(e) {}
            return JSON.stringify(results);
          })()
        """;
        final scanRes = _rt.evaluate(scanJs);
        final List<dynamic> scanList =
            jsonDecode(scanRes.stringResult) as List<dynamic>;
        final List<String> scanFound =
            scanList.map((e) => e.toString()).toList();
        return {'ok': scanFound.isNotEmpty, 'functions': scanFound};
      }

      return {'ok': found.isNotEmpty, 'functions': found};
    } catch (_) {
      return {'ok': false, 'functions': <String>[]};
    }
  }

  Future<List<Map<String, dynamic>>> search(
    String keyword, {
    String platform = 'auto',
    int page = 1,
  }) async {
    print('🔍 [LocalJsSource] 开始搜索: $keyword, 平台: $platform, 页面: $page');

    if (!_loaded) {
      print('❌ [LocalJsSource] 脚本未加载，无法搜索');
      return const [];
    }
    final escapedKw = keyword.replaceAll("'", " ");
    final platforms =
        platform == 'auto' ? ["qq", "netease", "kuwo", "kugou"] : [platform];
    // 尝试多种可能的函数名来适应混淆后的代码
    final candidateFunctions = [
      'sixyinSearch',
      'sixyinSearchImpl',
      'search',
      'musicSearch',
      'searchMusic',
    ];

    String? workingFunction;
    String result = '[]';

    // 首先检查哪个函数可用
    for (final funcName in candidateFunctions) {
      final checkJs = "typeof $funcName === 'function' ? 'yes' : 'no'";
      final checkResult = _rt.evaluate(checkJs);
      if (checkResult.stringResult == 'yes') {
        workingFunction = funcName;
        print('✅ [LocalJsSource] 找到可用函数: $funcName');
        break;
      }
    }

    if (workingFunction != null) {
      final js =
          "(function(){ " +
          "try { " +
          "var plats=" +
          jsonEncode(platforms) +
          ";" +
          // 将平台映射为 Huibq 所需代号
          "function mapPlat(p){ p=(p||'').toLowerCase(); if(p==='qq'||p==='tencent') return 'tx'; if(p==='netease'||p==='163') return 'wy'; if(p==='kuwo') return 'kw'; if(p==='kugou') return 'kg'; if(p==='migu') return 'mg'; return p; }" +
          "function norm(x){ " +
          "try{ " +
          "console.log && console.log('[LocalJS] norm处理:', typeof x, Array.isArray(x)); " +
          "function safeItem(item, idx) { " +
          "try{ " +
          "var safe = {}; " +
          "if(item.title || item.name) safe.title = item.title || item.name; " +
          "if(item.artist || item.singer) safe.artist = item.artist || item.singer; " +
          "if(item.album) safe.album = item.album; " +
          "if(item.duration) safe.duration = item.duration; " +
          "if(item.url || item.link) safe.url = item.url || item.link; " +
          "if(item.id) safe.id = item.id; " +
          "if(item.platform) safe.platform = item.platform; " +
          "return safe; " +
          "}catch(e){ " +
          "console.warn && console.warn('[LocalJS] 项目', idx, '处理失败:', e); " +
          "return {title:'Unknown',artist:'Unknown'}; " +
          "} " +
          "} " +
          "if(Array.isArray(x)) { " +
          "console.log && console.log('[LocalJS] 直接数组，长度:', x.length); " +
          "return x.map(safeItem); " +
          "} " +
          "if(x && Array.isArray(x.data)) { " +
          "console.log && console.log('[LocalJS] 发现x.data，长度:', x.data.length); " +
          "return x.data.map(safeItem); " +
          "} " +
          "if(x && Array.isArray(x.list)) { " +
          "console.log && console.log('[LocalJS] 发现x.list，长度:', x.list.length); " +
          "return x.list.map(safeItem); " +
          "} " +
          "if(x && Array.isArray(x.songs)) { " +
          "console.log && console.log('[LocalJS] 发现x.songs，长度:', x.songs.length); " +
          "return x.songs.map(safeItem); " +
          "} " +
          "if(x && Array.isArray(x.result)) { " +
          "console.log && console.log('[LocalJS] 发现x.result，长度:', x.result.length); " +
          "return x.result.map(safeItem); " +
          "} " +
          "if(typeof x === 'object' && x !== null) { " +
          "var keys = Object.keys(x); " +
          "console.log && console.log('[LocalJS] 对象键值:', keys); " +
          "for(var j=0; j<keys.length; j++) { " +
          "if(Array.isArray(x[keys[j]])) { " +
          "console.log && console.log('[LocalJS] 找到数组字段:', keys[j], '长度:', x[keys[j]].length); " +
          "return x[keys[j]].map(safeItem); " +
          "} " +
          "} " +
          "} " +
          "}catch(e){console.warn && console.warn('[LocalJS] norm error:', e);} " +
          "console.log && console.log('[LocalJS] 无法提取数组，返回空'); " +
          "return []; " +
          "} " +
          "for(var i=0;i<plats.length;i++){ " +
          "try { " +
          "var p=mapPlat(plats[i]); " +
          "console.log && console.log('[LocalJS] 尝试平台:', p); " +
          "var r=$workingFunction(p,'" +
          escapedKw +
          "'," +
          page.toString() +
          "); " +
          "console.log && console.log('[LocalJS] 平台原始结果:', p, typeof r); " +
          "if (r && typeof r.then === 'function') { " +
          "console.log && console.log('[LocalJS] 检测到Promise，检查状态'); " +
          "if (r.state === 'fulfilled' && r.value) { " +
          "console.log && console.log('[LocalJS] Promise已完成，使用value'); " +
          "r = r.value; " +
          "} else { " +
          "console.log && console.log('[LocalJS] Promise未完成，跳过'); " +
          "continue; " +
          "} " +
          "} " +
          "var n=norm(r); " +
          "if(n && n.length > 0) { " +
          "console.log && console.log('[LocalJS] 平台', p, '找到结果:', n.length, '条'); " +
          "return JSON.stringify(n); " +
          "} else { " +
          "console.log && console.log('[LocalJS] 平台', p, '无有效结果'); " +
          "} " +
          "} catch(e) { " +
          "console.warn && console.warn('[LocalJS] 平台搜索失败:', p, e); " +
          "} " +
          "} " +
          // 添加MusicFree格式支持
          "try { " +
          "if (typeof module !== 'undefined' && module && module.exports) { " +
          "var exp = module.exports; " +
          "if (exp.platform && (exp.search || exp.searchMusic)) { " +
          "console.log && console.log('[LocalJS] 检测到MusicFree格式，尝试搜索'); " +
          "var searchFn = exp.search || exp.searchMusic; " +
          "if (typeof searchFn === 'function') { " +
          "var query = { keyword: '" +
          escapedKw +
          "', page: " +
          page.toString() +
          ", type: 'music' }; " +
          "try { " +
          "var res = searchFn(query); " +
          "console.log && console.log('[LocalJS] MusicFree搜索结果类型:', typeof res); " +
          "console.log && console.log('[LocalJS] MusicFree搜索结果详情:', res); " +
          // 处理同步和异步结果
          "if (res && typeof res.then === 'function') { " +
          "console.log && console.log('[LocalJS] MusicFree返回Promise，尝试同步等待...'); " +
          "try { " +
          // 尝试检查Promise是否已经resolved
          "if (res.state === 'fulfilled') { " +
          "var n = norm(res.value); " +
          "if(n && n.length > 0) { " +
          "console.log && console.log('[LocalJS] Promise已完成，找到结果:', n.length, '条'); " +
          "return JSON.stringify(n); " +
          "} " +
          "} else { " +
          "console.log && console.log('[LocalJS] Promise未完成，状态:', res.state); " +
          "} " +
          "} catch(pe) { " +
          "console.warn && console.warn('[LocalJS] Promise处理失败:', pe); " +
          "} " +
          "} else { " +
          "var n = norm(res); " +
          "if(n && n.length > 0) { " +
          "console.log && console.log('[LocalJS] MusicFree找到结果:', n.length, '条'); " +
          "return JSON.stringify(n); " +
          "} " +
          "} " +
          "} catch(fe) { " +
          "console.warn && console.warn('[LocalJS] MusicFree函数调用失败:', fe); " +
          "} " +
          "} " +
          "} " +
          "} " +
          "} catch(e) { " +
          "console.warn && console.warn('[LocalJS] MusicFree格式搜索失败:', e); " +
          "} " +
          "console.log && console.log('[LocalJS] 所有平台都失败'); " +
          "return '[]'; " +
          "} catch(e) { " +
          "console.error && console.error('[LocalJS] 搜索代码执行失败:', e); " +
          "return '[]'; " +
          "} " +
          "})()";
      print('🔄 [LocalJsSource] 执行搜索JS代码...');
      final res = _rt.evaluate(js);
      result = res.stringResult;
      print('📤 [LocalJsSource] JS执行结果: $result');
    } else {
      print('❌ [LocalJsSource] 标准函数未找到，开始混淆函数检测...');

      // 改进的混淆函数检测
      try {
        final obfuscatedScanJs = """
          (function() {
            var candidates = [];
            var global = this || window || {};
            
            // 扫描所有全局函数，寻找可能的搜索函数
            for (var key in global) {
              try {
                if (typeof global[key] === 'function') {
                  var funcStr = global[key].toString();
                  // 检查函数体是否包含音乐搜索相关的特征
                  if (funcStr.length > 100 && (
                    funcStr.indexOf('qq') >= 0 || 
                    funcStr.indexOf('netease') >= 0 || 
                    funcStr.indexOf('music') >= 0 ||
                    funcStr.indexOf('http') >= 0 ||
                    funcStr.indexOf('url') >= 0 ||
                    funcStr.indexOf('search') >= 0
                  )) {
                    candidates.push(key);
                  }
                }
              } catch(e) { 
                continue; 
              }
            }
            
            // 过滤显然无关或会导致异常的函数名
            var blacklist = { 'fetch':1,'XMLHttpRequest':1,'webkit':1,'axios':1,'require':1,'setTimeout':1,'setInterval':1,'atob':1,'btoa':1,'Promise':1,'Buffer':1,'CryptoJs':1,'he':1 };
            var filtered = candidates.filter(function(n){ return !blacklist[n] && String(n).toLowerCase().indexOf('axios') === -1; });
            return JSON.stringify(filtered);
          })()
        """;

        final obfuscatedResult = _rt.evaluate(obfuscatedScanJs);
        final obfuscatedCandidates =
            jsonDecode(obfuscatedResult.stringResult) as List;
        print('🔍 [LocalJsSource] 发现混淆函数候选: ${obfuscatedCandidates.length} 个');

        // 测试每个候选函数
        for (final candidate in obfuscatedCandidates) {
          try {
            print('🧪 [LocalJsSource] 测试混淆函数: $candidate');

            // 简单测试调用（排除 Promise/axios/原生 fetch 等）
            final testJs = """
              (function() {
                try {
                  if (String($candidate).toLowerCase() === 'axios') return 'skip';
                  var result = $candidate('qq', 'test', 1);
                  if (result && typeof result.then === 'function') {
                    return 'promise';
                  }
                  if (result && (Array.isArray(result) || (typeof result === 'object' && typeof result.length === 'number'))) {
                    return 'valid';
                  }
                  return 'invalid';
                } catch(e) {
                  return 'error';
                }
              })()
            """;

            final testResult = _rt.evaluate(testJs);
            if (testResult.stringResult == 'valid') {
              print('✅ [LocalJsSource] 找到可用的混淆函数: $candidate');
              workingFunction = candidate.toString();

              // 使用找到的混淆函数进行搜索
              final searchJs =
                  "(function(){ " +
                  "try { " +
                  "var plats=" +
                  jsonEncode(platforms) +
                  ";" +
                  "function norm(x){ " +
                  "try{ " +
                  "if(Array.isArray(x)) return x; " +
                  "if(x && Array.isArray(x.data)) return x.data; " +
                  "if(x && Array.isArray(x.list)) return x.list; " +
                  "if(x && Array.isArray(x.songs)) return x.songs; " +
                  "if(x && Array.isArray(x.result)) return x.result; " +
                  "if(typeof x === 'object' && x !== null) { " +
                  "var keys = Object.keys(x); " +
                  "for(var j=0; j<keys.length; j++) { " +
                  "if(Array.isArray(x[keys[j]])) return x[keys[j]]; " +
                  "} " +
                  "} " +
                  "}catch(e){console.warn && console.warn('obf norm error:', e);} " +
                  "return []; " +
                  "} " +
                  "for(var i=0;i<plats.length;i++){ " +
                  "try { " +
                  "var p=plats[i]; " +
                  "console.log && console.log('[LocalJS Obf] 尝试平台:', p); " +
                  "var r=$workingFunction(p,'" +
                  escapedKw +
                  "'," +
                  page.toString() +
                  "); " +
                  "console.log && console.log('[LocalJS Obf] 平台结果:', p, r); " +
                  "var n=norm(r); " +
                  "if(n && n.length > 0) { " +
                  "console.log && console.log('[LocalJS Obf] 找到结果:', n.length, '条'); " +
                  "return JSON.stringify(n); " +
                  "} " +
                  "} catch(e) { " +
                  "console.warn && console.warn('[LocalJS Obf] 平台搜索失败:', p, e); " +
                  "continue; " +
                  "} " +
                  "} " +
                  "console.log && console.log('[LocalJS Obf] 所有平台都失败'); " +
                  "return '[]'; " +
                  "} catch(e) { " +
                  "console.error && console.error('[LocalJS Obf] 搜索代码执行失败:', e); " +
                  "return '[]'; " +
                  "} " +
                  "})()";

              final searchRes = _rt.evaluate(searchJs);
              result = searchRes.stringResult;
              print('📤 [LocalJsSource] 混淆函数搜索结果: $result');
              break;
            } else {
              // 跳过 skip/promise/invalid/error
            }
          } catch (e) {
            print('⚠️ [LocalJsSource] 测试函数 $candidate 失败: $e');
            continue;
          }
        }

        if (workingFunction == null) {
          print('❌ [LocalJsSource] 所有混淆函数都不可用');
          result = '[]';
        }
      } catch (e) {
        print('⚠️ [LocalJsSource] 混淆函数检测异常: $e');
        result = '[]';
      }
    }

    final text = result;
    try {
      final dynamic data = jsonDecode(text);
      if (data is List) {
        return data
            .where((e) => e is Map)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }
}
