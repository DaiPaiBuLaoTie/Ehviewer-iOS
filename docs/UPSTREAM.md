# 来源与版本

本项目名为 EhViewer SXJ iOS，是独立的 iOS 适配工程，不是 Android 上游的官方 iOS 发布。

- Android 功能参照：xiaojieonly/Ehviewer_CN_SXJ，分支 BiLi_PC_Gamer，固定提交 b44aafcdb1fe0270da2d3f45924d6de4b37b2cc4。
- 原生 Swift 基础：EhPanda-Team/EhPanda，develop 分支，固定提交 7a9051140db336c4a3ce0b883f005bacd8ce958f。
- 基础项目使用 MIT 许可；根目录 LICENSE 保留原文和作者署名。保留 Swift 文件的既有版权声明和原作者鸣谢。
- Android 根 LICENSE 含混合许可文字；本工程不将其 Android 源码整包复制进 iOS target。引用其实现进行后续代码移植时，按具体文件核对许可并保留声明。
- 独立主应用 Bundle ID：org.ehviewer.sxj.ios；分享扩展：org.ehviewer.sxj.ios.shareExtension。
- Xcode target / scheme 继续使用 EhPanda，以保留上游完整工程、测试计划及包引用；手机桌面显示 EhViewer SXJ。
- 当前适配对象：iPhone 17 Pro Max，iOS 27.0。最低运行版本 iOS 26.0。

新增适配包含原生本地收藏、本地标题/上传者/标签/命名空间屏蔽、JSON 备份恢复、图片目录离线导入、网络配置、站点工具入口、网页登录 Cookie 同步修复和无证书的 IPA 构建校验。

功能存在于源码、编译成功、模拟器测试通过、真机行为通过是不同的验收层级。请以 FEATURE-PARITY.md 和真实 Actions 结果为准，不把继承源代码等同于全部功能已验收。
