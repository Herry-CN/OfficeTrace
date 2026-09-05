# 群聊商机抓取流水线

实现位于 `lib/services/lead/`，逻辑移植自 fantastic-funicular 的 `TodoService.generateFromChat` + `AIService`。

## 流程

1. **取消息**：从 `DatabaseService` 读取目标群，按设置中的分析时窗（默认 24h）过滤文本消息  
2. **规范化**：转为 `[时间] [发送者]: 内容` 行，并做规则信号打分  
3. **分段**：时间间隙约 45 分钟、约 2200 字、最多 25 条、标签切换时可切段  
4. **分类**：规则分 + AI `classifyBusinessSegment`（recruitment / procurement / resource / expert / irrelevant）  
5. **提取**：相关段调用 `extractBusinessLeads`，并与规则兜底结果合并  
6. **滚动摘要**：相邻段保留上一两句摘要，减轻上下文割裂  
7. **过滤去重**：置信度阈值（默认 0.75）→ 同群同发送者时间 / 同标题 / 描述 Jaccard 去重  
8. **落库**：写入文档目录 `LeadTrace/leads.json`

## 关键类

| 类 | 职责 |
|----|------|
| `AiClientService` | Ollama/OpenAI、JSON 解析、分类/提取 prompt |
| `LeadPipelineService` | 分段、规则、合并、去重协调 |
| `LeadStore` | CRUD 与持久化 |
| `Lead` | 商机模型 |

## AI 配置

设置页「商机 AI 配置」：

- provider：`auto` / `ollama` / `openai`  
- Ollama Base URL（默认 `http://localhost:11434`）  
- OpenAI API Key（可选）  
- 模型名、置信度阈值、分析时窗  

## 后续可选增强

- 图片 OCR / 链接卡片商机  
- embedding 语义去重  
- CRM 导出
