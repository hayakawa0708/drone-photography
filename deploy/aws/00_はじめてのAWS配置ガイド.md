# drone はじめてのAWS配置ガイド

更新日: 2026-08-13  
現在地: **AWS未作成**

## 最初に覚える用語

- **S3**: アプリのファイルを置く倉庫。今回の倉庫は直接公開しません
- **CloudFront**: S3の前に置くHTTPSの公開入口
- **OAC**: CloudFrontからの読取だけをS3へ許可する鍵のような設定
- **CloudFormation**: S3やCloudFrontの設定をまとめた設計図
- **AWS Budgets**: AWS料金が設定額へ近づいたときの通知

## 全体の順番

| 順番 | どこで行うか | 作業 | 課金の可能性 |
|---:|---|---|---|
| 0 | Windows | テスト、短期branch、commit、push、配布フォルダ検査 | なし |
| 1 | AWS管理画面 | アカウント全体のBudgets通知を設定 | 通知機能の現行条件を画面で確認 |
| 2 | AWS管理画面 | CloudFormationのテンプレートを確認 | まだ作成しなければなし |
| 3 | AWS管理画面 | Stackを作成 | **S3・CloudFrontの従量課金対象が作られる** |
| 4 | Windows / AWS | 検査済みファイルをS3へ配置 | S3 PUT・保存量 |
| 5 | ブラウザ | CloudFront URLで実機確認 | CloudFrontリクエスト・通信量 |

## 作業前の停止点

`01_作成前チェックリスト.md`で、公開範囲、料金通知、配布ファイル、削除方法を確認します。commitやGitHubへのpushだけではAWSへ公開されず、AWS料金も始まりません。

CloudFormation画面の「送信」または「スタックの作成」を押す直前で一度止まり、作成予定が次の6種類だけか確認します。

1. S3 bucket
2. S3 bucket policy
3. CloudFront OAC
4. CloudFront cache policy
5. CloudFront response headers policy
6. CloudFront distribution

## 成功条件

- S3の「パブリックアクセスをすべてブロック」が有効
- S3 URLを直接開くと拒否される
- CloudFront URLはHTTPSで開く
- 住所候補を選択するまで飛行判定が始まらない
- 羽田空港付近で1km簡易警告が出る
- JSONバックアップとExcel出力が利用できる
- レスポンスにCSP、HSTS、`X-Content-Type-Options: nosniff`がある
- 料金通知先へBudgetsの確認メールが届いている

詳細な操作は`04_構築・更新手順.md`へ進みます。
