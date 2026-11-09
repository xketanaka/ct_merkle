# frozen_string_literal: true

module CTMerkle
  # Proof that a leaf is included in the tree of size tree_size
  # (RFC 9162 InclusionProofDataV2 without log_id).
  InclusionProof = Data.define(:leaf_index, :tree_size, :inclusion_path) do
    def self.from_h(hash, encoding: :hex)
      h = Serialization.normalize_keys(hash, members)
      new(
        leaf_index: h[:leaf_index],
        tree_size: h[:tree_size],
        inclusion_path: Serialization.decode_path(h[:inclusion_path], encoding, "inclusion_path"),
      )
    end

    def initialize(leaf_index:, tree_size:, inclusion_path:)
      raise ArgumentError, "leaf_index must be an Integer, got #{leaf_index.class}" unless leaf_index.is_a?(Integer)
      raise ArgumentError, "tree_size must be an Integer, got #{tree_size.class}" unless tree_size.is_a?(Integer)
      raise ArgumentError, "inclusion_path must be an Array, got #{inclusion_path.class}" unless inclusion_path.is_a?(Array)

      path = inclusion_path.each_with_index.map { |h, i| Digest.wrap(h, "inclusion_path[#{i}]") }.freeze
      super(leaf_index: leaf_index, tree_size: tree_size, inclusion_path: path)
    end

    # Exactly one of leaf_data: or leaf_hash: must be given.
    def verify(root:, leaf_data: nil, leaf_hash: nil, hasher: Hasher::SHA256)
      verify!(root: root, leaf_data: leaf_data, leaf_hash: leaf_hash, hasher: hasher)
    rescue VerificationError
      false
    end

    def verify!(root:, leaf_data: nil, leaf_hash: nil, hasher: Hasher::SHA256)
      if leaf_data.nil? == leaf_hash.nil?
        raise ArgumentError, "specify exactly one of leaf_data: or leaf_hash:"
      end

      unless leaf_data.nil? || leaf_data.is_a?(String)
        raise ArgumentError, "leaf_data must be a String, got #{leaf_data.class}"
      end

      Verifier.verify_inclusion!(
        leaf_hash: leaf_hash || hasher.leaf(leaf_data),
        leaf_index: leaf_index,
        tree_size: tree_size,
        inclusion_path: inclusion_path,
        root: root,
        hasher: hasher,
      )
    end

    def to_h(encoding: :hex)
      {
        leaf_index: leaf_index,
        tree_size: tree_size,
        inclusion_path: inclusion_path.map { |d| Serialization.encode(d, encoding) },
      }
    end
  end
end
