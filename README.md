# Luci App MosDNS Panel

Luci App MosDNS Panel 是一个为 OpenWrt/LuCI 设计的 MosDNS 可视化管理面板。它提供了一个现代化的、响应式的 Web 界面，用于监控 MosDNS 的运行状态、管理缓存、查看统计图表以及执行常见的维护操作。

### 亮色主题 (Light)
![MosDNS Panel Light Theme](img/Light.png)

### 暗色主题 (Dark)
![MosDNS Panel Dark Theme](img/Dark.png)

## 🚪 访问入口

安装成功后，您可以在 LuCI 菜单中找到入口：

1.  进入 OpenWrt 后台。
2.  导航至 **服务 (Services)** -> **MosDNS**。
3.  点击 **面板 (Panel)** 选项卡（通常位于“日志”选项卡的右侧）。

<div align="center">
  <img src="img/Panel.png" width="300" alt="Panel Entry Screenshot">
</div>

## ✨ 主要特性

*   **仪表盘概览**：实时显示 DNS 查询的命中率、缓存使用情况和延迟统计。
*   **可视化图表**：
    *   使用环形图（Doughnut Chart）直观展示各类型缓存（国内、国外、全部）的命中与未命中比例。
    *   支持动态交互，悬停查看详细数值（支持K/M/B 自动单位换算）。
*   **缓存管理**：
    *   **一键清理**：支持分别清理内存中国内、国外或乐观缓存中的域名。
    *   **缓存恢复**：支持将 `/etc/mosdns/*.dump` 文件中的域名加载到内存中。
    *   **乐观缓存**：支持 Lazy Cache (乐观缓存) 的统计与管理。
*   **实时控制**：支持一键重启 MosDNS 服务，以及刷新面板数据。
*   **自动刷新**：内置自动刷新机制，实时更新统计数据。
*   **多主题支持**：自动适配亮色（Light）和暗色（Dark）模式，同时也支持跟随系统设置。
*   **嵌入式优化**：针对 OpenWrt LuCI 的嵌入式环境进行了专门优化，支持 iframe 自适应高度。

## 🛠️ 安装与编译

### 依赖
本插件依赖于以下组件：
*   `luci-app-mosdns` (基础 MosDNS 插件)
*   `luci-base`
*   `curl`

### 编译方法

1.  将本仓库克隆到 OpenWrt SDK 或源码的 `package/` 目录下：
    ```bash
    git clone https://github.com/your-username/luci-app-mosdns-panel.git package/luci-app-mosdns-panel
    ```
2.  更新 feeds 并安装：
    ```bash
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    ```
3.  在 `make menuconfig` 中选择：
    *   `LuCI` -> `Applications` -> `luci-app-mosdns-panel`
4.  编译：
    ```bash
    make package/luci-app-mosdns-panel/compile V=s
    ```

### 直接安装 (IPK)
您可以直接下载 [Releases](https://github.com/MayflyDestiny/luci-app-mosdns-panel/releases) 页面提供的 `.ipk` 文件并安装：

```bash
opkg install luci-app-mosdns-panel_*.ipk
```

## ⚙️ 配置说明

本插件主要作为 MosDNS 的前端面板，依赖 MosDNS 的 API 接口。

*   **API 地址**：默认连接 `http://127.0.0.1:9091`。请确保您的 MosDNS 配置文件中开启了 API 并监听该端口。
*   **缓存恢复路径**：在执行“恢复缓存”操作时，默认会尝试从 `/etc/mosdns/` 目录加载对应的 `.dump` 文件。如果使用了自定义配置，请确保 `config_custom.yaml` 中的 `dump_file` 路径设置正确。
*   **缓存数据统计说明**：
    *   **全部缓存/国内/国外缓存**：如果您希望面板能精确区分并显示国内（`cache_cn`）和国外（`cache_google`）的缓存统计数据，需要使用 MosDNS 的 **自定义配置**。
        1.  进入 MosDNS 设置界面 -> **基本设置** -> **基本选项** -> **配置文件**。
        2.  勾选 **自定义配置**。
        3.  您需要手动配置 `cache_cn` 和 `cache_google` 两个缓存插件，并正确配置其分流规则。
        4.  如果您不熟悉如何配置，可以参考 [MosDNS Wiki](https://irine-sistiana.gitbook.io/mosdns-wiki) 学习，或者直接使用本项目提供的 **预设配置文件**。
        5.  预设配置文件（包含 `cache_cn`, `cache_google` 配置）可以在 [Releases](https://github.com/MayflyDestiny/luci-app-mosdns-panel/releases) 页面下载，文件名为 `mosdns_custom_config_*.zip`。下载后解压并上传至路由器的 `/etc/mosdns/` 目录即可。
    *   **乐观缓存 (Lazy Cache)**：如果您使用 MosDNS 的 **内置配置**（非自定义），面板将主要展示“乐观缓存”的数据。由于乐观缓存通常配置在处理流程的最前端，它能捕获并统计绝大部分的 DNS 请求数据。如果您对国内/国外分流统计没有强需求，直接使用内置配置也是完全可行的。

## 🤝 致谢与参考

本项目在开发过程中参考了以下优秀的开源项目，特此感谢：

*   **UI 设计参考**：[MosDNSUI](https://github.com/wzgwangzhengang/MosDNSUI) by @wzgwangzhengang
    *   参考了其现代化的界面布局和交互设计理念。
*   **配置逻辑参考**：[MosDNS-Config](https://github.com/moreoronce/MosDNS-Config) by @moreoronce
    *   参考了其 MosDNS 的配置结构和最佳实践。

## 📄 许可证

本项目遵循 [MIT License](LICENSE) 许可证。
