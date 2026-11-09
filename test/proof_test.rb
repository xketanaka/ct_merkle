# frozen_string_literal: true

require_relative "test_helper"

class InclusionProofTest < Minitest::Test
  def setup
    @tree = CTMerkle::Tree.new(TestData::LEAF_INPUTS)
    @proof = @tree.inclusion_proof(2, tree_size: 6)
    @root = @tree.root(tree_size: 6)
  end

  def test_verify_with_leaf_data_or_leaf_hash
    assert @proof.verify(leaf_data: TestData::LEAF_INPUTS[2], root: @root)
    assert @proof.verify(leaf_hash: @tree.leaf_hash(2), root: @root)
    assert @proof.verify(leaf_hash: @tree.leaf_hash(2).to_binary, root: @root.to_binary)
    assert @proof.verify!(leaf_hash: @tree.leaf_hash(2), root: @root)
  end

  def test_verify_failures
    refute @proof.verify(leaf_hash: @tree.leaf_hash(3), root: @root)
    assert_raises(CTMerkle::RootMismatchError) { @proof.verify!(leaf_hash: @tree.leaf_hash(3), root: @root) }
    # A hex string is interpreted as bytes, so its length is wrong.
    assert_raises(CTMerkle::MalformedProofError) { @proof.verify!(leaf_hash: @tree.leaf_hash(2).to_hex, root: @root) }
    short = @proof.with(inclusion_path: @proof.inclusion_path[0...-1])
    assert_raises(CTMerkle::MalformedProofError) { short.verify!(leaf_hash: @tree.leaf_hash(2), root: @root) }
    long = @proof.with(inclusion_path: @proof.inclusion_path + [@root])
    assert_raises(CTMerkle::MalformedProofError) { long.verify!(leaf_hash: @tree.leaf_hash(2), root: @root) }
  end

  def test_leaf_data_and_leaf_hash_are_exclusive
    assert_raises(ArgumentError) { @proof.verify(root: @root) }
    assert_raises(ArgumentError) { @proof.verify(leaf_data: "x", leaf_hash: @tree.leaf_hash(2), root: @root) }
  end

  def test_frozen_value_object
    assert_predicate @proof, :frozen?
    assert_predicate @proof.inclusion_path, :frozen?
    assert(@proof.inclusion_path.all?(CTMerkle::Digest))
  end

  def test_new_accepts_binary_strings
    path = @proof.inclusion_path.map(&:to_binary)
    assert_equal @proof, CTMerkle::InclusionProof.new(leaf_index: 2, tree_size: 6, inclusion_path: path)
  end

  def test_new_rejects_invalid_arguments
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.new(leaf_index: "2", tree_size: 6, inclusion_path: []) }
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.new(leaf_index: 2, tree_size: 6, inclusion_path: nil) }
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.new(leaf_index: 2, tree_size: 6, inclusion_path: [1]) }
  end

  def test_to_h
    h = @proof.to_h
    assert_equal %i[leaf_index tree_size inclusion_path], h.keys
    assert_equal @proof.inclusion_path.map(&:to_hex), h[:inclusion_path]
    assert_equal @proof.inclusion_path.map(&:to_base64), @proof.to_h(encoding: :base64)[:inclusion_path]
    assert_raises(ArgumentError) { @proof.to_h(encoding: :binary) }
    assert_raises(ArgumentError) { @proof.to_h(encoding: nil) }
  end

  def test_round_trip_through_json
    %i[hex base64].each do |e|
      json = JSON.generate(@proof.to_h(encoding: e))
      assert_equal @proof, CTMerkle::InclusionProof.from_h(JSON.parse(json), encoding: e)
    end
    assert_equal @proof, CTMerkle::InclusionProof.from_h(@proof.to_h)
  end

  def test_from_h_errors
    h = @proof.to_h
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.from_h(h.except(:tree_size)) }
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.from_h(h.merge(extra: 1)) }
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.from_h(h.merge(inclusion_path: ["%%"]), encoding: :base64) }
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.from_h(h.merge(inclusion_path: ["zz"])) }
    assert_raises(ArgumentError) { CTMerkle::InclusionProof.from_h(h.merge("tree_size" => 6)) }
  end
end

class ConsistencyProofTest < Minitest::Test
  def setup
    @tree = CTMerkle::Tree.new(TestData::LEAF_INPUTS)
    @proof = @tree.consistency_proof(3, tree_size: 7)
    @old_root = @tree.root(tree_size: 3)
    @new_root = @tree.root(tree_size: 7)
  end

  def test_verify
    assert @proof.verify(old_root: @old_root, new_root: @new_root)
    assert @proof.verify!(old_root: @old_root.to_binary, new_root: @new_root.to_binary)
    refute @proof.verify(old_root: @new_root, new_root: @old_root)
    assert_raises(CTMerkle::RootMismatchError) { @proof.verify!(old_root: @old_root, new_root: @old_root) }
  end

  def test_equal_sizes
    proof = @tree.consistency_proof(5, tree_size: 5)
    root = @tree.root(tree_size: 5)
    assert proof.verify(old_root: root, new_root: root)
    assert_raises(CTMerkle::RootMismatchError) { proof.verify!(old_root: root, new_root: @new_root) }
    bad = proof.with(consistency_path: [root])
    assert_raises(CTMerkle::MalformedProofError) { bad.verify!(old_root: root, new_root: root) }
  end

  def test_malformed
    zero = CTMerkle::ConsistencyProof.new(old_size: 0, new_size: 7, consistency_path: [])
    assert_raises(CTMerkle::MalformedProofError) { zero.verify!(old_root: CTMerkle::Hasher::SHA256.empty_root, new_root: @new_root) }
    reversed = @proof.with(old_size: 7, new_size: 3)
    assert_raises(CTMerkle::MalformedProofError) { reversed.verify!(old_root: @new_root, new_root: @old_root) }
    empty = @proof.with(consistency_path: [])
    assert_raises(CTMerkle::MalformedProofError) { empty.verify!(old_root: @old_root, new_root: @new_root) }
  end

  def test_round_trip
    %i[hex base64].each do |e|
      json = JSON.generate(@proof.to_h(encoding: e))
      assert_equal @proof, CTMerkle::ConsistencyProof.from_h(JSON.parse(json), encoding: e)
    end
    assert_equal %i[old_size new_size consistency_path], @proof.to_h.keys
  end
end

class VerifierTest < Minitest::Test
  def test_module_functions
    tree = CTMerkle::Tree.new(TestData::LEAF_INPUTS)
    proof = tree.inclusion_proof(1)
    assert CTMerkle::Verifier.verify_inclusion(
      leaf_hash: tree.leaf_hash(1), leaf_index: 1, tree_size: 8,
      inclusion_path: proof.inclusion_path, root: tree.root,
    )
    refute CTMerkle::Verifier.verify_inclusion(
      leaf_hash: tree.leaf_hash(1), leaf_index: 2, tree_size: 8,
      inclusion_path: proof.inclusion_path, root: tree.root,
    )
    cproof = tree.consistency_proof(6)
    assert CTMerkle::Verifier.verify_consistency(
      old_size: 6, new_size: 8, old_root: tree.root(tree_size: 6), new_root: tree.root,
      consistency_path: cproof.consistency_path,
    )
  end
end
