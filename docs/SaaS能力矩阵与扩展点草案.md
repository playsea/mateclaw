# SaaS 套餐能力矩阵与核心扩展点草案

> **状态**：产品要点已拍板（见 §0、§9）；接口仍为草案，**未实施代码**  
> **前提**：获客 = **公众号（只导流）+ 小程序 + Web**；默认 Token 额度 **每周 2000（运营可改）**；首期 **4** 个行业模板；B 支付预留 **微信+支付宝**。  
> **原则**：核心只加薄扩展点；业务落在独立 `mateclaw-saas`（或可开关模块）。私有化默认「全开 / 无套餐限制」。  
> **关联**：[技术设计说明](./技术设计说明.md)

---

## 0. 已拍板结论（2026-08-28）

| # | 议题 | 结论 |
|---|------|------|
| 1 | A 与 Wiki | **开放 Wiki 只读**（`view:wiki`）；禁止 `manage:wiki` |
| 2 | B 与 Agent | **允许自建 Agent**；成本靠 **可配置 Token 额度** 控制（非靠禁建 Agent） |
| 3 | 公众号职责 | **只获客**（菜单/推文跳小程序）；**不承接对话**；对话仅在 **小程序 / Web** |
| 4 | 邀请奖励 | **归因必做**；是否送 Token、送多少 = **运营可配置**（可按活动期调整，可关） |
| 5 | UnionId | 见 §4.5；未开通开放平台时也可上线，用「后绑定 / 手机号合并」兜底 |
| 6 | A/B 默认额度 | **默认 2000 / 周**（运营可改；**周期固定为自然周**） |
| 7 | 首期模板 | **4 个**：日常工作、电商运营、软件开发、隧道工程施工 |
| 8 | B 支付 | **微信 + 支付宝** 接口对接；商户参数后期配置 |
---

## 1. 概念分层（避免和现有 RBAC 打架）

| 层 | 现有 / 新增 | 回答的问题 |
|----|-------------|------------|
| **身份 Identity** | 现有 `User` + 新增绑定 | 你是谁（Web 密码 / 公众号 openid / 小程序 openid，可合并） |
| **租户 Tenant** | ≈ 用户的「主工作空间」或显式 tenant | 账单与套餐挂在谁身上 |
| **套餐 Plan** | **新增** Entitlement | 你买了什么（A/B/C） |
| **空间角色 Role** | 现有 viewer/member/admin/owner | 在该工作空间里能管什么 |
| **模块能力 Capability** | 现有 `chat` / `manage:*` … | UI 模块与粗粒度 API |

**最终鉴权（建议）：**

```
允许 = 已登录
     ∧ 空间成员角色具备 Capability（现有 RoleCapabilities）
     ∧ 租户套餐 Entitlement 允许该 Capability / 工具 / 配额（新增）
```

私有化 / C 类独立部署：Entitlement 提供者返回 `ALLOW_ALL`，行为与今天一致。

**C 类不与 A/B 共用多租户计量**：C = 签约私有化交付；公有云控制台最多记录「客户档案 / 交付状态」，能力在客户自己的 JAR 里全开。

---

## 2. 套餐定义（产品）

| 代号 | 名称 | 商业形态 | 典型用户 |
|------|------|----------|----------|
| **A** | 免费体验 | 获客；严控成本 | 个人试用、裂变导入 |
| **B** | 按量成长 | Token **周额度**；超额引导付费 | 个人/小团队日常用 |
| **C** | 深度定制 | 项目制私有化；连客户库与系统 | 企业客户 |

升级路径建议：`A → B（在线）`；`任意 → C（商务签约，另开交付）`。

---

## 3. 能力矩阵

图例：`✓` 开放 · `△` 受限开放 · `—` 关闭 · `★` 仅 C 私有化环境

### 3.1 模块能力（对齐现有 `Capability`）

| Capability（现有常量） | A 免费 | B 按量 | C 私有化 | 说明 |
|------------------------|--------|--------|----------|------|
| `chat` | ✓ | ✓ | ★ | 对话在小程序/Web；均受租户 Token 配额 |
| `view:wiki` | ✓ | ✓ | ★ | **A：只读**（模板/预置页可读） |
| `view:memory` | — | ✓ | ★ | 记忆运营面；A 关闭降低复杂度 |
| `view:dashboard` | △ | ✓ | ★ | A：仅本人用量/配额；B：完整 |
| `manage:wiki` | — | ✓ | ★ | A 禁止写入；B 可建库 |
| `manage:agents` | △ | ✓ | ★ | A：仅预置助手，禁自建/Teams；**B：允许自建**，靠额度控成本 |
| `manage:skills` | — | △ | ★ | B：安装市场技能；禁高级进化/Curator（可二期） |
| `manage:channels` | — | ✓ | ★ | 公有云获客渠道由平台配置；用户侧 A 不开放渠道台 |
| `manage:models` | — | △ | ★ | B：选用平台提供的模型档；禁自配任意 Key |
| `manage:security` | — | △ | ★ | B：只读审计；改 Guard 可放到 B+ |
| `manage:settings` | — | △ | ★ | B：成员/基础设置；MCP/插件/Workflow/Trigger 默认 — 或 B+ |

**前端路由**：在现有 `meta.requiredCapability` 之上，再拦一层 plan feature（或合并进 access API）。

### 3.2 运行时工具（Agent 可调用）

| 工具族（示意，以实际 `ToolRegistry` 名为准） | A | B | C | 备注 |
|-----------------------------------------------|----|----|---|------|
| 基础对话（无工具） | ✓ | ✓ | ★ | |
| `web_search` / 搜索链 | ✓ | ✓ | ★ | A 可另限周次数（可配） |
| 浏览器 `browser_*` | — | △ | ★ | B 可选；成本与 SSRF 风险高 |
| 文件读写 / shell / 代码执行 | — | △ | ★ | A 禁；B 沙箱+配额 |
| SQL / Datasource | — | — | ★ | 连客户库 → 仅 C |
| MCP / ACP 工具 | — | △ | ★ | B+ 或企业档 |
| 委派 / Team / 子 Agent | — | △ | ★ | A 禁；B 开放则 **Token 计入同一租户池** |
| 文档生成 docx/xlsx/pptx/pdf | — | ✓ | ★ | |
| 多模态（图/音/视频/3D） | — | △ | ★ | 按供应商成本单开配额 |
| 公众号发布 / 内容工作室重工具 | — | △ | ★ | 与「获客用公众号」权限隔离 |

### 3.3 平台功能面

| 功能 | A | B | C |
|------|----|----|---|
| Web 控制台登录 / 对话 | ✓ | ✓ | ★（客户环境） |
| 小程序注册 / 登录 / 对话 / 邀请 | ✓ | ✓ | —（公有云） |
| 公众号 | 仅获客跳转小程序 | 同左 | 按交付 |
| 公众号内智能对话 | — | — | —（公有云 v1 明确不做） |
| 自助选行业模板 | ✓（首期 4 个见 §3.5；A 引导选 1 次） | ✓（可换） | ★ 可定制模板包 |
| 多工作空间 | — | △（如 3 个） | ★ |
| 工作流 / 触发器 | — | △ | ★ |
| 插件安装 | — | — | ★ |
| 自有模型 Key / 私有 MCP | — | — | ★ |
| 邀请归因 | ✓ | ✓ | — |
| 邀请送 Token | 可配置开关 | 可配置 | — |

### 3.4 配额与计费（A/B）

| 项 | 默认（可被运营覆盖） | 超额行为 |
|----|----------------------|----------|
| **Token 额度** | **A/B 默认均为 2000 / 自然周**（completion+prompt 合计；周一 00:00 重置，时区可配，默认 `Asia/Shanghai`） | A：硬停 + 引导升级；B：提示续费/充值后停服 |
| Web Search 次数 | 与 Token 分开可配；未单独配置时 v1 可「不另限次数、只耗 Token」或给保守默认（如周 100） | 工具拒绝 + 文案 |
| 并发流式会话 | A=1；B=2～5（可配） | 429 |
| 模型档位 | A：平台廉价模型；B：可选更高档（可配） | — |
| 存储 | A：Wiki 只读为主；B：按档 | 禁超限上传 |

**运营修改方式（产品要求）：**

- 全局默认：`saas_plan_def` / 运营后台「套餐配置」改 A、B 的 `tokenQuota`（**周期固定 week**，只改额度数字）。
- 单租户覆盖：可为某用户临时调额（活动、客服补偿），记入 `saas_tenant.quota_override` 或调账流水；仍按**当前自然周**结算。
- **邀请奖励送的 Token**：叠加到**当前周**可用额度（或记入奖励余额由运营规则决定），不修改套餐档位本身。

**关于「2000」**：表示 **每周** 默认额度；偏紧/偏松只改配置。

**计量口径（v1）**：主对话 LLM usage；B 自建多 Agent / 子 Agent 若开放，**计入同一租户本周池**。

**B 控成本主手段**：额度熔断，而不是禁止建 Agent。

### 3.5 首期行业模板（已拍板 4 个）

| 模板 ID（建议） | 名称 | 定位（内容向，非技术引擎差异） |
|-----------------|------|--------------------------------|
| `daily_work` | 日常工作 | 通用办公助手、纪要/待办/邮件草稿等轻量技能 |
| `ecommerce` | 电商运营 | 选品/客服话术/内容种草等预置 Agent 与技能 |
| `software_dev` | 软件开发 | 代码助手、评审、文档类技能 |
| `tunnel_engineering` | 隧道工程施工 | 工程现场/资料/进度类场景种子（首期行业样板） |

模板包约定见 §5.5；首期只交付这 4 套，后续加行业不改核心。

### 3.6 B 支付渠道（已拍板方向）

| 项 | 结论 |
|----|------|
| 渠道 | **微信支付 + 支付宝** 均做接口对接 |
| 参数 | 商户号、证书、回调 URL 等 **后期配置**（环境变量 / 密文配置），代码不写死 |
| v1 策略 | 实现 `PaymentGateway` SPI + 两套 Adapter 与回调验签；未配齐参数时「支付未启用」，可用人工改 Plan / 调账兜底 |

```java
public interface PaymentGateway {
    String channel(); // wechat_pay | alipay
    CheckoutSession createCheckout(CheckoutRequest req);
    void handleNotify(Map<String, String> headers, byte[] body);
    boolean isConfigured();
}
```

---

## 4. 微信公众号 + 小程序获客方案（产品流）

### 4.1 角色分工（已拍板）

| 载体 | 职责 |
|------|------|
| **公众号** | 品牌、菜单「开始使用 / 邀请好友」、推文；**只跳小程序，不聊业务** |
| **小程序** | 注册 / 登录 / 选模板 / 配额 / 邀请海报 / **对话** |
| **Web** | 完整控制台 + 对话；与小程序同一 User、同一 Plan |

### 4.2 主路径

```
公众号关注 / 菜单 / 推文
    → 打开小程序（可带 scene=inviteCode）
        → wx.login → 注册或登录（Plan 默认 A）
        → 建主 Workspace；引导选行业模板（可跳过）
        → （可选）引导「关注公众号」便于运营通知
        → 在小程序或 Web 对话

好友被推荐
    → 小程序码 / 分享卡片（inviteCode）
        → 注册；写入 referral 归因
        → 若运营配置了奖励：按当时规则给邀请人（和/或新人）发放 Token 额度
```

### 4.3 身份同权

```
User (平台账号)
 ├── Credential: password（Web）
 ├── WechatMpOpenId（小程序）
 ├── WechatOaOpenId（公众号，用于关注态/通知，非对话）
 └── UnionId（若已绑定开放平台则优先用来自动合并）
```

权限只看 User / Tenant / Plan，不看登录入口。

### 4.4 邀请奖励（可运营配置）

| 配置项（示意） | 说明 |
|----------------|------|
| `referral.enabled` | 是否启用邀请 |
| `referral.reward.enabled` | 是否发放 Token（可关 = 仅归因） |
| `referral.reward.inviterTokens` | 邀请人到账额度 |
| `referral.reward.inviteeTokens` | 新人到账额度（可为 0） |
| `referral.reward.campaignId` | 活动期；换活动改数字，旧归因记录保留 |
| `referral.reward.capPerInviter` | 单人邀请奖励上限，防刷 |
| `referral.reward.capGlobalWeekly` | 全局本周发放上限 |

实现上：`ReferralService.bindOnRegister` 写归因后，调用 `RewardPolicy.current().grant(...)`；政策来自 DB/配置中心，**不写死在代码里**。

### 4.5 UnionId 是什么？（通俗说明）

微信里，**同一个用户在不同应用里的编号不一样**：

- 在你的**小程序**里叫一套 `openid`
- 在你的**公众号**里又是另一套 `openid`
- 在 **Web 微信扫码登录**（若做）又可能是另一套

如果这几个应用**没有**绑到同一个「微信开放平台」账号下，系统**无法自动知道**「小程序里的张三」和「公众号里的张三」是同一个人，容易变成两个平台账号。

**UnionId**：把小程序、公众号等挂到同一个**微信开放平台**主体后，微信会给「同一用户跨应用」发一个稳定的 `unionid`。有了它，三端（小程序 / 公众号 / 将来 Web 微信登录）可以自动合并成一个 MateClaw 用户。

| 情况 | 建议 |
|------|------|
| **已有开放平台，且公众号+小程序已绑定** | 登录优先用 `unionid` 合并，体验最好 |
| **还没有 / 暂时绑不上** | **照样可上线**：小程序注册为主账号；公众号只负责跳转（甚至先不存 oa openid）；用户在小程序里「绑定手机号 / 已有 Web 账号」做合并。等开放平台就绪再升级自动合并 |

**你需要做的运营动作（非开发）**：用公司主体在 [微信开放平台](https://open.weixin.qq.com/) 注册，把小程序 AppID、公众号 AppID 绑到同一开放平台账号下，并拿到相应权限。开发侧把 `unionid` 字段预留即可（表结构已含 `union_id`）。

**与现有 `channel.weixin`（iLink）**：仍解耦；公有云获客不依赖 iLink 对话。

---

## 5. 核心扩展点接口草案

> 包名示意：`vip.mate.saas.spi`（核心只定义 SPI；实现可在 `mateclaw-saas`）。  
> 私有化：提供 `Noop` / `AllowAll` 实现，或根本不装配 SaaS 自动配置。

### 5.1 套餐与鉴权

```java
/** 租户当前权益快照（可缓存；支付/升级后失效） */
public interface EntitlementSnapshot {
    String tenantId();
    String planCode();          // A | B | C | PRIVATE
    boolean allowAll();         // true → 跳过一切套餐限制（私有化）
    Set<String> features();     // 如 "chat", "tool:web_search", "module:manage:wiki"
    QuotaQuota quotas();        // 见下
}

public interface QuotaQuota {
    String period();            // 固定 "week"（自然周）
    String periodKey();         // e.g. "2026-W35"（ISO 周或运营约定）
    long weeklyTokenLimit();    // -1 = 不限；默认 2000
    long weeklyTokenUsed();
    long weeklySearchLimit();
    long weeklySearchUsed();
    int maxWorkspaces();
    String modelTierAllowed();
}

public interface EntitlementService {
    EntitlementSnapshot current(String tenantId);
    /** 模块能力：在 RoleCapabilities 通过后再问一次 */
    boolean allowsCapability(String tenantId, String capability);
    /** 工具名：构图时过滤 ToolRegistry */
    boolean allowsTool(String tenantId, String toolName);
    /** 流式开始前 / 每个 LLM chunk 后可调 */
    QuotaDecision checkAndConsumeTokens(String tenantId, int deltaTokens);
}

public enum QuotaDecisionKind { OK, SOFT_WARN, HARD_BLOCK }
public record QuotaDecision(QuotaDecisionKind kind, String messageCode, Map<String, Object> args) {}
```

**接入点（核心改动面，尽量少）：**

1. `GET /api/v1/workspaces/{id}/access`（或并行 `/api/v1/saas/entitlement`）— 返回 `capabilities ∩ planFeatures`。  
2. `AgentGraphBuilder` 组装工具后 — `filter(tool -> entitlement.allowsTool(...))`。  
3. `ChatController` / `AgentService` 流式入口 — `checkAndConsumeTokens`；`HARD_BLOCK` 时结束 SSE 并下发升级卡片事件。  
4. 前端路由 — 无 feature 则隐藏入口（与 403 双保险）。

### 5.2 注册与开户

```java
public record RegisterCommand(
    String channel,              // web | wechat_mp | wechat_oa
    String displayName,
    String passwordHashOrNull,   // web
    String wechatMpOpenIdOrNull,
    String wechatOaOpenIdOrNull,
    String unionIdOrNull,
    String inviteCodeOrNull,
    String clientIp
) {}

public record RegisterResult(
    String userId,
    String tenantId,
    String workspaceId,
    String planCode,
    boolean newUser,
    List<String> onboardingSteps   // e.g. SELECT_TEMPLATE, BIND_OA
) {}

public interface TenantProvisioningService {
    RegisterResult registerOrLogin(RegisterCommand cmd);
    /** 选行业模板：幂等应用到 workspace */
    void applyWorkspaceTemplate(String workspaceId, String templateId, String operatorUserId);
}
```

**事件（可选，便于插件监听）：**

```java
public record UserRegisteredEvent(String userId, String tenantId, String workspaceId,
                                  String channel, String inviteCodeOrNull) {}
public record PlanChangedEvent(String tenantId, String fromPlan, String toPlan, String reason) {}
public record QuotaExceededEvent(String tenantId, String quotaType, String planCode) {}
```

核心 `AuthService` **不写死** SaaS 逻辑：注册 API 可放在 `mateclaw-saas` Controller；若坚持走现有 `createUser`，则仅在其后 `ApplicationEventPublisher.publish(UserRegisteredEvent)`，由 SaaS 监听建空间（需保证事务边界清晰）。

### 5.3 邀请与归因 / 可配置奖励

```java
public interface ReferralService {
    String createInviteCode(String inviterUserId);
    /** 写归因；若当前活动开启奖励则调用 RewardPolicy（失败不影响注册成功） */
    ReferralBindResult bindOnRegister(String inviteCode, String inviteeUserId);
    InviteSharePayload miniProgramSharePayload(String inviterUserId);
}

public interface RewardPolicy {
    /** 运营后台或配置中心下发的当前活动；disabled 时只归因不发币 */
    RewardCampaign current();
    void grant(String inviterUserId, String inviteeUserId, RewardCampaign campaign);
}

public record RewardCampaign(
    String campaignId,
    boolean rewardEnabled,
    long inviterBonusTokens,
    long inviteeBonusTokens,
    long capPerInviter,
    long capGlobalWeekly
) {}

public record InviteSharePayload(String mpPath, String query, String title, String imageUrl) {}
```

公众号菜单只负责打开小程序并带上 `inviteCode`；对话不在公众号内完成。

### 5.4 微信公众号 / 小程序网关（SaaS 模块内）

```java
/** 小程序登录：code2session */
public interface WechatMpAuthClient {
    MpSession code2Session(String jsCode);  // openid, session_key, unionid?
}

/** 公众号：关注事件 / 带参二维码 / 网页授权（若需要） */
public interface WechatOaClient {
    void handleCallback(String timestamp, String nonce, String signature, String body);
    String buildMiniProgramJumpUrl(String path, String query);
}

public interface WechatIdentityService {
    /** 登录或绑定；优先 unionId 合并 */
    RegisterResult loginWithMp(String jsCode, String inviteCodeOrNull);
    void linkOaOpenId(String userId, String oaOpenId);
}
```

配置（环境变量 / 管理台，勿写死）：

- `SAAS_WECHAT_MP_APPID` / `SECRET`
- `SAAS_WECHAT_OA_APPID` / `SECRET` / `TOKEN` / `AES_KEY`
- `SAAS_WECHAT_OPEN_PLATFORM`（是否启用 unionId）

### 5.5 行业模板

```java
public record WorkspaceTemplateDescriptor(
    String id,                   // engineering | ecommerce | retail | software | ...
    String title,
    String description,
    String industry,
    int version,
    // 内容可为 classpath JSON / 对象存储；应用时调用现有 Agent/Skill/Wiki API
    String packageUri
) {}

public interface WorkspaceTemplateCatalog {
    List<WorkspaceTemplateDescriptor> listPublished();
    WorkspaceTemplateDescriptor get(String id);
}

public interface WorkspaceTemplateApplier {
    /** 创建默认 Agent、绑定基础 Skill、可选 Wiki 种子页；不做破坏性清空除非 force */
    void apply(String workspaceId, String templateId, ApplyOptions options);
}
```

模板包内容（文件约定，非代码）：

```
templates/engineering/v1/
  manifest.json          # id, title, agents[], skills[], wiki[]
  agents/*.json
  skills/                # 或引用市场 skill id
  wiki/*.md
```

A：注册后强制或强引导选一次；B：设置页可更换（策略：覆盖预置资源 / 另建空间）。

### 5.6 计量旁路

```java
public interface TokenUsageListener {
    /** 落库 tokenUsage 后调用；实现方聚合到 tenant_weekly_usage */
    void onUsage(String tenantId, String workspaceId, String conversationId,
                 int promptTokens, int completionTokens, String modelId);
}
```

核心在现有 `ConversationService` 写 usage 处 **publish 事件或调用可选 Listener 列表**（`ObjectProvider<List<TokenUsageListener>>`），无 Listener 则零开销。

---

## 6. 建议的最小 API 面（SaaS 模块）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/saas/auth/mp/login` | 小程序 code → token + onboarding |
| POST | `/api/v1/saas/auth/web/register` | Web 注册 |
| POST | `/api/v1/saas/auth/web/login` | 可复用现有 login，或统一发 token |
| GET | `/api/v1/saas/entitlement` | 当前套餐与配额 |
| GET | `/api/v1/saas/templates` | 行业模板列表 |
| POST | `/api/v1/saas/workspaces/{id}/template` | 应用模板 |
| GET | `/api/v1/saas/invite/me` | 我的邀请码与小程序分享参数 |
| POST | `/api/v1/saas/billing/checkout` | B 升级（二期；v1 可人工改 plan） |
| * | `/api/v1/saas/wechat/oa/callback` | 公众号服务器 URL |

现有 `/api/v1/chat/stream` **尽量不动签名**；仅在过滤器/入口增加配额检查。

---

## 7. 数据表草案（SaaS 模块自有库表，前缀 `saas_`）

| 表 | 用途 |
|----|------|
| `saas_tenant` | tenant_id, owner_user_id, plan_code, status |
| `saas_plan_def` | plan 配置（配额 JSON、feature 集合）— 亦可先 YAML |
| `saas_user_identity` | user_id, provider(mp/oa/password), subject(openid…), union_id |
| `saas_referral` | invite_code, inviter, invitee, channel, campaign_id, created_at |
| `saas_reward_ledger` | 发放流水（防重复、对账） |
| `saas_reward_campaign` | 活动配置：是否送 Token、额度、上限 |
| `saas_usage_weekly` | tenant_id, week_key（如 2026-W35）, tokens, searches, … |
| `saas_workspace_template_apply` | workspace_id, template_id, version, applied_at |

工作空间仍用现有 `mate_workspace*`；`saas_tenant.primary_workspace_id` 关联即可。

---

## 8. 分阶段落地（仍不动代码，仅排期参考）

| 阶段 | 交付 | 核心改动量 |
|------|------|------------|
| **S0** | 决策台账齐备；申请公众号+小程序；准备 4 套模板内容大纲 | 0 |
| **S1** | SPI + AllowAll；`saas` 模块空壳；access API 合并 feature；默认 **周额度 2000** 可配 | 小 |
| **S2** | 小程序登录注册 + 建空间 + Plan=A + 4 模板列表/应用 | 小～中 |
| **S3** | 工具/路由门控 + **周** Token 熔断 + 升级文案 | 中 |
| **S4** | 邀请码 + 公众号菜单跳小程序 + 归因 + 可配置奖励 | 小 |
| **S5** | `PaymentGateway`：微信 + 支付宝骨架；参数可后配 | 中 |
| **S6** | C 交付工作流（合同、独立部署清单） | 小 |

---

## 9. 产品决策台账

| # | 议题 | 结论 | 状态 |
|---|------|------|------|
| 1 | A 与 Wiki | 开放只读 `view:wiki`；禁 `manage:wiki` | 已拍板 |
| 2 | B 与 Agent | 允许自建；Token 额度控成本 | 已拍板 |
| 3 | 公众号 | 只获客；对话仅小程序/Web | 已拍板 |
| 4 | 邀请奖励 | 归因必做；送 Token 可配置（含活动期、防刷上限） | 已拍板 |
| 5 | UnionId | 见 §4.5；无开放平台也可先上线 | 已说明 |
| 6 | A/B 默认额度 | **每周 2000**；运营可改数字；**周期固定自然周**（建议周一 00:00，`Asia/Shanghai`） | 已拍板 |
| 7 | 首期行业模板 | 日常工作、电商运营、软件开发、隧道工程施工 | 已拍板 |
| 8 | B 支付 | 微信 + 支付宝接口预留，商户参数后配 | 已拍板 |

**已齐备。** 额度周期不再在日/月间选择。

---

## 10. 小结

- 矩阵与获客路径已按拍板更新；公众号不做对话。  
- 默认额度 **每周 2000**、首期 **4** 模板、支付 **微信+支付宝（参数后配）** 已写入 §3.4–3.6 / §9。  
- 邀请 = 归因 + 可选可配置 Token 奖励。  
- UnionId 见 §4.5；无开放平台也可先上线。  
- 下一步可出《S1 任务拆解 / DDL》；**未下令前仍不改代码。**
