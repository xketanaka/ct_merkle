# 変更履歴

## [Unreleased] - 未リリース

Not yet.

## [0.1.0] - 2026-11-10

初版リリース

### 追加

- `CTMerkle::Tree`：RFC 6962 / RFC 9162 §2.1 に準拠した追記型マークルツリー
  - `append` / `<<` / `append_leaf_hash` で葉を追加
  - `root`、`inclusion_proof`、`consistency_proof` で、ルートハッシュと証明を取得。`tree_size:` で過去の任意のサイズの時点を指定できる
  - `leaf_hash`、`index_of`、`inclusion_proof_by_hash` で、リーフハッシュから葉を検索
  - `at` で、特定のサイズの時点のツリーを `CTMerkle::Snapshot` として取得
- `CTMerkle::InclusionProof` / `CTMerkle::ConsistencyProof`：証明を表す値オブジェクト
  - `verify` / `verify!` で検証
  - `to_h` / `from_h` で Hash と相互に変換（ハッシュ値は hex または base64）
- `CTMerkle::Verifier`：ツリーなしで証明を検証するモジュール関数。RFC 9162 §2.1.3.2 / §2.1.4.2 の手順に従う
- `CTMerkle::Digest`：ハッシュ値を表す値オブジェクト。hex / base64 との相互変換
- `CTMerkle::Hasher::SHA256`：RFC 6962 / RFC 9162 の SHA-256 によるハッシュ関数
- `CTMerkle.root`：葉の配列からルートハッシュを計算するショートカット
- 例外クラス `CTMerkle::Error`、`VerificationError`、`MalformedProofError`、`RootMismatchError`
- 対応する Ruby のバージョン：3.3、3.4、4.0

### 既知の差異

- transparency-dev/merkle（Go）とは、整合性証明の検証で 1 つのケースだけ結果が異なる。`old_size == new_size` でルートの長さが正しくない場合、Go は成功とするが、ct_merkle は `MalformedProofError` とする

[0.1.0]: https://github.com/xketanaka/ct_merkle/releases/tag/v0.1.0
