# frozen_string_literal: true

module CTMerkle
  # A read-only view of a Tree at a fixed tree size, returned by Tree#at.
  #
  # The tree is append-only, so appending to the original Tree does not change
  # what a Snapshot returns.
  class Snapshot
    attr_reader :tree_size
    alias size tree_size

    # Use Tree#at instead of calling this directly.
    def initialize(tree, tree_size)
      @tree = tree
      @tree_size = tree_size
      freeze
    end

    def root
      @tree.root(tree_size: @tree_size)
    end

    def leaf_hash(index)
      check_index!(index)
      @tree.leaf_hash(index)
    end

    def index_of(leaf_hash)
      index = @tree.index_of(leaf_hash)
      index if index && index < @tree_size
    end

    def inclusion_proof(index)
      @tree.inclusion_proof(index, tree_size: @tree_size)
    end

    def inclusion_proof_by_hash(leaf_hash)
      @tree.inclusion_proof_by_hash(leaf_hash, tree_size: @tree_size)
    end

    def consistency_proof(old_size)
      @tree.consistency_proof(old_size, tree_size: @tree_size)
    end

    def inspect
      "#<#{self.class.name} tree_size=#{@tree_size}>"
    end

    private

    def check_index!(index)
      raise ArgumentError, "index must be an Integer, got #{index.class}" unless index.is_a?(Integer)
      return if index.between?(0, @tree_size - 1)

      raise ArgumentError, "index must be between 0 and #{@tree_size - 1}, got #{index}"
    end
  end
end
