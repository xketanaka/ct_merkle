# ct_merkle API 設計メモ

RFC 6962 / RFC 9162 §2.1 に準拠したマークルツリーの Ruby 実装

## 1. 基本方針

- **追記型を基本にする**: ツリーは追記のみ。バッチ型の用途も追記されていないツリーとして同じクラスで扱う。
- **生成と検証を分離する**: 証明を検証する側はツリー全体を持つ必要がない。検証は `Tree` なしでもできるようにする。
- **基準ツリーは `tree_size:` 引数で指定する**: 証明やルートは「どのサイズの時点のツリーに対するものか」とセットで意味を持つ。基準のツリーはキーワード引数 `tree_size:` で指定し、省略した場合は現在のサイズを使う。
- **ハッシュ値はバイナリで持ち、公開 API では `CTMerkle::Digest` で返す**: 中身は生のバイト列（SHA-256 なら 32 バイト、エンコーディングは BINARY）に統一する。公開 API の戻り値はそれを包んだ `CTMerkle::Digest` とし、hex や base64 への変換は `to_hex` / `to_base64` で行う。引数としては `Digest` とバイナリ文字列のどちらも受け付ける。
- **依存は標準ライブラリだけにする**: `openssl` / `digest` のみ。

## 2. 使用例

```ruby
require "ct_merkle"

# バッチ型: tree_size を意識しなくてよい
tree  = CTMerkle::Tree.new(["a", "b", "c", "d"])
root  = tree.root                             # => #<CTMerkle::Digest 3a7b...>
root.to_hex                                   # => "3a7b..."
proof = tree.inclusion_proof(2)               # tree_size は自動で 4
proof.verify(leaf_data: "c", root: root)      # => true

# 追記型
log = CTMerkle::Tree.new
i = log.append("e0")                          # => 0（追加した葉のインデックス）
log << "e1" << "e2" << "e3" << "e4"

root4 = log.root(tree_size: 4)
root5 = log.root

log.inclusion_proof(0, tree_size: 4)          # サイズ4の時点に対する包含証明
cproof = log.consistency_proof(3)             # サイズ3 → 現在のサイズ(5)
cproof.verify(old_root: log.root(tree_size: 3), new_root: root5)

# 検証する側（ツリーを持たない）。外部から base64 で受け取った値を使う例
path  = path_b64.map { |s| CTMerkle::Digest.from_base64(s) }
proof = CTMerkle::InclusionProof.new(leaf_index: 0, tree_size: 4, inclusion_path: path)
proof.verify!(leaf_hash: lh, root: CTMerkle::Digest.from_base64(root4_b64))  # 失敗すると例外
```

## 3. 用語

| 用語 | 意味 |
|---|---|
| 葉（リーフ） | ツリーに追加した 1 件のデータ |
| `index` / `leaf_index` | 追加した順番での葉の位置。0 から数える。一度決まったら変わらない |
| `tree_size` | 葉の数（= 追加した件数）。有効なインデックスは `0`〜`tree_size - 1` |
| リーフハッシュ | `HASH(0x00 ‖ data)` |
| ノードハッシュ | `HASH(0x01 ‖ left ‖ right)` |
| ルートハッシュ (MTH) | ツリー全体のハッシュ。空のツリーのルートは `HASH("")` |
| 包含証明 (Inclusion Proof) | ある葉が、サイズ `tree_size` のツリーに含まれていることの証明 |
| 整合性証明 (Consistency Proof) | サイズ `old_size` のツリーが、サイズ `new_size` のツリーの先頭部分そのままであることの証明 |

## 4. `CTMerkle::Tree`

追記専用のマークルツリー。

### 生成

```ruby
CTMerkle::Tree.new(leaves = [], hasher: CTMerkle::Hasher::SHA256)
```

- `leaves`: 最初に追加する生データ（String）の配列。

### 追加

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `append(data)` | Integer | 生データを追加し、その葉のインデックスを返す。リーフハッシュは内部で計算する |
| `<<(data)` | self | `append` と同じ。チェーンして書けるよう self を返す |
| `append_leaf_hash(leaf_hash)` | Integer | 計算済みのリーフハッシュを追加し、インデックスを返す |

### 参照

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `tree_size` | Integer | 現在の葉の数 |
| `size` | Integer | `tree_size` の別名 |
| `root(tree_size: self.tree_size)` | `Digest` | 指定したサイズの時点のルートハッシュ |
| `leaf_hash(index)` | `Digest` | 指定した葉のリーフハッシュ |
| `index_of(leaf_hash)` | Integer / nil | 指定したリーフハッシュを持つ葉のインデックス。同じハッシュが複数ある場合は最初のもの。見つからなければ `nil` |
| `at(tree_size)` | `Snapshot` | 指定したサイズの時点のツリー（読み取り専用）を返す |

### 証明の生成

| メソッド | 戻り値 |
|---|---|
| `inclusion_proof(index, tree_size: self.tree_size)` | `InclusionProof` |
| `inclusion_proof_by_hash(leaf_hash, tree_size: self.tree_size)` | `InclusionProof` / nil |
| `consistency_proof(old_size, tree_size: self.tree_size)` | `ConsistencyProof` |

どのメソッドも、第 1 引数が証明の対象、`tree_size:` が基準となるツリーを表す。

- `consistency_proof(3)` は `consistency_proof(3, tree_size: tree.tree_size)` と同じ意味。
- `inclusion_proof_by_hash` は、`index_of` で求めたインデックスに対する包含証明を返す（RFC 6962 の `get-proof-by-hash` に相当）。リーフハッシュが見つからない場合や、見つかったインデックスが `tree_size` 以上の場合は `nil` を返す。
- 証明はその時点のスナップショットになる。生成後に追記しても、すでに作った証明の中身は変わらない。

`index_of` と `inclusion_proof_by_hash` のため、`Tree` は内部に「リーフハッシュ → インデックス」の対応表を持つ。そのぶん葉の数に比例してメモリを使う。

## 5. `CTMerkle::Snapshot`

`Tree#at(tree_size)` が返す、特定のサイズの時点のツリー。読み取り専用で、`tree_size:` 引数の代わりに「どの時点のツリーか」をオブジェクトとして表す。

```ruby
snap = tree.at(4)
snap.root                    # tree.root(tree_size: 4) と同じ
snap.inclusion_proof(0)      # tree.inclusion_proof(0, tree_size: 4) と同じ
snap.consistency_proof(3)    # tree.consistency_proof(3, tree_size: 4) と同じ
```

ツリーは追記しかできないため、`Snapshot` を作ったあとで元の `Tree` に追記しても、`Snapshot` の内容は変わらない。

### メソッド

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `tree_size` | Integer | この時点の葉の数 |
| `size` | Integer | `tree_size` の別名 |
| `root` | `Digest` | この時点のルートハッシュ |
| `leaf_hash(index)` | `Digest` | 指定した葉のリーフハッシュ。`index >= tree_size` なら `ArgumentError` |
| `index_of(leaf_hash)` | Integer / nil | この時点のツリーに含まれる葉のうち、最初に一致したもののインデックス |
| `inclusion_proof(index)` | `InclusionProof` | この時点のツリーに対する包含証明 |
| `inclusion_proof_by_hash(leaf_hash)` | `InclusionProof` / nil | この時点のツリーに対する包含証明 |
| `consistency_proof(old_size)` | `ConsistencyProof` | `old_size` → この時点のサイズの整合性証明 |

## 6. `CTMerkle::InclusionProof`

包含証明を表す値オブジェクトで、frozen の状態で生成する。属性名は RFC 9162 §4.12 / §4.13 に合わせる。

### コンストラクタ

```ruby
CTMerkle::InclusionProof.new(leaf_index:, tree_size:, inclusion_path:)
CTMerkle::InclusionProof.from_h(hash, encoding: :hex)   # 直列化の項を参照
```

### アクセサ

| 属性・メソッド | 説明 |
|---|---|
| `leaf_index` | 葉のインデックス |
| `tree_size` | 基準となるツリーのサイズ |
| `inclusion_path` | 証明に使うハッシュ（`Digest`）の配列（RFC 6962 での audit path） |
| `verify(leaf_data: \| leaf_hash:, root:)` | 検証結果を `true` / `false` で返す |
| `verify!(leaf_data: \| leaf_hash:, root:)` | 検証に失敗すると例外を投げる。成功時は `true` |
| `to_h(encoding: :hex)` | Hash に変換する。直列化の項を参照 |

`leaf_data:` と `leaf_hash:` はどちらか一方だけを指定する。両方指定した場合や、どちらも指定しない場合は `ArgumentError`。

### 直列化

`to_h` と `from_h` で Hash と相互に変換する。JSON などへの変換は利用者側で行う。

```ruby
h = proof.to_h
# => { leaf_index: 0, tree_size: 4, inclusion_path: ["2cf24dba...", ...] }
proof.to_h(encoding: :base64)
# => { leaf_index: 0, tree_size: 4, inclusion_path: ["LPJNul+w...", ...] }

json = JSON.generate(proof.to_h)
CTMerkle::InclusionProof.from_h(JSON.parse(json))
```

- `encoding:` は `:hex`（既定）または `:base64`。それ以外は `ArgumentError`。既定を hex にしたのは、`Digest#to_s` や `inspect` と表現をそろえるため。
- `to_h` のキーは属性名のシンボル。ハッシュ値は `encoding:` に従った文字列になる。
- `from_h` のキーはシンボルと文字列のどちらでもよい（`JSON.parse` の結果をそのまま渡せる）。ハッシュ値は `encoding:` に従った文字列として解釈する。
- `from_h` で必要なキーがない場合、未知のキーがある場合、ハッシュ値が `encoding:` の形式として不正な場合は `ArgumentError`。
- `from_h(proof.to_h(encoding: e), encoding: e)` は元の証明と等しくなる。

#### 形式の位置づけ

この形式は ct_merkle 独自のもので、特定の標準には準拠しない。内容は RFC 9162 の `InclusionProofDataV2` / `ConsistencyProofDataV2` から `log_id`（CT 固有のログ識別子）を除き、JSON で表せる Hash にしたもの。

| このgemのキー | RFC 9162 のフィールド |
|---|---|
| `leaf_index` | `InclusionProofDataV2.leaf_index` |
| `tree_size` | `InclusionProofDataV2.tree_size` |
| `inclusion_path` | `InclusionProofDataV2.inclusion_path` |
| `old_size` | `ConsistencyProofDataV2.tree_size_1` |
| `new_size` | `ConsistencyProofDataV2.tree_size_2` |
| `consistency_path` | `ConsistencyProofDataV2.consistency_path` |
| （なし） | `log_id` |

ハッシュ値の表現（hex / base64）は独自に定めたもので、RFC 9162 では生のバイト列。

#### 互換性

この形式の互換性は、gem のバージョン（セマンティックバージョニング）で保証する。キー名、キーの追加・削除、ハッシュ値の表現、`encoding:` の既定値を変えるのはメジャーバージョンを上げるときだけとする。

外部の形式（RFC 6962 の JSON API や Rekor など）は、キー名やハッシュの表現がそれぞれ違うため、専用の変換は用意しない。`new` と `Digest.from_hex` / `Digest.from_base64` で組み立てる。

```ruby
# RFC 6962 の get-proof-by-hash（tree_size はリクエストで指定した値）
res = JSON.parse(body)
proof = CTMerkle::InclusionProof.new(
  leaf_index:     res["leaf_index"],
  tree_size:      requested_tree_size,
  inclusion_path: res["audit_path"].map { CTMerkle::Digest.from_base64(_1) },
)

# Rekor
ip = entry["verification"]["inclusionProof"]
proof = CTMerkle::InclusionProof.new(
  leaf_index:     ip["logIndex"],
  tree_size:      ip["treeSize"],
  inclusion_path: ip["hashes"].map { CTMerkle::Digest.from_hex(_1) },
)
```

v1 では `to_json` と RFC 9162 のバイナリ形式（`InclusionProofDataV2`）は提供しない。前者は ActiveSupport などが定義する `to_json` と競合しやすいため、後者は CT 固有の `log_id` を含みマークルツリーの範囲を超えるため。

## 7. `CTMerkle::ConsistencyProof`

整合性証明を表す値オブジェクトで、frozen の状態で生成する。属性名は RFC 9162 §4.12 / §4.13 に合わせる。

### コンストラクタ

```ruby
CTMerkle::ConsistencyProof.new(old_size:, new_size:, consistency_path:)
CTMerkle::ConsistencyProof.from_h(hash, encoding: :hex)
```

### アクセサ

| 属性・メソッド | 説明 |
|---|---|
| `old_size` | 古いツリーのサイズ（RFC 9162 の `tree_size_1`） |
| `new_size` | 新しいツリーのサイズ（RFC 9162 の `tree_size_2`） |
| `consistency_path` | 証明に使うハッシュ（`Digest`）の配列 |
| `verify(old_root:, new_root:)` | 検証結果を `true` / `false` で返す |
| `verify!(old_root:, new_root:)` | 検証に失敗すると例外を投げる。成功時は `true` |
| `to_h(encoding: :hex)` | Hash に変換する。`{ old_size:, new_size:, consistency_path: }` の形 |

直列化の仕様は `InclusionProof` と同じ（6 章「直列化」を参照）。

生成時はキーワード引数で `tree_size:` を指定するが、できあがった証明では 2 つのサイズが同列に並ぶため、属性名は `old_size` / `new_size` とする。

## 8. `CTMerkle::Digest`

ハッシュ値を表す値オブジェクト。中身は BINARY エンコーディングのバイト列で、frozen の状態で生成する。公開 API がハッシュ値を返すときは、すべてこのクラスを使う。

```ruby
d = CTMerkle::Digest.from_hex("2cf24dba...")
d.to_hex       # => "2cf24dba..."
d.to_base64    # => "LPJNul+w..."
d.to_binary    # => "\x2C\xF2\x4D\xBA..."（BINARY エンコーディング）
d.bytesize     # => 32
p d            # => #<CTMerkle::Digest 2cf24dba...>
```

### コンストラクタ

| メソッド | 説明 |
|---|---|
| `Digest.new(bytes)` | バイト列から作る。エンコーディングに関係なく、内部で BINARY に揃える |
| `Digest.from_hex(str)` | hex 文字列から作る。大文字小文字は問わない。hex として不正な場合は `ArgumentError` |
| `Digest.from_base64(str)` | base64 文字列（RFC 4648、改行なし）から作る。base64 として不正な場合は `ArgumentError` |

### インスタンスメソッド

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `to_binary` | String | 生のバイト列（BINARY エンコーディング） |
| `to_hex` | String | 小文字の hex 文字列 |
| `to_base64` | String | base64 文字列（RFC 4648、改行なし） |
| `to_s` | String | `to_hex` と同じ（標準ライブラリの `Digest#to_s` に合わせる） |
| `inspect` | String | `#<CTMerkle::Digest 2cf24dba...>` の形式 |
| `bytesize` | Integer | バイト数 |
| `==(other)` | true / false | `Digest` またはバイナリ文字列と、バイト列だけで比較する（String のエンコーディングは見ない）。それ以外の値との比較は常に `false` |
| `eql?(other)` / `hash` | | `Digest` 同士でだけ等しいとみなす。Hash のキーとして使える |

`to_str` は定義しない。定義すると暗黙に String として扱われ、バイナリ文字列と hex 文字列を取り違えやすくなるため。

その結果、`String#==` は `Digest` を相手にすると常に `false` を返す。String と比較するときは `digest == str` のように `Digest` を左辺に置く。

### 引数として受け付ける値

ハッシュ値を受け取る引数（`root:`、`leaf_hash:`、`inclusion_path:` など）は、`Digest` とバイナリ文字列のどちらも受け付ける。String は常にバイト列として解釈し、hex や base64 として解釈することはない。そのため、hex 文字列をそのまま渡すと長さが合わず、検証は失敗する（`verify` は `false`、`verify!` は `MalformedProofError`）。

## 9. `CTMerkle::Verifier`

証明オブジェクトを作らずに検証するためのモジュール関数。証明オブジェクトの `verify` も内部でこれを呼ぶ。

```ruby
CTMerkle::Verifier.verify_inclusion(leaf_hash:, leaf_index:, tree_size:, inclusion_path:, root:, hasher: SHA256)
CTMerkle::Verifier.verify_consistency(old_size:, new_size:, old_root:, new_root:, consistency_path:, hasher: SHA256)

# 失敗時に例外を投げる版（証明オブジェクトの verify! が使う）
CTMerkle::Verifier.verify_inclusion!(...)
CTMerkle::Verifier.verify_consistency!(...)
```

アルゴリズムは RFC 9162 §2.1.3.2（包含証明）と §2.1.4.2（整合性証明）に従う。

`!` なしは `true` / `false` を返し、`!` つきは成功時に `true` を返して、失敗時は `MalformedProofError` または `RootMismatchError` を投げる。証明オブジェクトの `verify` / `verify!` も、同じように `hasher:` を受け取る。

ハッシュ値（葉、ルート、パスの各要素）の長さが `hasher.digest_size` と違う場合は、常に `MalformedProofError` とする。Go の `transparency-dev/merkle` は `old_size == new_size` のときに長さを確認しないため、この点だけ結果が異なる（`test/vectors_test.rb` の `DEVIATIONS` を参照）。

## 10. `CTMerkle::Hasher`

低レベル API

```ruby
CTMerkle::Hasher::SHA256.leaf(data)          # HASH(0x00 ‖ data)
CTMerkle::Hasher::SHA256.node(left, right)   # HASH(0x01 ‖ left ‖ right)
CTMerkle::Hasher::SHA256.empty_root          # HASH("")
CTMerkle::Hasher::SHA256.digest_size         # 32

CTMerkle.root(leaves)                        # 一度だけルートを計算するショートカット。Digest を返す
```

`Hasher` はツリー内部の計算で大量に呼ばれるため、引数も戻り値も `Digest` ではなくバイナリ文字列（String）とする。

ハッシュアルゴリズムを差し替える場合は、上の 4 メソッドを持つオブジェクトを `hasher:` に渡す。

## 11. `CTMerkle::Error`

当ライブラリで送出する例外

```
StandardError
├─ ArgumentError                 引数が不正（範囲外のインデックスやサイズなど）
└─ CTMerkle::Error
   └─ CTMerkle::VerificationError         verify! が失敗したとき
      ├─ CTMerkle::MalformedProofError    証明の形が不正（パスの長さが合わない、index >= tree_size など）
      └─ CTMerkle::RootMismatchError      計算したルートが期待したルートと一致しない
```

`verify` は例外を投げず、どちらの失敗でも `false` を返す。

## 12. 境界条件

| 状況 | 動作 |
|---|---|
| 空のツリーの `root` | `HASH("")` を返す |
| `inclusion_proof` で `index >= tree_size` | `ArgumentError` |
| `tree_size:` が現在のサイズより大きい、または負の値 | `ArgumentError` |
| `consistency_proof` で `old_size == 0` | `ArgumentError`（RFC では証明が定義されていないため） |
| `consistency_proof` で `old_size > tree_size` | `ArgumentError` |
| `consistency_proof` で `old_size == tree_size` | 空の証明を返す。検証は 2 つのルートが等しいかどうかだけを見る |

## 13. 未決事項

- [x] `Tree#size` を `tree_size` の別名として用意するか
 - 用意する
- [x] `index_of(leaf_hash)` と `inclusion_proof_by_hash(leaf_hash, tree_size:)` を v1 に含めるか。含める場合、同じハッシュが複数あるときは最初のインデックスを返す想定
 - 含める（同じハッシュが複数ある場合は最初のインデックス）
- [ ] 永続化のためのストレージインターフェース（`LeafStore`）を v1 で公開するか。想定するリーフ数の規模で判断する
 - 後回し（v1 はメモリ上だけで持つ。内部では差し替えられる構造にしておく）
- [x] 特定の時点のツリーを取り出す API（`tree.at(tree_size)`）を追加するか
 - 追加する（`CTMerkle::Snapshot` を返す）
- [x] hex / base64 変換の補助メソッドの名前と置き場所
 - ハッシュ値を `CTMerkle::Digest` で包み、`to_hex` / `to_base64` / `from_hex` / `from_base64` を持たせる（8 章）
- [x] 証明オブジェクトの直列化形式（JSON での表現、RFC 9162 のバイナリ形式）と `to_h` / `from_h` の仕様
 - `to_h` / `from_h` を提供し、`encoding:` の既定は `:hex`。JSON への変換と外部形式への対応は利用者側で行う（6 章）
- [x] 対応する Ruby のバージョン、RBS をつけるかどうか
 - 3.3以降
 - RBSは不要
- [x] gem 名 `ct_merkle` が rubygems.org で使われていないかの確認
 - 確認済み
