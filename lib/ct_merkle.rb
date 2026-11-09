# frozen_string_literal: true

require_relative "ct_merkle/version"
require_relative "ct_merkle/errors"
require_relative "ct_merkle/hasher"
require_relative "ct_merkle/digest"
require_relative "ct_merkle/serialization"
require_relative "ct_merkle/verifier"
require_relative "ct_merkle/inclusion_proof"
require_relative "ct_merkle/consistency_proof"
require_relative "ct_merkle/tree"
require_relative "ct_merkle/snapshot"

# RFC 6962 / RFC 9162 Merkle trees.
module CTMerkle
  # Computes the root of a tree built from leaves (raw data) in one call.
  def self.root(leaves, hasher: Hasher::SHA256)
    Tree.new(leaves, hasher: hasher).root
  end
end
