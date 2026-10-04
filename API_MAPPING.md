# QSLMM API 映射

移动端直接使用 QSLCard-Manager REST API，不在客户端复制服务端业务规则。

## 核心接口

- `GET /api/health`：连接检查
- `GET /api/stats`：首页统计
- `GET /api/stats/recent-activity`：首页最近活动
- `GET /api/logs`：日志列表
- `GET /api/logs/:id`：日志详情
- `PUT /api/logs/:id`：编辑日志
- `POST /api/logs/import`：ADIF 上传
- `POST /api/qsl/generate`：QSL 编号颁发
- `GET /api/qsl/search`：QSL 编号搜索
- `GET /api/qsl/:id`：QSL 详情
- `POST /api/print/queue`：推送 QSL / 地址标签打印任务
- `GET/POST /api/address`：地址簿
- `GET /api/address/callsign/:callsign`：地址详情
- `DELETE /api/address/:callsign`：删除地址
- `POST /api/qsl/scan`：QSL 扫码处理

APP 不显示打印队列；打印任务仍由服务端管理。
