# Mobile Profile WebLibre 运行时包

WebLibre 运行时侧的纯 Dart 编排层：真实目录布局、Runtime 状态机、
进程绑定约束。真实 Gecko 绑定通过 `WebLibreGeckoBinder` 契约注入，
Android 实现随补丁流接入（M3 真机阶段）。

## 上游事实（b4721ae6）

- Profile 目录：`{filesDir}/weblibre_profiles/profile-<uuid>/`，元数据
  `metadata.json`（tmp+rename 原子写），Gecko 存储在 `files/mozilla/`。
- **Gecko runtime 与进程一次性绑定**（上游 core/filesystem.dart）：
  一个进程同时最多一个已绑定 Profile，切换必须先 stop 再 launch。

## 结构

```text
WebLibreProfilePaths        路径拼装与校验（无副作用）
WebLibreProfileStorage      目录存储契约 + DirectoryWebLibreProfileStorage（真实 FS）
WebLibreRuntimeController   created→starting→running→stopping→stopped / failed 状态机
WebLibreRuntimeManager      编排：存储创建 + Gecko 绑定 + 单绑定槽位
WebLibreGeckoBinder         进程绑定契约（真机实现点）
```

## 测试

```bash
dart pub get
dart analyze
dart test
```
