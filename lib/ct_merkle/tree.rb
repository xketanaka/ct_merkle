# frozen_string_literal: true

module CTMerkle
  # An append-only Merkle tree (RFC 6962 / RFC 9162 §2.1), held in memory.
  #
  # Every complete subtree hash is cached as leaves are appended, so the root
  # and proofs for any past tree size are computed in O(log n).
  class Tree
    attr_reader :hasher

    def initialize(leaves = [], hasher: Hasher::SHA256)
      @hasher = hasher
      # @levels[l][i] is the hash of the complete subtree that covers
      # leaves [i * 2**l, (i + 1) * 2**l). @levels[0] holds the leaf hashes.
      @levels = [[]]
      @index = {}
      leaves.each { |data| append(data) }
    end

    # Appends raw leaf data and returns the index of the new leaf.
    def append(data)
      raise ArgumentError, "leaf data must be a String, got #{data.class}" unless data.is_a?(String)

      add_leaf_hash(@hasher.leaf(data).freeze)
    end

    def <<(data)
      append(data)
      self
    end

    # Appends an already computed leaf hash and returns the index of the new leaf.
    def append_leaf_hash(leaf_hash)
      add_leaf_hash(leaf_hash_bytes(leaf_hash))
    end

    def tree_size
      @levels[0].size
    end
    alias size tree_size

    def root(tree_size: self.tree_size)
      check_tree_size!(tree_size)
      Digest.new(tree_size.zero? ? @hasher.empty_root : subtree_hash(0, tree_size))
    end

    def leaf_hash(index)
      check_index!(index, tree_size)
      Digest.new(@levels[0][index])
    end

    # Index of the first leaf whose hash is leaf_hash, or nil.
    def index_of(leaf_hash)
      @index[leaf_hash_bytes(leaf_hash)]
    end

    def at(tree_size)
      check_tree_size!(tree_size)
      Snapshot.new(self, tree_size)
    end

    def inclusion_proof(index, tree_size: self.tree_size)
      check_tree_size!(tree_size)
      check_index!(index, tree_size)
      path = audit_path(index, 0, tree_size).map { |h| Digest.new(h) }
      InclusionProof.new(leaf_index: index, tree_size: tree_size, inclusion_path: path)
    end

    # Inclusion proof for the first leaf whose hash is leaf_hash, or nil when no
    # such leaf exists in the tree of size tree_size.
    def inclusion_proof_by_hash(leaf_hash, tree_size: self.tree_size)
      check_tree_size!(tree_size)
      index = index_of(leaf_hash)
      return nil if index.nil? || index >= tree_size

      inclusion_proof(index, tree_size: tree_size)
    end

    def consistency_proof(old_size, tree_size: self.tree_size)
      check_tree_size!(tree_size)
      raise ArgumentError, "old_size must be an Integer, got #{old_size.class}" unless old_size.is_a?(Integer)
      raise ArgumentError, "old_size must be positive, got #{old_size}" unless old_size.positive?
      if old_size > tree_size
        raise ArgumentError, "old_size (#{old_size}) must not exceed tree_size (#{tree_size})"
      end

      path = old_size == tree_size ? [] : subproof(old_size, 0, tree_size, true)
      ConsistencyProof.new(old_size: old_size, new_size: tree_size,
                           consistency_path: path.map { |h| Digest.new(h) })
    end

    def inspect
      "#<#{self.class.name} tree_size=#{tree_size}>"
    end

    private

    def add_leaf_hash(bytes)
      index = @levels[0].size
      @levels[0] << bytes
      @index[bytes] = index unless @index.key?(bytes)

      # Cache every complete subtree that this leaf closes.
      level = 0
      i = index
      while i.odd?
        @levels[level + 1] ||= []
        @levels[level + 1] << @hasher.node(@levels[level][i - 1], @levels[level][i]).freeze
        level += 1
        i >>= 1
      end
      index
    end

    # MTH(D[start:finish]). The ranges produced by the RFC 6962 recursion start
    # at a multiple of the largest power of two that fits, so complete
    # subtrees can be looked up directly.
    def subtree_hash(start, finish)
      n = finish - start
      if n.nobits?(n - 1) # power of two: a cached complete subtree
        level = n.bit_length - 1
        return @levels[level][start >> level]
      end

      k = largest_power_of_two_below(n)
      @hasher.node(subtree_hash(start, start + k), subtree_hash(start + k, finish))
    end

    # PATH(m, D[start:finish]) from RFC 9162 §2.1.3.1.
    def audit_path(m, start, finish)
      n = finish - start
      return [] if n == 1

      k = largest_power_of_two_below(n)
      if m < k
        audit_path(m, start, start + k) << subtree_hash(start + k, finish)
      else
        audit_path(m - k, start + k, finish) << subtree_hash(start, start + k)
      end
    end

    # SUBPROOF(m, D[start:finish], b) from RFC 9162 §2.1.4.1.
    def subproof(m, start, finish, complete)
      n = finish - start
      if m == n
        return complete ? [] : [subtree_hash(start, finish)]
      end

      k = largest_power_of_two_below(n)
      if m <= k
        subproof(m, start, start + k, complete) << subtree_hash(start + k, finish)
      else
        subproof(m - k, start + k, finish, false) << subtree_hash(start, start + k)
      end
    end

    # The largest power of two smaller than n (n > 1).
    def largest_power_of_two_below(n)
      1 << ((n - 1).bit_length - 1)
    end

    def leaf_hash_bytes(leaf_hash)
      bytes = Digest.bytes_of(leaf_hash, "leaf_hash")
      unless bytes.bytesize == @hasher.digest_size
        raise ArgumentError, "leaf_hash must be #{@hasher.digest_size} bytes, got #{bytes.bytesize}"
      end

      bytes
    end

    def check_tree_size!(tree_size)
      raise ArgumentError, "tree_size must be an Integer, got #{tree_size.class}" unless tree_size.is_a?(Integer)
      return if tree_size.between?(0, self.tree_size)

      raise ArgumentError, "tree_size must be between 0 and #{self.tree_size}, got #{tree_size}"
    end

    def check_index!(index, tree_size)
      raise ArgumentError, "index must be an Integer, got #{index.class}" unless index.is_a?(Integer)
      return if index.between?(0, tree_size - 1)

      raise ArgumentError, "index must be between 0 and #{tree_size - 1}, got #{index}"
    end
  end
end
