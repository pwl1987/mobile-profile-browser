# 威胁模型

## 保护资产

- Profile Cookie 与网站数据；
- 已保存的凭据与浏览器权限；
- SSH / 代理凭据；
- Profile 元数据；
- Device Profile 配置；
- Profile 与网络路由之间的关联关系。

## 主要威胁

1. Profile 之间发生 Cookie、Storage、权限或会话泄漏；
2. 受保护网络路由失效后静默回退到设备直连；
3. 凭据通过日志、备份、崩溃报告或调试接口泄漏；
4. 活动 Profile 注册表损坏；
5. 把浏览器可见配置误认为底层引擎特征已经改变；
6. 上游 Gecko / WebLibre 更新削弱隔离或安全边界；
7. DNS、IPv6、WebRTC 等旁路网络产生意外的直连；
8. 删除 Profile 后敏感数据仍残留在未定义的缓存或临时目录中。

## 安全要求

- Secret 使用 Android Keystore 保护；
- Profile 存储边界必须显式定义并通过测试；
- 防泄漏模式下受保护网络路由必须 Fail Closed；
- Release 构建关闭或严格脱敏调试日志；
- 上游和依赖升级必须经过审计；
- Device Profile 字段必须明确能力状态：`controlled`、`derived`、`observed` 或 `unsupported`；
- 网络健康检查不得泄漏 SSH 私钥、代理认证信息、Cookie 等敏感数据；
- Profile 删除必须有可验证的清理结果。

## 不属于本项目的承诺

本项目不承诺匿名性，不承诺绕过任何网站的风险控制或检测系统，也不声称某个“指纹配置”能够永久隐藏设备身份。

项目目标是：**可验证的 Profile 隔离、明确的网络路径、可解释的设备配置以及可靠的隐私保护。**
