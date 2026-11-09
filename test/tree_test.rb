# frozen_string_literal: true

require_relative "test_helper"

class TreeTest < Minitest::Test
  def setup
    @tree = CTMerkle::Tree.new(TestData::LEAF_INPUTS)
  end

  def test_roots_for_every_size
    TestData::ROOT_HASHES.each_with_index do |hex, n|
      assert_equal hex, @tree.root(tree_size: n).to_hex, "tree_size=#{n}"
      assert_equal hex, CTMerkle::Tree.new(TestData::LEAF_INPUTS.first(n)).root.to_hex
    end
  end

  def test_empty_tree
    tree = CTMerkle::Tree.new
    assert_equal 0, tree.tree_size
    assert_equal TestData::ROOT_HASHES[0], tree.root.to_hex
  end

  def test_root_returns_digest
    assert_kind_of CTMerkle::Digest, @tree.root
  end

  def test_append_returns_index_and_shovel_returns_self
    tree = CTMerkle::Tree.new
    assert_equal 0, tree.append("a")
    assert_same tree, (tree << "b" << "c")
    assert_equal 3, tree.size
    assert_equal 3, tree.tree_size
  end

  def test_append_leaf_hash
    tree = CTMerkle::Tree.new
    TestData::NODE_HASHES[0].each_with_index do |hex, i|
      arg = i.even? ? CTMerkle::Digest.from_hex(hex) : TestData.hd(hex)
      assert_equal i, tree.append_leaf_hash(arg)
    end
    assert_equal TestData::ROOT_HASHES[8], tree.root.to_hex
  end

  def test_append_leaf_hash_rejects_wrong_size
    tree = CTMerkle::Tree.new
    assert_raises(ArgumentError) { tree.append_leaf_hash(TestData::NODE_HASHES[0][0]) } # hex, 64 bytes
  end

  def test_append_rejects_non_string
    assert_raises(ArgumentError) { CTMerkle::Tree.new.append(1) }
  end

  def test_leaf_hash
    TestData::NODE_HASHES[0].each_with_index do |hex, i|
      assert_equal hex, @tree.leaf_hash(i).to_hex
    end
    assert_raises(ArgumentError) { @tree.leaf_hash(8) }
    assert_raises(ArgumentError) { @tree.leaf_hash(-1) }
  end

  def test_index_of_returns_first_match
    tree = CTMerkle::Tree.new(%w[a b a])
    h = CTMerkle::Hasher::SHA256.leaf("a")
    assert_equal 0, tree.index_of(h)
    assert_equal 0, tree.index_of(CTMerkle::Digest.new(h))
    assert_nil tree.index_of(CTMerkle::Hasher::SHA256.leaf("z"))
  end

  def test_inclusion_proofs_match_reference
    (1..8).each do |n|
      n.times do |i|
        proof = @tree.inclusion_proof(i, tree_size: n)
        expected = Reference.path(i, TestData::LEAF_INPUTS.first(n))
        assert_equal expected, proof.inclusion_path.map(&:to_binary), "index=#{i} tree_size=#{n}"
        assert_equal i, proof.leaf_index
        assert_equal n, proof.tree_size
      end
    end
  end

  def test_inclusion_proof_defaults_to_current_size
    assert_equal @tree.inclusion_proof(2, tree_size: 8), @tree.inclusion_proof(2)
  end

  def test_inclusion_proof_by_hash
    h = @tree.leaf_hash(5)
    assert_equal @tree.inclusion_proof(5), @tree.inclusion_proof_by_hash(h)
    assert_equal @tree.inclusion_proof(5, tree_size: 6), @tree.inclusion_proof_by_hash(h, tree_size: 6)
    assert_nil @tree.inclusion_proof_by_hash(h, tree_size: 5)
    assert_nil @tree.inclusion_proof_by_hash(CTMerkle::Hasher::SHA256.leaf("missing"))
  end

  def test_consistency_proofs_match_reference
    (1..8).each do |n|
      (1..n).each do |m|
        proof = @tree.consistency_proof(m, tree_size: n)
        expected = Reference.proof(m, TestData::LEAF_INPUTS.first(n))
        assert_equal expected, proof.consistency_path.map(&:to_binary), "old_size=#{m} tree_size=#{n}"
        assert_equal m, proof.old_size
        assert_equal n, proof.new_size
      end
    end
  end

  def test_consistency_proof_defaults_to_current_size
    assert_equal @tree.consistency_proof(3, tree_size: 8), @tree.consistency_proof(3)
  end

  def test_consistency_proof_for_equal_sizes_is_empty
    assert_empty @tree.consistency_proof(8).consistency_path
  end

  def test_argument_errors
    assert_raises(ArgumentError) { @tree.root(tree_size: 9) }
    assert_raises(ArgumentError) { @tree.root(tree_size: -1) }
    assert_raises(ArgumentError) { @tree.inclusion_proof(8) }
    assert_raises(ArgumentError) { @tree.inclusion_proof(3, tree_size: 3) }
    assert_raises(ArgumentError) { @tree.inclusion_proof(0, tree_size: 0) }
    assert_raises(ArgumentError) { @tree.consistency_proof(0) }
    assert_raises(ArgumentError) { @tree.consistency_proof(5, tree_size: 4) }
    assert_raises(ArgumentError) { @tree.consistency_proof(1, tree_size: 9) }
    assert_raises(ArgumentError) { @tree.at(9) }
  end

  def test_proofs_are_snapshots
    proof = @tree.inclusion_proof(0)
    @tree << "more"
    assert_equal 8, proof.tree_size
    refute_equal proof, @tree.inclusion_proof(0)
  end

  def test_module_root_shortcut
    assert_equal TestData::ROOT_HASHES[8], CTMerkle.root(TestData::LEAF_INPUTS).to_hex
  end
end

# Cross-checks every root and proof against the naive reference for larger
# trees, and verifies each generated proof.
class TreeReferenceTest < Minitest::Test
  MAX = 40

  def test_all_sizes
    leaves = Array.new(MAX) { |i| "leaf-#{i}" }
    tree = CTMerkle::Tree.new(leaves)

    (1..MAX).each do |n|
      sub = leaves.first(n)
      root = Reference.mth(sub)
      assert_equal root, tree.root(tree_size: n).to_binary, "root tree_size=#{n}"

      n.times do |i|
        proof = tree.inclusion_proof(i, tree_size: n)
        assert_equal Reference.path(i, sub), proof.inclusion_path.map(&:to_binary)
        assert proof.verify(leaf_data: sub[i], root: root), "inclusion index=#{i} tree_size=#{n}"
        refute proof.verify(leaf_data: "#{sub[i]}x", root: root)
      end

      (1..n).each do |m|
        proof = tree.consistency_proof(m, tree_size: n)
        assert_equal Reference.proof(m, sub), proof.consistency_path.map(&:to_binary) if m < n
        old_root = Reference.mth(leaves.first(m))
        assert proof.verify(old_root: old_root, new_root: root), "consistency #{m}->#{n}"
        refute proof.verify(old_root: root, new_root: old_root) if m < n
      end
    end
  end
end

class SnapshotTest < Minitest::Test
  def setup
    @tree = CTMerkle::Tree.new(TestData::LEAF_INPUTS)
    @snap = @tree.at(4)
  end

  def test_delegates_with_fixed_size
    assert_equal 4, @snap.tree_size
    assert_equal 4, @snap.size
    assert_equal @tree.root(tree_size: 4), @snap.root
    assert_equal @tree.inclusion_proof(0, tree_size: 4), @snap.inclusion_proof(0)
    assert_equal @tree.consistency_proof(3, tree_size: 4), @snap.consistency_proof(3)
    assert_equal @tree.leaf_hash(3), @snap.leaf_hash(3)
  end

  def test_limits_to_its_size
    assert_raises(ArgumentError) { @snap.leaf_hash(4) }
    assert_raises(ArgumentError) { @snap.inclusion_proof(4) }
    h = @tree.leaf_hash(6)
    assert_nil @snap.index_of(h)
    assert_nil @snap.inclusion_proof_by_hash(h)
    assert_equal 1, @snap.index_of(@tree.leaf_hash(1))
  end

  def test_unchanged_after_append
    root = @snap.root
    @tree << "more"
    assert_equal root, @snap.root
    assert_equal 4, @snap.tree_size
  end
end
