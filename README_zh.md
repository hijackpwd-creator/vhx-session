# NSURLSession rootless 测试 App

面向 iOS 15+ 的 rootless 越狱设备，包括 iPhone XS / iOS 16.2 / Dopamine。使用 arm64，目标为独立 App，不注入系统进程。

## GitHub 编译

1. 将本压缩包解压，把里面的文件放在 GitHub 仓库根目录。根目录应直接出现 main.m、build.sh、packaging 和 .github，不要额外嵌套 vhx-session-app 目录。务必上传隐藏目录 .github。
2. Actions → Build NSURLSession Test App → Run workflow。
3. 成功后下载 Artifacts 中的 vhx-session-test-rootless。
4. 解压得到 vhx-session-test_1.0.0_iphoneos-arm64.deb。

建议使用单独仓库；若复用旧命令行仓库，请使用本包的根目录结构。旧 workflow 不需要运行。

## 安装

通过 Filza 打开 deb，选择 Sileo 安装；或将 deb 上传到 /var/mobile，在已有 root 终端执行：

```bash
/var/jb/usr/bin/dpkg -i /var/mobile/vhx-session-test_1.0.0_iphoneos-arm64.deb
```

安装脚本会在 uicache 存在时注册桌面 App。若图标未出现，执行：

```bash
/var/jb/usr/bin/uicache -p /var/jb/Applications/VHXSessionTest.app
```

桌面打开 VHX Session Test。输入服务器基础地址，例如 https://example.com（不含末尾斜杠），超时 5，期望状态码 200，点击 Run NSURLSession Test。

## 实现和结果

- NSURLSession.sharedSession + NSMutableURLRequest，GET，直接追加 /vhx，timeoutInterval 使用输入值。
- 在后台工作线程创建和启动 task，等待信号量 timeout + 2 秒。界面主线程不被等待阻塞。
- 回调保存响应和错误并通知信号量；超时后取消，不读取可能仍被回调写入的变量。
- 输出实际 NSURLSession NSError 的 domain/code/description/userInfo、最终 URL、HTTP 状态、响应字节数、响应头、正文预览和耗时。
- 成功条件：无错误、状态码匹配、非空且有效 UTF-8 正文去除首尾空白后不区分大小写等于 ok。
- 判定使用完整正文，界面正文预览限制为 8192 个 UTF-16 单元。
- 原 stru_B8.segname 常量未知，200 只是可修改的默认值。原 _sharedSession 配置未知，因此不能保证配置与原程序完全相同。
- 对无效 UTF-8 增加了 nil 检查；原反编译逻辑可能因向 nil 消息返回 0 而误判为成功，本程序对此返回 false。

## 网络配置

此测试 App 在 Info.plist 中设置 NSAllowsArbitraryLoads，允许普通 HTTP 测试，避免 App 的 ATS 限制混入接口测试。HTTPS 仍使用系统默认证书校验，不绕过证书错误。配置与原 App 不一定相同。

对本地网络请求，iOS 可能显示本地网络权限提示，请允许测试访问。NSURLSession sharedSession 仍采用系统缓存、Cookie 和重定向行为。超时参数限制 (0,120] 秒。

## 验证范围与限制

源码和构建脚本在交付环境进行静态检查；没有 Apple SDK，没有运行 GitHub 构建或在真机启动。macOS GitHub runner 只能编译 iOS App，不能替代 Dopamine 真机验证。App 安装仍依赖越狱的签名和启动机制，不能保证解决之前命令行的 SIGKILL。

签名使用 SHA-256 ldid 自签名，不需要 Apple 开发者证书或 TrollStore。此 App 不请求私有特权。

点击测试后保持 App 在前台；切换到后台可能使请求暂停，影响计时。如果 App 无法打开，请提供对应安装和启动错误，不能据此判断 NSURLSession 的请求失败。
