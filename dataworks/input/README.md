# 客户提供的输入文件

## 业务库表 DDL：`src_ddl*.sql`

来源：字典页 `dataworks/dist/index.html` →「旧系统对照 · 业务库 DDL」→「导出文件」得到的 `src_ddl_YYYYMMDD.sql`。也可以直接放客户给的 mysqldump / `SHOW CREATE TABLE` 文件，按表名自动匹配，同名多数据源的会提示跳过。

放进本目录后重跑：

```bash
python3 dataworks/standard/build.py
```

生效范围：

- 业务库表（SRC）：字段以 DDL 为准，包括顺序、类型、注释、主键；DDL 有而同步任务没读的字段标「未同步」，同步配置有而 DDL 没有的标「可能已删除或改名」；DDL 页签显示原始建表语句。
- ODS：字段注释以 DDL 为准；没有落地 Hive 表结构的列，类型取 DDL。
- 字典页「业务库 DDL」：已处理的表显示「已入库」。

多个文件按文件名排序读取，后面的覆盖前面的同名表。
