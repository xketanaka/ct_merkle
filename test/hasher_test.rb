# frozen_string_literal: true

require_relative "test_helper"

class HasherTest < Minitest::Test
  H = CTMerkle::Hasher::SHA256

  def test_empty_root
    assert_equal TestData::ROOT_HASHES[0], H.empty_root.unpack1("H*")
  end

  def test_leaf_hashes
    TestData::LEAF_INPUTS.each_with_index do |input, i|
      assert_equal TestData::NODE_HASHES[0][i], H.leaf(input).unpack1("H*")
    end
  end

  def test_node_hashes
    (1...TestData::NODE_HASHES.size).each do |level|
      TestData::NODE_HASHES[level].each_with_index do |hex, i|
        left = TestData.hd(TestData::NODE_HASHES[level - 1][2 * i])
        right = TestData.hd(TestData::NODE_HASHES[level - 1][(2 * i) + 1])
        assert_equal hex, H.node(left, right).unpack1("H*")
      end
    end
  end

  def test_returns_binary_strings
    assert_equal Encoding::BINARY, H.leaf("あ").encoding
    assert_equal 32, H.digest_size
  end

  def test_leaf_hashes_bytes_regardless_of_encoding
    assert_equal H.leaf("あ".b), H.leaf("あ")
  end
end
