# frozen_string_literal: true

require_relative "test_helper"

# Runs the inclusion and consistency probes from transparency-dev/merkle
# (test/fixtures/transparency-dev). Each probe says whether verification must
# succeed or fail.
class VectorsTest < Minitest::Test
  DIR = File.expand_path("fixtures/transparency-dev", __dir__)

  # Probes where ct_merkle intentionally differs from the Go implementation.
  # The value is the result ct_merkle returns, with the reason.
  DEVIATIONS = {
    # The roots are 12-byte placeholders. Go skips the length check when
    # size1 == size2, but ct_merkle rejects any hash that is not
    # digest_size bytes as malformed.
    "consistency/additional/sizes-are-equal-one-and-proof-is-empty.json" => false,
  }.freeze

  def self.probes(kind)
    Dir.glob(File.join(DIR, kind, "**", "*.json")).sort.map do |path|
      [path.delete_prefix("#{DIR}/"), JSON.parse(File.read(path))]
    end
  end

  def self.b64(str)
    str.unpack1("m0")
  end

  def self.test_name(path)
    "test_#{path.gsub(/[^0-9A-Za-z]+/, "_")}"
  end

  probes("inclusion").each do |path, p|
    define_method(test_name(path)) do
      got = CTMerkle::Verifier.verify_inclusion(
        leaf_hash: self.class.b64(p["leafHash"]),
        leaf_index: p["leafIdx"],
        tree_size: p["treeSize"],
        inclusion_path: (p["proof"] || []).map { |s| self.class.b64(s) },
        root: self.class.b64(p["root"]),
      )
      assert_equal DEVIATIONS.fetch(path) { !p["wantErr"] }, got, "#{path}: #{p["desc"]}"
    end
  end

  probes("consistency").each do |path, p|
    define_method(test_name(path)) do
      got = CTMerkle::Verifier.verify_consistency(
        old_size: p["size1"],
        new_size: p["size2"],
        old_root: self.class.b64(p["root1"]),
        new_root: self.class.b64(p["root2"]),
        consistency_path: (p["proof"] || []).map { |s| self.class.b64(s) },
      )
      assert_equal DEVIATIONS.fetch(path) { !p["wantErr"] }, got, "#{path}: #{p["desc"]}"
    end
  end

  def test_vectors_are_present
    assert_operator self.class.probes("inclusion").size, :>, 50
    assert_operator self.class.probes("consistency").size, :>, 50
  end
end
