# MosDNS 自定义配置文件

本目录包含 MosDNS 的自定义配置文件示例。如果您需要使用自定义配置，请参考以下说明。

## 文件说明

*   `config_custom.yaml`: MosDNS 的主配置文件（自定义部分）。
*   `dat_exec.yaml`: 数据处理和执行相关的配置。
*   `dns.yaml`: DNS 服务器相关的配置。

## 使用方法

1.  **上传文件**：
    - 将本目录下的所有 `.yaml` 文件或者在[Releases](https://github.com/MayflyDestiny/luci-app-mosdns-panel/releases) 页面下载，文件名为 `mosdns_custom_config_*.zip`的文件并解压出来。
    - 上传到 OpenWrt 路由器的 `/etc/mosdns/` 目录中。
    > 可以使用 SCP、SFTP 或其他文件传输工具。

2.  **设置GeoData导出**：
    - 进入 MosDNS 设置界面 -> **基本设置** -> **GeoData导出**
    然后依次添加如下的导出标签：
    - **GeoSite标签**：cn、gfw、private、geolocation-!cn、category-ads-all
    - **GeoIP标签**：cn、private
    ![GeoData导出设置](../img/GeoData.png)

3.  **设置自定义配置**：
    - 上传完成并设置完成GeoData导出后，进入 MosDNS 设置界面 -> **基本设置** -> **基本选项** -> **配置文件** -> 勾选 **自定义配置**。
    此时编辑器中应该会出现上传的`config_custom.yaml`文件中的内容，如果没有出现可以通过手动复制的方式添加。
    ![自定义配置设置](../img/Config_Custom.png)
4. **启动Mosdns**
    - 所有配置确认没有问题之后点击下方的“保存并应用”按钮启动Mosdns服务。
    - 启动完成后可以在 MosDNS “面板”选项卡中查看服务状态。
## 注意事项

*   请确保配置文件的语法正确，否则 MosDNS 可能无法启动。
*   如果不确定yaml文件哪里有问题可以通过`mosdns start -c /etc/mosdns/*.yaml`命令确认yaml文件是否配置正确。如果配置错误终端中会有具体的错误提示，根据提示修改即可。
