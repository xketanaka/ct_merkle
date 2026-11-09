# frozen_string_literal: true

require_relative "test_helper"

class DigestTest < Minitest::Test
  HEX = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  B64 = "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ="

  def setup
    @d = CTMerkle::Digest.from_hex(HEX)
  end

  def test_conversions
    assert_equal HEX, @d.to_hex
    assert_equal B64, @d.to_base64
    assert_equal TestData.hd(HEX), @d.to_binary
    assert_equal Encoding::BINARY, @d.to_binary.encoding
    assert_equal HEX, @d.to_s
    assert_equal 32, @d.bytesize
    assert_equal "#<CTMerkle::Digest #{HEX}>", @d.inspect
  end

  def test_from_hex_accepts_upper_case
    assert_equal @d, CTMerkle::Digest.from_hex(HEX.upcase)
  end

  def test_from_base64
    assert_equal @d, CTMerkle::Digest.from_base64(B64)
  end

  def test_invalid_hex
    ["abc", "zz", "00 11", nil].each do |s|
      assert_raises(ArgumentError) { CTMerkle::Digest.from_hex(s) }
    end
  end

  def test_invalid_base64
    ["%%%", "LPJNul+w\n", "abc", nil].each do |s|
      assert_raises(ArgumentError) { CTMerkle::Digest.from_base64(s) }
    end
  end

  def test_new_normalizes_encoding_and_freezes
    d = CTMerkle::Digest.new("あ")
    assert_equal Encoding::BINARY, d.to_binary.encoding
    assert_equal 3, d.bytesize
    assert_predicate d, :frozen?
    assert_predicate d.to_binary, :frozen?
  end

  def test_new_rejects_non_string
    assert_raises(ArgumentError) { CTMerkle::Digest.new(nil) }
  end

  def test_equality_with_digest_and_string
    bin = TestData.hd(HEX)
    assert_equal @d, CTMerkle::Digest.new(bin)
    assert @d == bin
    assert @d == bin.dup.force_encoding(Encoding::UTF_8)
    refute @d == HEX
    refute @d == nil
    refute bin == @d, "String#== is not symmetric because to_str is not defined"
  end

  def test_eql_and_hash
    other = CTMerkle::Digest.new(TestData.hd(HEX))
    assert @d.eql?(other)
    refute @d.eql?(TestData.hd(HEX))
    assert_equal 1, { @d => 1, other => 1 }.size
  end

  def test_no_to_str
    refute_respond_to @d, :to_str
  end
end
