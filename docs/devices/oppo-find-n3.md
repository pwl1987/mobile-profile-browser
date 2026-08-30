# OPPO Find N3 设备基线

## 目标设备

本项目 V0.x 的首个真实设备目标为 **OPPO Find N3**。

中国大陆版本官方入网型号为 `PHN110`。官方规格确认：内屏 7.82 英寸、2440×2268；外屏 6.31 英寸、2484×1116；两块屏幕均支持最高 120Hz，最高 240Hz 触控采样。设备采用第二代骁龙 8 移动平台、8 核 CPU；中国大陆官方规格页列出的系统为 ColorOS 13.2。citeturn753245search0

国际版本的硬件标识为 `CPH2499`，GPU 为 Adreno 740，主频页面列为 680MHz；不同地区的型号、频段和系统版本可能不同，因此浏览器不能把国际版与中国大陆版混成一个不可变身份。citeturn753245search1

## 为什么折叠屏必须单独建模

Find N3 不是普通单屏 Android 设备。浏览器可见的窗口尺寸、viewport、方向和布局会随着折叠/展开状态改变。

因此 DeviceProfile 不采用：

```text
DeviceProfile
└── 一个固定 screenWidth / screenHeight
```

而采用：

```text
DeviceProfile
├── deviceModel
├── platformProfile
└── displayStates
    ├── cover
    │   ├── resolution
    │   ├── viewport
    │   ├── dpr
    │   └── posture
    └── main
        ├── resolution
        ├── viewport
        ├── dpr
        └── posture
```

## V0.1 建模原则

### 真实硬件字段

以下信息可以作为设备能力基线，但不等于浏览器 JavaScript 一定能直接看到：

- `model`: OPPO Find N3
- `regional_model`: `PHN110` 或 `CPH2499`
- CPU: Snapdragon 8 Gen 2 / 8 cores
- RAM: 具体容量以真机为准
- main display: 2440×2268
- cover display: 2484×1116
- main PPI: 426
- cover PPI: 431
- touch sampling: up to 240Hz
- Android / ColorOS version: 以真机观测值为准

### 不应该硬编码

以下项目不能仅根据宣传参数直接写入浏览器指纹：

- 实际 CSS viewport
- `devicePixelRatio`
- `navigator.userAgent`
- Client Hints
- WebGL vendor/renderer
- `hardwareConcurrency`
- `deviceMemory`
- 字体集合
- WebRTC 行为
- 系统语言
- 时区

这些值必须区分 `controlled`、`derived`、`observed` 和 `unsupported`。

## 折叠姿态

V0.1 至少定义：

```text
CLOSED / FOLDED
OPEN / UNFOLDED
TRANSITIONING
```

浏览器运行时不允许在 `TRANSITIONING` 状态下生成新的 DeviceProfile 身份快照；应继续使用上一稳定状态，待系统报告稳定姿态后再更新显示环境。

## 真机采集

安装到用户自己的 Find N3 后，第一步不是“伪装”，而是建立观测基线：

1. Android 系统版本；
2. ColorOS 版本；
3. Build fingerprint；
4. 设备型号与区域型号；
5. 展开状态下实际 display metrics；
6. 折叠状态下实际 display metrics；
7. 实际 density / DPR 相关信息；
8. GeckoView 实际暴露的浏览器能力；
9. WebGL / Canvas / Audio / Font 等能力的观测结果。

真实观测数据用于建立 `ObservedDeviceProfile`，而不是直接当作可伪装字段。

## 验收要求

V0.1 在 Find N3 上至少验证：

- 折叠与展开都能正常浏览；
- 旋转/姿态变化不会导致 Profile 数据错乱；
- Profile 切换不会串 Cookie；
- Profile 切换不会错误继承上一 Profile 的 display state；
- 浏览器显示尺寸与 Android 当前窗口状态一致；
- 网络出口与 Profile 绑定关系保持不变。

## M3 真机验收矩阵

执行 runbook 与结果记录：`tools/device/README.md`（M3 Gate 收口条件）。

| 场景 | 必须测试 | 说明 |
| --- | --- | --- |
| 外屏启动 | ✅ | 折叠态冷启动 |
| 内屏启动 | ✅ | 展开态冷启动 |
| 展开 | ✅ | 运行中形态切换 |
| 折叠 | ✅ | 运行中形态切换 |
| 屏幕切换 | ✅ | 内外屏往复 |
| Activity 重建 | ✅ | "不保留活动" + 切回 |
| 后台恢复 | ✅ | Home → 回前台 |
| 横竖屏 | ✅ | 旋转 |
| 分屏 | 后续 | — |
| 键盘弹出 | 后续 | — |

### 实现红线：不得缓存屏幕度量

错误做法：缓存 `MediaQuery.of(context).size.width` 等值后复用——折叠/
展开/旋转后尺寸即变化，缓存值必然过期。正确做法：每次渲染经
WindowMetrics（`MediaQuery`/`WidgetsBindingObserver`）重新获取；涉及
viewport 的判断在 build 内完成，不在状态里持久化度量值。
