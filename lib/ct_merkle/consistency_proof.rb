# frozen_string_literal: true

module CTMerkle
  # Proof that the tree of size old_size is a prefix of the tree of size
  # new_size (RFC 9162 ConsistencyProofDataV2 without log_id).
  ConsistencyProof = Data.define(:old_size, :new_size, :consistency_path) do
    def self.from_h(hash, encoding: :hex)
      h = Serialization.normalize_keys(hash, members)
      new(
        old_size: h[:old_size],
        new_size: h[:new_size],
        consistency_path: Serialization.decode_path(h[:consistency_path], encoding, "consistency_path"),
      )
    end

    def initialize(old_size:, new_size:, consistency_path:)
      raise ArgumentError, "old_size must be an Integer, got #{old_size.class}" unless old_size.is_a?(Integer)
      raise ArgumentError, "new_size must be an Integer, got #{new_size.class}" unless new_size.is_a?(Integer)
      unless consistency_path.is_a?(Array)
        raise ArgumentError, "consistency_path must be an Array, got #{consistency_path.class}"
      end

      path = consistency_path.each_with_index.map { |h, i| Digest.wrap(h, "consistency_path[#{i}]") }.freeze
      super(old_size: old_size, new_size: new_size, consistency_path: path)
    end

    def verify(old_root:, new_root:, hasher: Hasher::SHA256)
      verify!(old_root: old_root, new_root: new_root, hasher: hasher)
    rescue VerificationError
      false
    end

    def verify!(old_root:, new_root:, hasher: Hasher::SHA256)
      Verifier.verify_consistency!(
        old_size: old_size,
        new_size: new_size,
        old_root: old_root,
        new_root: new_root,
        consistency_path: consistency_path,
        hasher: hasher,
      )
    end

    def to_h(encoding: :hex)
      {
        old_size: old_size,
        new_size: new_size,
        consistency_path: consistency_path.map { |d| Serialization.encode(d, encoding) },
      }
    end
  end
end
