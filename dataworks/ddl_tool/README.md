# 业务库 DDL 补齐工具

在浏览器里录入客户业务库表的 `CREATE TABLE` 语句，每次保存直接写进一个文件，不需要导出。

## 启动

- Windows：双击 `启动.bat`
- macOS / Linux：`./start.sh`
- 或：`python3 dataworks/ddl_tool/server.py`

启动后会自动打开浏览器（`http://127.0.0.1:8765/`），并自动创建 `dataworks/input/src_ddl.sql`（已存在就接着用）。工具窗口开着时页面才能保存，用完关掉窗口即可。

参数：`--file 路径` 换文件位置，`--port 端口`，`--no-browser` 不自动打开浏览器。

只依赖 Python 3 标准库。整个 `ddl_tool` 目录可以单独拷到别的电脑上用，表清单在 `src_tables.json`；在别的电脑上用时，建议加 `--file` 指定文件位置。

## 页面

- 左侧是 366 张业务库表（DataWorks 同步任务读取的全部业务表）。
  - 可以按状态筛选：未录入、已录入且一致、已录入有差异、未对上。
  - 也可以按数据源筛选。
- 批量粘贴：一次贴多张，按表名自动对到业务库表。
  - 同一个表名在多个数据源都有时，先选数据源再贴。
  - 对不上的表也会保存，标为「未对上」。
- 单表详情：DDL 字段与同步配置读取的字段逐个比对，分三种：一致；DDL 有、未同步；同步有、DDL 无。可以修改或删除。

## 文件

`dataworks/input/src_ddl.sql`：
- 每张表前一行 `-- @table 数据源:表名` 和一行 `-- @at 录入时间`，下面是原始建表语句；
- 每次保存整份重写，上一版留在 `src_ddl.sql.bak`。

把这个文件交给数仓，重跑 `python3 dataworks/standard/build.py`，字典里的业务库字段、类型、注释、主键就以 DDL 为准，见 `dataworks/input/README.md`。

`src_tables.json` 由 `standard/build.py` 生成。
