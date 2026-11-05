# AWS アイコン（draw.io 標準の AWS 2019 系: `mxgraph.aws4`）

## サービスアイコン（四角に白い絵）

共通 style（`{色}` と `{名前}` を入れ替える。サイズは 78x78）:

```
sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;strokeColor=#ffffff;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontFamily=Noto Sans JP;fontSize=13;fontStyle=1;aspect=fixed;shape=mxgraph.aws4.resourceIcon;fillColor={色};resIcon=mxgraph.aws4.{名前};
```

| サービス | resIcon | fillColor（カテゴリ） |
|---|---|---|
| Lambda | `lambda` | `#ED7100`（コンピューティング） |
| EC2 | `ec2` | `#ED7100` |
| ECS / Fargate | `ecs` / `fargate` | `#ED7100` |
| S3 | `s3` | `#7AA116`（ストレージ） |
| DynamoDB | `dynamodb` | `#C925D1`（データベース） |
| RDS / Aurora | `rds` / `aurora` | `#C925D1` |
| API Gateway | `api_gateway` | `#E7157B`（アプリ統合） |
| SQS / SNS / EventBridge | `sqs` / `sns` / `eventbridge` | `#E7157B` |
| Step Functions | `step_functions` | `#E7157B` |
| CloudWatch | `cloudwatch_2` | `#E7157B`（管理） |
| CloudFront | `cloudfront` | `#8C4FFF`（ネットワーク） |
| Route 53 | `route_53` | `#8C4FFF` |
| Cognito | `cognito` | `#DD344C`（セキュリティ） |
| IAM | `identity_and_access_management` | `#DD344C` |

表に無いサービスは `stencils/aws4.xml`（`/opt/drawio-viewer/stencils/aws4.xml`）の `<shape name="...">` を探す。名前は小文字・空白を `_` にしたもの。PNG で絵が出ないときは名前の間違い。

## 人・端末（アイコンだけで四角なし）

```
sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#232F3D;strokeColor=none;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontFamily=Noto Sans JP;fontSize=13;fontStyle=1;aspect=fixed;pointerEvents=1;shape=mxgraph.aws4.user;
```

`shape=` を `mxgraph.aws4.users` / `mxgraph.aws4.mobile_client` / `mxgraph.aws4.client` に変えると別の絵になる。

## グループ枠

共通 style:

```
outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontFamily=Noto Sans JP;fontSize=12;fontStyle=0;container=1;pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;verticalAlign=top;align=left;spacingLeft=30;fillColor=none;
```

これに続けて:

| 枠 | 追加 style |
|---|---|
| AWS Cloud | `grIcon=mxgraph.aws4.group_aws_cloud_alt;strokeColor=#232F3E;fontColor=#232F3E;dashed=0;` |
| Region | `grIcon=mxgraph.aws4.group_region;strokeColor=#00A4A6;fontColor=#147EBA;dashed=1;` |
| VPC | `grIcon=mxgraph.aws4.group_vpc2;strokeColor=#8C4FFF;fontColor=#8C4FFF;dashed=0;` |
| Public subnet | `grIcon=mxgraph.aws4.group_security_group;grStroke=0;strokeColor=#7AA116;fillColor=#F2F6E8;fontColor=#248814;dashed=0;` |
| Private subnet | `grIcon=mxgraph.aws4.group_security_group;grStroke=0;strokeColor=#00A4A6;fillColor=#E6F6F7;fontColor=#147EBA;dashed=0;` |

## 配置の目安（このリポジトリの図で確認済み）

- アイコン 78x78、横に並べる間隔は 230px（アイコン間のすき間 152px。2 行の矢印ラベルが入る）。
- アイコン名は下に出て、高さ約 20px 使う。下の段に置くアイコンは 60px 以上離す。
- 枠の上辺から最初のアイコンまで 130px 空けると、上を回る矢印とそのラベルが入る。
