# EhViewer SXJ iOS

为 iPhone 使用场景适配的原生 Swift 客户端，以 EhPanda 的原生实现为基础，对照 Ehviewer_CN_SXJ 的 Android 功能继续适配。输出未签名 IPA，由使用者自行签名安装。

**本项目尚未宣称与原 APK 全功能等价。** 已包含的模块、平台差异和待补齐项记录在 [功能对照](docs/FEATURE-PARITY.md)。构建成功也不能代替 iPhone 真机验收。

## 构建 IPA

1. 打开本仓库的 **Actions**。
2. 选择 **Build unsigned iOS IPA**。
3. 点击 **Run workflow**，分支选 main。
4. 等待所有步骤通过，在该次运行底部 **Artifacts** 下载 EhViewer-SXJ-iOS-unsigned。
5. 解压 Artifact ZIP，得到 EhViewer-SXJ-iOS-unsigned.ipa、SHA-256 文件和 build-info.json。
6. 核对哈希后使用自己的签名工具签名安装。

推送 main 或 v 开头的标签也会触发构建。无需 Apple Developer 证书、描述文件或签名 Secrets。Artifacts 保存 14 天，过期后可以重新运行。

- 构建环境：GitHub macos-26，Xcode 26.6，Swift 6.3.1。
- 目标：真机 arm64，iOS 26.0 及以上；包含分享扩展。
- 工作流先跑完整模拟器测试计划、安装并验证模拟器应用启动，再 archive 和打包。测试失败不会输出“成功”的 IPA。
- 输出校验会拒绝模拟器包、残留签名、描述文件、扩展 ID 不匹配和不可执行的主程序。
- 构建日志、测试摘要及 xcresult 保存在独立 diagnostics Artifact，保存 7 天。

## 使用入口

- 首页：最新、热门、排行、订阅更新和历史。
- 搜索：高级筛选、标签搜索、快速搜索和图片搜索。
- 详情：标签、评分、评论、预览、归档、种子和下载。
- 下载：队列、暂停/恢复、失败重试、文件夹和离线阅读。
- 设置：登录、站点、外观、阅读、下载与隐私。
- 设置右上角 **扩展工具**：本地收藏、本地屏蔽、图片目录导入、Android 数据库迁移、备份恢复、Hosts/加密 DNS/代理以及站点标签订阅管理等页面。
- 阅读设置：屏幕常亮、独立亮度、黑白背景、页码/时间/电量显示。
- 长按画廊：本地收藏、屏蔽上传者或标题。

登录使用网页或 Cookie；所有请求直接从手机访问站点。构建过程不需要也不包含用户的站点账号。账号权限与站点网络可达性仍由站点和手机网络决定。

## Android 数据迁移

原版导出的 SQLite .db 可在扩展工具的 Android 数据库迁移中先预览再合并。当前支持本地收藏、历史、阅读书签、屏蔽规则、快速搜索名称和关键词；高级搜索的独立筛选参数尚未映射。数据库本身没有图片，下载任务不能当成已经下载的内容。

将原下载目录通过“文件”或隔空投送复制到 iPhone，再使用本地画廊导入。包含有效 .ehviewer v1/v2 元数据的目录会保留画廊身份和原始数字页码，缺页会保留为空缺，重复身份跳过；普通图片目录生成独立的本地画廊。原始文件不修改。

## 本地开发

在装有 Xcode 26.6 的 Mac 上打开 EhPanda.xcodeproj，scheme 选 EhPanda。源码逻辑位于 AppPackage/Sources，薄入口位于 App，分享扩展位于 ShareExtension。

无需签名的归档命令：

~~~bash
bash Scripts/build-unsigned.sh
~~~

本地不依赖 Xcode 的检查：

~~~bash
python3 Scripts/verify-source.py
python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
~~~

来源、固定版本、许可和名称关系详见 [UPSTREAM.md](docs/UPSTREAM.md)。完整真机验收步骤见 [DEVICE-ACCEPTANCE.md](docs/DEVICE-ACCEPTANCE.md)。
