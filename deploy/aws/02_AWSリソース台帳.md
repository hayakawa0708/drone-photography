# drone AWSリソース台帳

更新日: 2026-08-13  
リージョン: `ap-northeast-1`（CloudFront自体はグローバル）  
状態: すべて予定・未作成

| 種類 | 名前・ID | 状態 | 用途 | 課金要因 | 停止・削除 |
|---|---|---|---|---|---|
| S3 bucket | CloudFormation自動名 | 予定 | 静的ファイルを非公開保存 | 保存量、PUT/GET | 中身を確認して空にし、Stack削除後にbucket削除 |
| S3 bucket policy | 自動 | 予定 | CloudFrontだけに読取許可 | 原則追加料金なし | Stack削除 |
| CloudFront OAC | 自動 | 予定 | S3への署名付きアクセス | 原則追加料金なし | Stack削除 |
| Cache policy | 自動 | 予定 | キャッシュを通常1時間に固定 | 原則追加料金なし | Stack削除 |
| Response headers policy | 自動 | 予定 | CSP・HSTS等を付与 | 原則追加料金なし | Stack削除 |
| CloudFront distribution | 自動 | 予定 | HTTPS公開 | リクエスト、通信量 | Disable後にStack削除 |

## 作らないもの

EC2、Lambda、RDS、DynamoDB、NAT Gateway、ALB、固定IPv4、Route 53、独自証明書、WAF、CloudWatch LogsはPhase 1で作りません。

## 秘密情報

Phase 1はAPIキーやAWSアクセスキーをアプリへ保存しません。CloudFormation、HTML、JSON、配布フォルダにも秘密情報を含めません。

## 料金通知

stock等と共通のアカウント全体Budgetsを使います。二重作成せず、既存Budgetがあれば通知先と閾値を確認します。

| 閾値 | 通知先 | 確認状態 |
|---:|---|---|
| 300円相当 | ユーザー指定メール | 未設定 |
| 700円相当 | ユーザー指定メール | 未設定 |
| 1,000円相当 | ユーザー指定メール | 未設定 |
