# frozen_string_literal: true

require "digest"

module CTMerkle
  # Hashing strategies. A hasher responds to #leaf, #node, #empty_root and
  # #digest_size, and works on binary Strings (not CTMerkle::Digest) because it
  # is called for every node of the tree.
  module Hasher
    # The RFC 6962 / RFC 9162 hashing strategy with SHA-256.
    module SHA256
      LEAF_PREFIX = "\x00".b.freeze
      NODE_PREFIX = "\x01".b.freeze
      EMPTY_ROOT = ::Digest::SHA256.digest("").freeze

      module_function

      # HASH(0x00 || data)
      def leaf(data)
        d = ::Digest::SHA256.new
        d.update(LEAF_PREFIX)
        d.update(data)
        d.digest
      end

      # HASH(0x01 || left || right)
      def node(left, right)
        d = ::Digest::SHA256.new
        d.update(NODE_PREFIX)
        d.update(left)
        d.update(right)
        d.digest
      end

      # HASH("") — the root of an empty tree.
      def empty_root
        EMPTY_ROOT
      end

      def digest_size
        32
      end
    end
  end
end
