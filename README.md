# eqdb-performance-test

EQMonitorの通知配信SQLのパフォーマンステスト用Repository

- https://github.com/YumNumm/EQMonitor/issues/689
  - 実行結果: https://github.com/YumNumm/EQMonitor/issues/689#issuecomment-2118983188
  

## Migrationを実行して、実際に実行するSQLを生成する

```bash
supabase up
supabase migrate up # 事前定義したSQLを実行(./supabase/migrations)
bun run ./index.ts # SQLで書くのが面倒だった部分のダミーデータ投入実行
bun run ./create-sql.ts | pbcopy
```
