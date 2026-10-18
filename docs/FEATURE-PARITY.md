# Android 功能对照与验收状态

参照提交：b44aafcdb1fe0270da2d3f45924d6de4b37b2cc4。iOS 原生基础提交：7a9051140db336c4a3ce0b883f005bacd8ce958f。

目标是原 APK 的完整使用能力，而不是只做网页外壳。下表的“原生”表示已有相应实现，“网页”表示经当前账号 Cookie 打开完整站点功能；都不代表真机已验收。未列明的细项也不能自动视为完成。

| 原版功能 | 当前 iOS 实现 | 代码入口或差异 |
|---|---|---|
| E-Hentai / ExHentai 切换 | 原生 | AccountSetting、GalleryHost |
| 用户名密码登录 | 原生 | LoginFeature 的 LoginReducer |
| Cookie 登录、编辑 Cookie | 原生 | CookieClient、AccountSetting |
| 网页登录、验证后同步 | 原生 | WebView；独立会话与当前原生 Cookie 同步 |
| 注销 | 原生 | AccountSetting；新网页不沿用旧 WebKit 会话 |
| 最新画廊、分页 | 原生 | HomeFeature/Frontpage |
| 热门 | 原生 | HomeFeature/Popular |
| 排行榜、分榜 | 原生 | HomeFeature/Toplists |
| 订阅更新列表 | 原生 | HomeFeature/Watched |
| 标签订阅、删除订阅、标签权重/屏蔽管理 | 网页 | 扩展工具 → 标签订阅与屏蔽，站点 mytags |
| 新闻 | 网页 | 扩展工具 → 站点新闻 |
| 站点设置、配置档 | 原生与网页 | EhSetting；扩展工具 uconfig.php |
| 用户信息、积分、配额 | 原生与网页 | AccountSetting；扩展工具 home.php |
| 关键字与标签搜索 | 原生 | SearchFeature |
| 搜索历史 | 原生 | historyKeywords |
| 高级分类、评分、页数等筛选 | 原生 | FiltersFeature |
| 日期定位 | 原生 | DateSeekFeature |
| 图片搜索 | 原生 | SearchFeature |
| 快速搜索、排序、编辑 | 原生 | QuickSearchFeature |
| 多标签搜索 | 原生 | 搜索语法、TagSuggestion |
| 标签中文翻译、自定义词库 | 原生 | TagTranslationFeature、FileClient |
| 日文标题、列表/缩略图显示 | 原生 | AppearanceSetting |
| 详情、画廊信息、标签 | 原生 | DetailFeature |
| 预览、缩略图分页 | 原生 | DetailFeature/Previews |
| 评论查看、发送、编辑与投票 | 原生 | DetailFeature/Comments、PostComment |
| 画廊评分 | 原生 | DetailFeature/Rating |
| 标签投票 | 原生 | DetailFeature |
| 云收藏、收藏分类、搜索和排序 | 原生 | FavoritesFeature |
| 本地收藏 | 新增原生 | 长按画廊 / 扩展工具 → 本地收藏 |
| 本地标题屏蔽 | 新增原生 | SXJBlockRule，包含匹配 |
| 上传者黑名单 | 新增原生 | SXJBlockRule，完整匹配 |
| 标签/命名空间屏蔽 | 新增原生 | SXJBlockRule；列表全被过滤时仍可翻页 |
| 浏览历史、阅读进度 | 原生 | GalleryHistoryEntry |
| 竖向、左翻、右翻 | 原生 | ReadingFeature |
| 缩放、双击、横屏、双页 | 原生 | ReadingFeature、ReadingSettingFeature |
| 自动翻页、跳页、预加载 | 原生 | ReadingFeature |
| 静态、GIF、WebP 等图片 | 原生 | ImageClient、AnimatedImageFeature |
| 原图保存、分享、复制链接 | 原生 | ReadingFeature、DetailFeature |
| 种子列表/种子链接 | 原生 | DetailFeature/Torrents；下载后由兼容客户端处理 |
| 在线归档请求/归档链接 | 原生 | DetailFeature/Archives；需要站点权限 |
| 下载队列、暂停/恢复 | 原生 | DownloadClient、DownloadsFeature |
| 失败重试、单页修复、校验 | 原生 | DownloadInspector、DownloadStore |
| 下载文件夹、移动、排序和搜索 | 原生 | DownloadsFeature |
| 下载页分类及标签搜索细项 | 待逐项对齐 | 已有本地搜索，不将全部 Android 搜索选项算作已实现 |
| 下载并发、蜂窝网络限制 | 原生 | DownloadSetting |
| 离线阅读 | 原生 | 本地 manifest 与图片，不依赖在线页列表 |
| 重新扫描/恢复已下载目录 | 原生 | DownloadStore.reconcileDownloads / refreshDownloads |
| 读取时捕获缓存到下载库 | 原生 | captureCachedPage；与 Android 的“自动整本同步下载”需分项验收 |
| 图片目录/相册整理后导入 | 新增原生 | 扩展工具 → 本地画廊导入；从“文件”选择目录 |
| 直接导入 ZIP/7z/RAR | 尚未实现 | 当前必须先解压后选择图片目录 |
| Android 数据库备份直接导入 | 尚未实现 | 当前支持本工程 JSON 备份，格式不兼容 Android SQLite |
| Android Wi-Fi 二进制迁移协议互通 | 尚未实现 | 可先通过系统“文件”/隔空投送迁移目录，不宣称原协议兼容 |
| 设置/历史/快速搜索/本地收藏备份恢复 | 新增原生 | SXJBackup；校验后确认恢复，凭据不导出 |
| 清理图片缓存、日志查看 | 原生 | GeneralSetting、AppActivityLogs |
| 崩溃日志与 Android logcat | 平台适配 | 使用 iOS 系统日志与应用日志；没有 Android logcat |
| 内置 Hosts、SNI 直连 | 原生 | DomainResolver、DFClient |
| 自定义 Hosts | 新增原生 | SXJNetworkSettings；用于 SNI 直连模式 |
| DNS over HTTPS | 新增原生 | Network.framework PrivacyContext；系统策略优先 |
| HTTP/HTTPS CONNECT / SOCKS5 代理 | 新增原生 | SXJNetworkSettings；目前不支持代理账号密码 |
| 深色/浅色、主题、列表外观 | 原生 | AppearanceSetting |
| 简繁中/日/英等语言 | 原生 | 上游多语言资源；新增扩展工具当前以简体中文为主 |
| 屏幕保持、亮度/阅读显示细项 | 待逐项验收 | 使用 iOS 阅读器行为，尚未逐个复制 Android 的所有设置开关 |
| 音量键翻页 | 平台差异 | 不使用私有 API 拦截系统音量键；原生触屏/手势翻页 |
| 常驻后台服务 | 平台差异 | 后台 URLSession + 系统 BGProcessing，调度由 iOS 决定 |
| 任意存储目录/Android 媒体扫描 | 平台适配 | 沙盒 Downloads、系统“文件”、security-scoped 导入 |
| 图案锁、隐私保护 | 平台适配 | Face ID/系统认证、超时锁定、后台模糊；不复制 Android 图案锁界面 |
| 阻止系统截图 | 平台差异 | 后台隐私模糊，不能等同 Android FLAG_SECURE 的截图阻止 |
| Android 厂商后台优化/S Pen | 平台不适用 | iPhone 没有对应系统服务或硬件 |
| 应用升级 | 平台适配 | Actions 重新构建 IPA，使用者自行签名覆盖安装 |

## 未完成清单

在直接压缩包导入、Android SQLite 迁移、Wi-Fi 协议互通、原版下载检索细项、阅读设置开关等差异闭环之前，本工程不能标注为“原 APK 全功能移植完成”。站点网页登录、防机器人验证、用户权限、真实下载和锁屏/后台行为必须由真实账号与 iPhone 验收。

本地脚本校验不等于 Swift 编译。最新的 Actions 运行、产物 SHA-256 和 DEVICE-ACCEPTANCE.md 中的实测记录共同构成验收证据。
