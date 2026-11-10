# ct_merkle

[RFC 6962](https://www.rfc-editor.org/rfc/rfc6962) / [RFC 9162](https://www.rfc-editor.org/rfc/rfc9162) §2.1（Certificate Transparency）に準拠した、追記型マークルツリーの Ruby 実装。

## 機能

- 文字列または任意のハッシュ値を葉としてマークルツリーを作成
- マークルツリーよりルートのハッシュ、包含証明、整合性証明を取得可能(過去の任意のサイズ時点のツリーからも取得可)
- 外部から与えられた包含証明、整合性証明を検証可能
- 検証手順は RFC 9162 §2.1.3.2 / §2.1.4.2 に準拠
- [transparency-dev/merkle](https://github.com/transparency-dev/merkle) のテストベクタで動作を検証済み
- 依存ライブラリなし

## インストール

```bash
gem install ct_merkle

# or

bundle add ct_merkle
```

## 使い方

### ツリー作成、包含証明

```ruby
# ツリーを作成
tree  = CTMerkle::Tree.new(["a", "b", "c", "d"])

# ルートハッシュ、"c"(=index:2)の包含証明を取得
root  = tree.root
proof = tree.inclusion_proof(2)

# 包含証明の検証
proof.verify(leaf_data: "c", root: root)   # => true
proof.verify(leaf_data: "x", root: root)   # => false
```

### 追記型ログの整合性証明

```ruby
tree = CTMerkle::Tree.new
tree.append("e0")
tree << "e1" << "e2" << "e3" << "e4"
tree.tree_size                        # => 5

# ルートハッシュの取得(tree_sizeを指定するとその時点のルートハッシュを取得)
root3 = tree.root(tree_size: 3)
root5 = tree.root

# 現在のツリーと tree_size:3 の時点のツリーの整合性証明
cproof = tree.consistency_proof(3)
cproof.verify(old_root: root3, new_root: root5)   # => true
```

### ツリーのスナップショット

```ruby
# tree.at(n)` は `tree_size: n` 時点の読み取り専用ツリーを返却する
snap = tree.at(4)
snap.root                    # tree.root(tree_size: 4) と同じ
snap.inclusion_proof(0)      # tree.inclusion_proof(0, tree_size: 4) と同じ
snap.consistency_proof(3)    # tree.consistency_proof(3, tree_size: 4) と同じ
```

### ハッシュ値からインデックスを取得

```ruby
h = CTMerkle::Hasher::SHA256.leaf("e2")
tree.index_of(h)                  # => 2
tree.inclusion_proof_by_hash(h)   # tree.inclusion_proof(2) と同じ
```

### 証明の検証

```ruby
## 包含証明
# leaf_hash, leaf_index, tree_size, inclusion_path, root_hex が与えられた状態で
# leaf_hash が root_hex のツリーに含まれることを検証する
proof = CTMerkle::InclusionProof.new(
  leaf_index: 2,
  tree_size: 5,
  inclusion_path: path_hex.map { CTMerkle::Digest.from_hex(_1) },
)
proof.verify!(leaf_hash: leaf_hash, root: CTMerkle::Digest.from_hex(root_hex))

## 整合性証明
# old_size, new_size, consistency_path, old_root_hex, new_root_hex が与えられた状態で
# old_root_hex のツリーが new_root_hex のツリーの先頭部分そのままであることを検証する
cproof = CTMerkle::ConsistencyProof.new(
  old_size: 3,
  new_size: 5,
  consistency_path: path_hex.map { CTMerkle::Digest.from_hex(_1) },
)
cproof.verify!(
  old_root: CTMerkle::Digest.from_hex(old_root_hex),
  new_root: CTMerkle::Digest.from_hex(new_root_hex),
)
```

### ハッシュ値

ルートのハッシュ値は `CTMerkle::Digest` クラスで表現される。hex, base64, binary 文字列と相互変換可能

```ruby
d = tree.root
d.to_hex       # => "33376a3b..."
d.to_base64    # => "MzdqO9Y+..."
d.to_binary    # => 生のバイト列（BINARY エンコーディング）

CTMerkle::Digest.from_hex("33376a3b...")
CTMerkle::Digest.from_base64("MzdqO9Y+...")
```

### 直列化

包含証明、整合性証明は `to_h` / `from_h` で Hash と相互変換可能

```ruby
require "json"

json = JSON.generate(tree.inclusion_proof(2).to_h)   # to_h はデフォルトでハッシュ値を hex でエンコーディングする
# {"leaf_index":2,"tree_size":5,"inclusion_path":["...", "..."]}

proof = CTMerkle::InclusionProof.from_h(JSON.parse(json))
proof.to_h(encoding: :base64)                        # base64 エンコーディングを指定
```

Hashのキーは RFC 9162 の `InclusionProofDataV2` / `ConsistencyProofDataV2` のフィールド名に準拠

### CT ログからの検証

[RFC 6962 の JSON API](https://www.rfc-editor.org/rfc/rfc6962#section-4) の例

```ruby
# GET /ct/v1/get-sth
sth  = JSON.parse(sth_body)
root = CTMerkle::Digest.from_base64(sth["sha256_root_hash"])

# GET /ct/v1/get-proof-by-hash?hash=...&tree_size=<sth["tree_size"]>
res = JSON.parse(proof_body)
proof = CTMerkle::InclusionProof.new(
  leaf_index: res["leaf_index"],
  tree_size: sth["tree_size"],
  inclusion_path: res["audit_path"].map { CTMerkle::Digest.from_base64(_1) },
)
proof.verify(leaf_hash: leaf_hash, root: root)
```

### 参照

- 各クラス・メソッドの仕様は [docs/reference.md](docs/reference.md) を参照

## 開発

```bash
bundle install
bundle exec rake test
```

Docker を使う場合：

```bash
docker compose run --rm test        # Ruby 4.0
docker compose run --rm test-3.x    # Ruby 3.x
```

`test/fixtures/transparency-dev` にあるテストベクタは [transparency-dev/merkle](https://github.com/transparency-dev/merkle) から取得したもの

## ライセンス

[MIT License](LICENSE.txt)
