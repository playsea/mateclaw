# MateClaw Windows 本地开发与部署调试指南

本文档面向 **Windows 开发机**，说明如何用项目自带脚本一键启动、调试常见问题，以及生产部署要点。

---

## 1. 环境要求

| 组件 | 版本 | 说明 |
|------|------|------|
| JDK | 21+ | 项目 `pom.xml` 指定 Java 21 |
| Maven | 3.9+ | 构建后端及本地模块 |
| Node.js | 20+ | 前端开发服（部分依赖建议 22+，20 可用但有 engine 警告） |

### 推荐运行时路径（可按机器修改）

```
E:\runtime\jdk-21_windows-x64_bin\jdk-21.0.11   ← 注意：JDK 解压后还有一层子目录
E:\runtime\node-v20.19.0-win-x64
E:\runtime\apache-maven-3.9.8\apache-maven-3.9.8
```

> **常见坑**：`E:\runtime\jdk-21_windows-x64_bin` 外层目录没有 `bin\java.exe`，`JAVA_HOME` 必须指向内层 `jdk-21.x.x` 目录。

---

## 2. 一键启动（推荐）

### 2.1 首次使用：配置路径

```powershell
cd E:\project\mateclaw\scripts
copy dev.local.ps1.example dev.local.ps1
# 用记事本编辑 dev.local.ps1，改成你机器上的实际路径
```

### 2.2 启动命令

**方式 A — 双击（最简单）**

```
scripts\dev-start.bat
```

**方式 B — PowerShell**

```powershell
cd E:\project\mateclaw\scripts

# 首次或代码/依赖变更后：先构建再启动
.\dev-start.ps1 -Build

# 日常开发：直接启动（若已在运行会自动关闭旧进程再重启）
.\dev-start.ps1

# 仅启动后端
.\dev-start.ps1 -BackendOnly

# 仅启动前端（需后端已在 18088 运行）
.\dev-start.ps1 -FrontendOnly

# 查看端口与健康状态
.\dev-start.ps1 -Status
```

### 2.3 停止服务

```powershell
cd E:\project\mateclaw\scripts
.\dev-stop.ps1
```

### 2.4 访问地址

| 服务 | 地址 |
|------|------|
| 前端开发控制台 | http://localhost:5173 |
| 后端 API | http://localhost:18088 |
| Swagger 文档 | http://localhost:18088/swagger-ui.html |
| 健康检查 | http://localhost:18088/actuator/health |

**默认登录**：`admin` / `admin123`

开发模式下前端 Vite 会把 `/api` 和 `/skill-assets` 代理到后端 `18088`，因此日常开发请访问 **5173**，不要直接访问 18088 的静态页（开发时前端未 build 到后端）。

---

## 3. 手动启动（脚本等价命令）

若需手动排查，可按以下步骤分两个终端执行。

**终端 1 — 后端**

```powershell
$env:JAVA_HOME="E:\runtime\jdk-21_windows-x64_bin\jdk-21.0.11"
$env:Path="$env:JAVA_HOME\bin;E:\runtime\apache-maven-3.9.8\apache-maven-3.9.8\bin;$env:Path"

cd E:\project\mateclaw
mvn install -pl mateclaw-server -am -DskipTests   # 首次或模块变更后

cd mateclaw-server
mvn spring-boot:run -DskipTests
```

**终端 2 — 前端**

```powershell
$env:Path="E:\runtime\node-v20.19.0-win-x64;$env:Path"

cd E:\project\mateclaw\mateclaw-ui
npm install    # 首次
npm run dev
```

---

## 4. 架构与数据

```
浏览器 → http://localhost:5173 (Vite)
              ↓ 代理 /api, /skill-assets
         http://localhost:18088 (Spring Boot)
              ↓
         H2 文件库 ./mateclaw-server/data/mateclaw.*
```

- **默认 profile**：`dev`，使用内置 **H2 文件数据库**，数据落在 `mateclaw-server/data/` 目录。
- **LLM API Key**：无需在 `.env` 配置，启动后在管理界面 **设置 → 模型管理** 添加。
- **Flyway**：启动时自动执行数据库迁移。

---

## 5. 常见问题排查

### 5.1 `Could not transfer artifact vip.mate:mateclaw-plugin-api`

**原因**：本地 Maven 模块未安装，或网络拉包失败。

**解决**：

```powershell
cd E:\project\mateclaw
mvn install -pl mateclaw-server -am -DskipTests
```

国内网络慢可在 `dev.local.ps1` 中设置 `$env:MAVEN_FLAGS = "-Paliyun-first"`。

---

### 5.2 `Unable to find a suitable main class`（根目录 spring-boot:run 失败）

**原因**：在仓库根目录执行 `mvn spring-boot:run -am` 会误触发根 POM。

**解决**：必须在 `mateclaw-server` 目录执行，或使用 `scripts/dev-start.ps1`。

---

### 5.3 前端 `http proxy error: ECONNREFUSED`

**原因**：后端未启动或端口不是 18088。

**解决**：

```powershell
.\dev-start.ps1 -Status
# 确认 18088 在监听且 /actuator/health 返回 UP
```

---

### 5.4 端口被占用

```powershell
# 查看占用
Get-NetTCPConnection -LocalPort 18088 -State Listen
Get-NetTCPConnection -LocalPort 5173 -State Listen

# 一键停止 MateClaw 开发服务
.\dev-stop.ps1
```

---

### 5.5 JAVA_HOME 不正确 / `不支持发行版本 21`

**现象**：`mvn` 报 `Fatal error compiling: 错误: 不支持发行版本 21`，或 `java -version` 显示 17 而非 21。

**原因**：终端未设置 `JAVA_HOME`，Maven 使用了系统默认 Java 17（`C:\Program Files\Java\jdk-17`）。

**解决**：先加载开发环境脚本，再执行 Maven：

```powershell
. E:\project\mateclaw\scripts\dev-env.ps1

cd E:\project\mateclaw\mateclaw-server
mvn spring-boot:run '-Dmaven.test.skip=true'
```

> `-Dmaven.test.skip=true` 跳过测试代码编译（680 个测试类），开发启动更快。  
> 仅用 `-DskipTests` 仍会编译测试代码，只是不运行测试。

验证 Maven 使用的 Java 版本：

```powershell
mvn -version
# 应显示 Java version: 21.x
```

**IntelliJ IDEA**：在 **Project Structure → SDK** 和 **Settings → Build → Maven → Runner → JRE** 都改为 JDK 21。

---

### 5.6 PowerShell 下 Maven 参数被截断 / `Unknown lifecycle phase ".test.skip=true"`

**现象**：`mvn spring-boot:run -Dmaven.test.skip=true` 报 `Unknown lifecycle phase ".test.skip=true"`。

**原因**：PowerShell 会把 `-Dmaven.test.skip=true` 当成自己的参数解析，Maven 只收到 `.test.skip=true`。

**解决**：参数加引号：

```powershell
mvn spring-boot:run '-Dmaven.test.skip=true'
```

---

### 5.8 后端日志中文 / 边框字符乱码

**现象**：控制台出现 `鈺斺晲`、`鎺у埗鍙` 等乱码，但服务实际已正常启动。

**原因**：Java 以 UTF-8 输出日志，Windows 控制台默认 GBK（代码页 936）导致显示错乱。

**解决**：

1. 使用最新版 `dev-start.bat` / `dev-start.ps1`（已自动 `chcp 65001` 并设置 Java UTF-8 参数）
2. 手动启动时先加载环境：

```powershell
. E:\project\mateclaw\scripts\dev-env.ps1
chcp 65001
cd E:\project\mateclaw\mateclaw-server
mvn spring-boot:run '-Dmaven.test.skip=true'
```

乱码不影响服务运行，日志文件 `./logs/mateclaw.log` 中内容是正确的 UTF-8。

---

### 5.7 npm engine 警告（Node 20）

部分包（如 `pdfjs-dist`、`rollup-plugin-visualizer`）声明需要 Node 22+，在 Node 20 下仅为警告，一般不影响 `npm run dev`。若前端构建异常，可升级到 Node 22 LTS。

---

## 6. 生产部署（Docker）

开发调试与生产部署分离。生产推荐使用 Docker：

```powershell
cd E:\project\mateclaw
copy .env.example .env
# 编辑 .env，至少设置 DB_PASSWORD 等必填项

docker compose up -d
# 访问 http://localhost:18080
```

详见项目根目录 `.env.example` 与 `docker-compose.yml`。Docker 默认使用 **PostgreSQL 16**。

---

## 7. 打包前后端一体 JAR

前端 build 产物会输出到 `mateclaw-server/src/main/resources/static`，随后打 JAR 可单进程部署：

```powershell
cd E:\project\mateclaw\mateclaw-ui
npm run build

cd E:\project\mateclaw
mvn package -pl mateclaw-server -am -DskipTests

java -jar mateclaw-server\target\mateclaw-server-*.jar
# 访问 http://localhost:18088
```

---

## 8. IDE 调试建议

### IntelliJ IDEA

1. **Import**：以 Maven 项目打开 `E:\project\mateclaw`。
2. **Project SDK**：设置为 JDK 21（`E:\runtime\jdk-21_windows-x64_bin\jdk-21.0.11`）。
3. **运行配置**：Main class `vip.mate.MateClawApplication`，Working directory `mateclaw-server`。
4. **前端**：单独在 `mateclaw-ui` 目录 `npm run dev`，或 IDE 终端执行 `scripts/dev-start.ps1 -FrontendOnly`。

### VS Code / Cursor

- Java 扩展：配置 `java.configuration.runtimes` 指向 JDK 21。
- 后端：Spring Boot Dashboard 或 Java Debug 启动 `MateClawApplication`。
- 前端：终端 `npm run dev`。

---

## 9. 脚本清单

| 文件 | 说明 |
|------|------|
| `scripts/dev-lib.ps1` | 启停脚本共享逻辑（端口检测、停止进程） |
| `scripts/dev-env.ps1` | 加载 JDK 21 / Maven / Node 环境变量（手动 Maven 命令前使用） |
| `scripts/dev-start.ps1` | 一键启动（PowerShell） |
| `scripts/dev-start.bat` | 一键启动（双击入口） |
| `scripts/dev-stop.ps1` | 停止 18088 / 5173 上的进程 |
| `scripts/dev.local.ps1.example` | 本地路径配置模板 |

---

## 10. 相关文档

- [README_zh.md](../README_zh.md) — 项目概览与快速开始
- [claw.mate.vip/docs](https://claw.mate.vip/docs) — 官方完整文档
- [.env.example](../.env.example) — Docker / 生产环境变量说明
