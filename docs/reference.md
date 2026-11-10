# ct_merkle API リファレンス

## 目次

- [CTMerkle](#ctmerkle)
- [CTMerkle::Tree](#ctmerkletree)
- [CTMerkle::Snapshot](#ctmerklesnapshot)
- [CTMerkle::InclusionProof](#ctmerkleinclusionproof)
- [CTMerkle::ConsistencyProof](#ctmerkleconsistencyproof)
- [CTMerkle::Digest](#ctmerkledigest)
- [CTMerkle::Verifier](#ctmerkleverifier)
- [CTMerkle::Hasher::SHA256](#ctmerklehashersha256)
- [例外](#例外)

## 共通仕様

### 引数のハッシュ値

ハッシュ値を受け取る引数には `CTMerkle::Digest` またはバイト列の String を指定する

- String はエンコーディングに関係なくバイト列として扱う。hex や base64 の指定は不可
- それ以外の型を渡すと `ArgumentError` になる
- 長さがハッシュ関数の出力長（SHA-256 なら 32 バイト）と違う場合の扱いは、メソッドごとに記載する

### 戻り値のハッシュ値

ハッシュ値を返すメソッドは `CTMerkle::Digest` を返す(ただし `CTMerkle::Hasher` を除く)

### ハッシュアルゴリズム

ハッシュアルゴリズム(`hasher:`)を受け取るメソッドのデフォルト値は `CTMerkle::Hasher::SHA256` である。
独自のハッシュ関数を使う場合は、[CTMerkle::Hasher::SHA256](#ctmerklehashersha256) と同じメソッドを持つオブジェクトを指定する。

---

## CTMerkle

### `CTMerkle.root(leaves, hasher: Hasher::SHA256)` → `Digest`

生データの配列からツリーを作り、そのルートハッシュを返す。`CTMerkle::Tree.new(leaves, hasher: hasher).root` と同じ。

### `CTMerkle::VERSION`

gem のバージョン文字列。

---

## CTMerkle::Tree

追記専用のマークルツリー。葉はメモリ上に持つ。スレッドセーフではない。

```ruby
tree = CTMerkle::Tree.new(["a", "b", "c"])
tree << "d"
tree.root                        # => #<CTMerkle::Digest ...>
tree.inclusion_proof(0)          # => #<data CTMerkle::InclusionProof ...>
tree.consistency_proof(2)        # => #<data CTMerkle::ConsistencyProof ...>
```

### `Tree.new(leaves = [], hasher: Hasher::SHA256)`

ツリーを作る。`leaves` の各要素を、先頭から順に `append` する。

- `leaves`：生データ（String）の配列。String 以外の要素があると `ArgumentError`

### `#append(data)` → Integer

生データを葉として追加し、その葉のインデックスを返す。リーフハッシュ `HASH(0x00 ‖ data)` はこのメソッドの中で計算する。

- `data`：String。テキストでもバイナリでもよく、バイト列をそのままハッシュする（エンコーディングの変換はしない）
- String 以外を渡すと `ArgumentError`

計算済みのリーフハッシュを渡すと、それをデータとしてもう一度ハッシュしてしまう。リーフハッシュを追加するときは `append_leaf_hash` を使う。

### `#<<(data)` → self

`append` と同じ。`tree << "a" << "b"` のようにつなげて書けるよう、`self` を返す。

### `#append_leaf_hash(leaf_hash)` → Integer

計算済みのリーフハッシュを、そのまま葉として追加し、その葉のインデックスを返す。

- `leaf_hash`：`Digest` またはバイト列の String
- 長さが `hasher.digest_size` と違う場合は `ArgumentError`
- そのハッシュが `HASH(0x00 ‖ data)` の形で計算されたものかどうかは確認しない

### `#tree_size` → Integer

現在の葉の数。

### `#size` → Integer

`tree_size` の別名。

### `#hasher` → Object

このツリーが使っているハッシュ関数。

### `#root(tree_size: self.tree_size)` → `Digest`

指定したサイズの時点のルートハッシュを返す。サイズが 0 のときは空のツリーのルート `HASH("")` を返す。

- `tree_size` が Integer でない場合、または `0..self.tree_size` の範囲外の場合は `ArgumentError`

### `#leaf_hash(index)` → `Digest`

指定したインデックスの葉のリーフハッシュを返す。

- `index` が Integer でない場合、または `0...tree_size` の範囲外の場合は `ArgumentError`（負のインデックスで後ろから数えることはできない）

### `#index_of(leaf_hash)` → Integer / nil

指定したリーフハッシュを持つ葉のインデックスを返す。同じハッシュの葉が複数ある場合は、最初の（いちばん小さい）インデックスを返す。見つからなければ `nil` を返す。

- `leaf_hash`：`Digest` またはバイト列の String。長さが `hasher.digest_size` と違う場合は `ArgumentError`

### `#at(tree_size)` → `Snapshot`

指定したサイズの時点のツリーを、読み取り専用の `Snapshot` として返す。

- `tree_size` が `0..self.tree_size` の範囲外の場合は `ArgumentError`

### `#inclusion_proof(index, tree_size: self.tree_size)` → `InclusionProof`

サイズ `tree_size` の時点のツリーについて、`index` の葉の包含証明を返す（RFC 9162 §2.1.3.1 の `PATH`）。

- `tree_size` が `0..self.tree_size` の範囲外の場合は `ArgumentError`
- `index` が `0...tree_size` の範囲外の場合は `ArgumentError`（`tree_size` が 0 のときは常に `ArgumentError`）

返した証明は、その時点の値である。そのあとでツリーに追記しても、証明の中身は変わらない。

### `#inclusion_proof_by_hash(leaf_hash, tree_size: self.tree_size)` → `InclusionProof` / nil

`index_of(leaf_hash)` で見つけた葉について、`inclusion_proof` を返す。RFC 6962 の `get-proof-by-hash` に相当する。

- 該当する葉がない場合、または見つかったインデックスが `tree_size` 以上の場合は `nil`
- 引数の誤りは `index_of` / `inclusion_proof` と同じく `ArgumentError`

### `#consistency_proof(old_size, tree_size: self.tree_size)` → `ConsistencyProof`

サイズ `old_size` のツリーから、サイズ `tree_size` のツリーへの整合性証明を返す（RFC 9162 §2.1.4.1 の `PROOF`）。返す証明の `new_size` は `tree_size` である。

- `old_size == tree_size` の場合は、`consistency_path` が空の証明を返す
- `old_size` が Integer でない場合、1 未満の場合、`tree_size` より大きい場合は `ArgumentError`（サイズ 0 のツリーからの整合性証明は RFC で定義されていない）
- `tree_size` が `0..self.tree_size` の範囲外の場合は `ArgumentError`

---

## CTMerkle::Snapshot

`Tree#at` が返す、特定のサイズの時点のツリー。読み取り専用で、frozen である。直接 `new` せず、`Tree#at` で作る。

元の `Tree` を参照しているだけなので、作るときにツリーのコピーはしない。ツリーは追記しかできないので、`Snapshot` を作ったあとで元の `Tree` に追記しても、`Snapshot` が返す値は変わらない。

```ruby
snap = tree.at(4)
snap.root                    # tree.root(tree_size: 4) と同じ
snap.inclusion_proof(0)      # tree.inclusion_proof(0, tree_size: 4) と同じ
snap.consistency_proof(3)    # tree.consistency_proof(3, tree_size: 4) と同じ
```

| メソッド | 戻り値 | 同じ意味の `Tree` の呼び出し |
|---|---|---|
| `tree_size` / `size` | Integer | — |
| `root` | `Digest` | `tree.root(tree_size: n)` |
| `leaf_hash(index)` | `Digest` | `tree.leaf_hash(index)`。ただし `index >= n` なら `ArgumentError` |
| `index_of(leaf_hash)` | Integer / nil | `tree.index_of(leaf_hash)`。ただし見つかったインデックスが `n` 以上なら `nil` |
| `inclusion_proof(index)` | `InclusionProof` | `tree.inclusion_proof(index, tree_size: n)` |
| `inclusion_proof_by_hash(leaf_hash)` | `InclusionProof` / nil | `tree.inclusion_proof_by_hash(leaf_hash, tree_size: n)` |
| `consistency_proof(old_size)` | `ConsistencyProof` | `tree.consistency_proof(old_size, tree_size: n)` |

（`n` はこの `Snapshot` の `tree_size`）

---

## CTMerkle::InclusionProof

包含証明を表す値オブジェクト。`Data` のサブクラスで、frozen である。`==`、`eql?`、`hash`、`with` は `Data` のものを使える。

### `InclusionProof.new(leaf_index:, tree_size:, inclusion_path:)`

- `leaf_index`：Integer
- `tree_size`：Integer
- `inclusion_path`：ハッシュ値の配列。各要素は `Digest` に変換して保持する

型が違う場合は `ArgumentError` とする。値の範囲（`leaf_index < tree_size` など）、パスの長さ、ハッシュの長さは、作るときには確認しない。外部から受け取ったデータからも証明を組み立てられるようにするためで、これらは検証のときに確認する。

### `InclusionProof.from_h(hash, encoding: :hex)` → `InclusionProof`

`to_h` が返した形式の Hash から証明を作る。

- キーはシンボルでも文字列でもよい（`JSON.parse` の結果をそのまま渡せる）
- `inclusion_path` の各要素は、`encoding:` に従った文字列として解釈する
- 次の場合は `ArgumentError`：
  - `hash` が Hash でない
  - 必要なキーがない、または未知のキーがある
  - 同じキーがシンボルと文字列の両方で入っている
  - `encoding:` が `:hex` / `:base64` 以外
  - ハッシュ値の文字列が、`encoding:` の形式として不正

### 属性

| 属性 | 型 | 説明 |
|---|---|---|
| `leaf_index` | Integer | 葉のインデックス |
| `tree_size` | Integer | 基準となるツリーのサイズ |
| `inclusion_path` | Array<`Digest`> | 証明に使うハッシュの配列（frozen）。RFC 6962 での audit path |

### `#verify(root:, leaf_data: nil, leaf_hash: nil, hasher: Hasher::SHA256)` → true / false

証明を検証し、成功すれば `true`、失敗すれば `false` を返す。

- `leaf_data:`（生データの String）と `leaf_hash:`（リーフハッシュ）は、どちらか一方だけを指定する。両方指定した場合や、どちらも指定しない場合は `ArgumentError`
- `leaf_data:` を指定した場合は、`hasher.leaf(leaf_data)` をリーフハッシュとして使う
- 検証の詳細は [CTMerkle::Verifier](#ctmerkleverifier) の `verify_inclusion!` を参照

### `#verify!(root:, leaf_data: nil, leaf_hash: nil, hasher: Hasher::SHA256)` → true

`verify` と同じだが、失敗した場合は `MalformedProofError` または `RootMismatchError` を投げる。

### `#to_h(encoding: :hex)` → Hash

証明を Hash に変換する。キーは属性名のシンボルで、ハッシュ値は `encoding:` に従った文字列になる。

```ruby
proof.to_h
# => { leaf_index: 2, tree_size: 5, inclusion_path: ["d5bdb58a...", "718fa036...", "8e1f887c..."] }
proof.to_h(encoding: :base64)
# => { leaf_index: 2, tree_size: 5, inclusion_path: ["1b21ihkX...", "cY+gNp10...", "jh+IfPx8..."] }
```

- `encoding:`：`:hex`（小文字）または `:base64`（RFC 4648、改行なし）。それ以外は `ArgumentError`
- `InclusionProof.from_h(proof.to_h(encoding: e), encoding: e) == proof` が成り立つ
- この形式は ct_merkle 独自のもので、同じメジャーバージョンの間は互換性を保つ

---

## CTMerkle::ConsistencyProof

整合性証明を表す値オブジェクト。`Data` のサブクラスで、frozen である。`==`、`eql?`、`hash`、`with` は `Data` のものを使える。

### `ConsistencyProof.new(old_size:, new_size:, consistency_path:)`

- `old_size`：Integer
- `new_size`：Integer
- `consistency_path`：ハッシュ値の配列。各要素は `Digest` に変換して保持する

型が違う場合は `ArgumentError` とする。値の範囲やパスの長さは、作るときには確認せず、検証のときに確認する。

### `ConsistencyProof.from_h(hash, encoding: :hex)` → `ConsistencyProof`

`InclusionProof.from_h` と同じ規則で、`to_h` が返した形式の Hash から証明を作る。

### 属性

| 属性 | 型 | 説明 |
|---|---|---|
| `old_size` | Integer | 古いツリーのサイズ（RFC 9162 の `tree_size_1`） |
| `new_size` | Integer | 新しいツリーのサイズ（RFC 9162 の `tree_size_2`） |
| `consistency_path` | Array<`Digest`> | 証明に使うハッシュの配列（frozen） |

### `#verify(old_root:, new_root:, hasher: Hasher::SHA256)` → true / false

証明を検証し、成功すれば `true`、失敗すれば `false` を返す。検証の詳細は [CTMerkle::Verifier](#ctmerkleverifier) の `verify_consistency!` を参照。

### `#verify!(old_root:, new_root:, hasher: Hasher::SHA256)` → true

`verify` と同じだが、失敗した場合は `MalformedProofError` または `RootMismatchError` を投げる。

### `#to_h(encoding: :hex)` → Hash

`{ old_size:, new_size:, consistency_path: }` の形の Hash に変換する。規則は `InclusionProof#to_h` と同じ。

---

## CTMerkle::Digest

ハッシュ値を表す値オブジェクト。中身は BINARY エンコーディングのバイト列で、frozen である。

```ruby
d = CTMerkle::Digest.from_hex("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
d.to_hex       # => "2cf24dba..."
d.to_base64    # => "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ="
d.bytesize     # => 32
p d            # => #<CTMerkle::Digest 2cf24dba...>
```

### `Digest.new(bytes)`

バイト列から作る。エンコーディングに関係なく、BINARY のコピーとして保持する。

- `bytes` が String でない場合は `ArgumentError`
- 長さは確認しない

### `Digest.from_hex(str)` → `Digest`

hex 文字列から作る。大文字・小文字のどちらでもよい。

- `str` が String でない場合、または hex として不正な場合（奇数桁、hex 以外の文字、空白を含むなど）は `ArgumentError`

### `Digest.from_base64(str)` → `Digest`

base64 文字列（RFC 4648、改行なし、パディングあり）から作る。

- `str` が String でない場合、または base64 として不正な場合（改行を含む、パディングがないなど）は `ArgumentError`

### インスタンスメソッド

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `to_binary` | String | 生のバイト列（BINARY エンコーディング、frozen） |
| `to_hex` | String | 小文字の hex 文字列 |
| `to_base64` | String | base64 文字列（RFC 4648、改行なし） |
| `to_s` | String | `to_hex` と同じ |
| `inspect` | String | `#<CTMerkle::Digest 2cf24dba...>` の形式（hex は省略せずに全桁を表示） |
| `bytesize` | Integer | バイト数 |
| `==(other)` | true / false | `other` が `Digest` または String の場合は、バイト列だけで比較する（String のエンコーディングは見ない）。それ以外は常に `false` |
| `eql?(other)` | true / false | `other` が `Digest` で、バイト列が同じ場合だけ `true` |
| `hash` | Integer | `eql?` と一貫したハッシュ値。`Digest` を Hash のキーに使える |

`to_str` は定義していない。そのため、`String#==` は `Digest` と比較すると常に `false` を返す。String と比較するときは、`digest == str` のように `Digest` を左辺に置く。

---

## CTMerkle::Verifier

証明オブジェクトを作らずに、値を直接渡して検証するためのモジュール関数。証明オブジェクトの `verify` / `verify!` も、内部でこれを呼んでいる。

### `Verifier.verify_inclusion(leaf_hash:, leaf_index:, tree_size:, inclusion_path:, root:, hasher: Hasher::SHA256)` → true / false

`verify_inclusion!` を呼び、成功すれば `true`、`VerificationError` が発生すれば `false` を返す。`ArgumentError` はそのまま投げる。

### `Verifier.verify_inclusion!(leaf_hash:, leaf_index:, tree_size:, inclusion_path:, root:, hasher: Hasher::SHA256)` → true

RFC 9162 §2.1.3.2 の手順で包含証明を検証する。

| 状況 | 結果 |
|---|---|
| `leaf_index` または `tree_size` が Integer でない | `ArgumentError` |
| `inclusion_path` が Array でない | `ArgumentError` |
| ハッシュ値の引数が `Digest` / String でない | `ArgumentError` |
| `leaf_hash`、`root`、`inclusion_path` の要素の長さが `hasher.digest_size` と違う | `MalformedProofError` |
| `leaf_index` または `tree_size` が負 | `MalformedProofError` |
| `leaf_index >= tree_size` | `MalformedProofError` |
| `inclusion_path` が長すぎる、または短すぎる | `MalformedProofError` |
| 計算したルートが `root` と一致しない | `RootMismatchError` |
| 上のどれにも当てはまらない | `true` |

### `Verifier.verify_consistency(old_size:, new_size:, old_root:, new_root:, consistency_path:, hasher: Hasher::SHA256)` → true / false

`verify_consistency!` を呼び、成功すれば `true`、`VerificationError` が発生すれば `false` を返す。`ArgumentError` はそのまま投げる。

### `Verifier.verify_consistency!(old_size:, new_size:, old_root:, new_root:, consistency_path:, hasher: Hasher::SHA256)` → true

RFC 9162 §2.1.4.2 の手順で整合性証明を検証する。

| 状況 | 結果 |
|---|---|
| `old_size` または `new_size` が Integer でない | `ArgumentError` |
| `consistency_path` が Array でない | `ArgumentError` |
| ハッシュ値の引数が `Digest` / String でない | `ArgumentError` |
| `old_root`、`new_root`、`consistency_path` の要素の長さが `hasher.digest_size` と違う | `MalformedProofError` |
| `old_size` または `new_size` が負 | `MalformedProofError` |
| `old_size > new_size` | `MalformedProofError` |
| `old_size == 0` | `MalformedProofError` |
| `old_size == new_size` で、`consistency_path` が空でない | `MalformedProofError` |
| `old_size == new_size` で、`old_root` と `new_root` が違う | `RootMismatchError` |
| `old_size < new_size` で、`consistency_path` が空 | `MalformedProofError` |
| `consistency_path` が長すぎる、または短すぎる | `MalformedProofError` |
| 計算した古いルートが `old_root` と、または新しいルートが `new_root` と一致しない | `RootMismatchError` |
| 上のどれにも当てはまらない | `true` |

ハッシュの長さを常に確認するため、transparency-dev/merkle（Go）とは 1 つのケースで結果が異なる。`old_size == new_size` でルートの長さが正しくない場合、Go は成功とするが、ct_merkle は `MalformedProofError` とする。

---

## CTMerkle::Hasher::SHA256

RFC 6962 / RFC 9162 の SHA-256 によるハッシュ関数。ツリーの計算で大量に呼ばれるため、引数も戻り値も `Digest` ではなく、バイナリの String とする。

| メソッド | 戻り値 | 説明 |
|---|---|---|
| `leaf(data)` | String | `SHA-256(0x00 ‖ data)`。`data` はバイト列としてハッシュする |
| `node(left, right)` | String | `SHA-256(0x01 ‖ left ‖ right)` |
| `empty_root` | String | `SHA-256("")`。空のツリーのルート（frozen） |
| `digest_size` | Integer | `32` |

戻り値はすべて BINARY エンコーディングである。

### 独自のハッシュ関数

`hasher:` 引数には、上の 4 つのメソッドを同じ意味で持つオブジェクトを渡せる。`digest_size` は、引数のハッシュ値の長さの確認に使う。

---

## 例外

```
StandardError
├─ ArgumentError                         引数の型や範囲が不正
└─ CTMerkle::Error                       このライブラリの例外の基底クラス
   └─ CTMerkle::VerificationError        verify! / Verifier.verify_*! が失敗した
      ├─ CTMerkle::MalformedProofError   証明の形が不正
      └─ CTMerkle::RootMismatchError     計算したルートが期待したルートと一致しない
```

- 呼び出し方の誤り（型が違う、範囲外のインデックスやサイズを指定したなど）は `ArgumentError` とする。`verify` でも `false` にはならず、例外になる
- 証明の検証の失敗は `VerificationError` のサブクラスで表す。`verify` は `false` を返し、`verify!` は例外を投げる
