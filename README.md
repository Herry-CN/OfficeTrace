# LeadTrace

LeadTrace 是基于本地微信数据库解密能力的 **群聊商机智能抓取** 桌面工具（Windows 优先）。

## 产品主次

1. **主目标**：从微信群聊抓取招聘 / 求购 / 资源 / 专家类商机，沉淀为可跟进待办  
2. **支撑能力**：聊天浏览、群分析、导出、年度报告（继承 EchoTrace 能力）  
3. **硬前置**：未配置密钥并完成解密（或实时 WCDB 连接）前，商机与聊天不可用

## 快速开始

```bash
cd D:\source\leadtrace
flutter pub get
flutter run -d windows
```

建议流程：

1. **设置** → 配置微信路径 / wxid / 解密密钥  
2. **数据管理** → 批量解密或连接实时数据库  
3. **设置** → 配置 Ollama（推荐）或 OpenAI，保存并测试 AI  
4. **商机中心** → 选择群聊 → 智能抓取 / 批量抓取  

## 文档

- [产品说明](docs/product.md)
- [商机流水线](docs/lead_pipeline.md)
- [新手指南（解密与数据）](docs/beginner_guide.md)
- [开发者架构](docs/development.md)
- [WCDB 实时接口](docs/wcdb_realtime.md)

## 技术栈

- Flutter（桌面 UI）+ Provider  
- Go FFI 解密 + WCDB 实时读库  
- Ollama / OpenAI（商机分类与提取）  

## 许可

MIT（继承上游开源组件许可）。请仅在合法授权的个人/企业数据上使用。
