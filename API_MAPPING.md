# API mapping

| Mobile feature | Endpoint |
|---|---|
| API health | `GET /api/health` |
| Dashboard | `GET /api/stats/dashboard` |
| Activity | `GET /api/stats/recent-activity` |
| Logs list | `GET /api/logs` |
| Log detail | `GET /api/logs/:id` |
| Log create/update/delete | `POST/PUT/DELETE /api/logs...` |
| ADIF import | `POST /api/logs/import` |
| ADIF export | `GET /api/logs/export/adif` |
| QSL search | `GET /api/qsl/search` |
| QSL detail | `GET /api/qsl/:qsl_id` |
| QSL generate | `POST /api/qsl/generate` |
| QSL scan | `POST /api/qsl/scan` |
| Address book | `GET/POST/DELETE /api/address...`（更新与网页端一致也使用 POST） |
| Config | `GET/PUT /api/config` |
| Callsigns | `GET /api/config/callsigns` |

The endpoint shapes follow the repository's `docs/API.md` contract.


## v0.1.7 移动端扩展

- 日志详情：`GET /api/logs/:id`
- 日志修改：`PUT /api/logs/:id`
- QSL 颁发：`POST /api/qsl/generate`，移动端支持 TC/RC，单条或多条日志，以及 single/multi 编号方式；服务端会自动进入打印队列。
- 卡片详情：`GET /api/qsl/:qsl_id`，返回关联日志。
- 卡片补打：`POST /api/print/queue`，移动端只显示“已加入服务器打印队列”，不展示队列页面。
- 最近活动：`GET /api/stats/recent-activity?limit=10`，移动端按网页端格式显示收/发、呼号、QSL ID、日期、模式和状态。


## v0.1.9
- QSL 卡片搜索仍使用 `GET /api/qsl/search?prefix=...`，移动端取消状态筛选按钮。
- 新增独立 QR 扫描 UI，仅用于读取 QSL 编号；扫描结果返回卡片管理页后自动写入搜索框并执行查询。
- 扫码页使用手动控制 `MobileScannerController` 生命周期，避免页面切换或应用切后台时重复启动相机。


## v0.2.1
- 地址列表兼容网页端实际响应：`response.data` 直接为数组，同时兼容包装对象。
- 地址详情按网页端实际接口使用 `GET /api/address/callsign/:callsign`。
- 地址创建/更新按网页端实际接口统一使用 `POST /api/address`。
- 地址标签通过 `POST /api/print/queue` 推送，类型为 `address_label`；FROM 仅提交 `sender`，TO 仅提交 `receiver`，并附带方向元数据；移动端不显示打印队列。
- 地址标签打印前会避免地址字段与国家/地区字段重复显示，例如 `XXXXF07` + `F07` 会规范为地址 `XXXX` + 国家 `F07`。
