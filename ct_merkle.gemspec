# frozen_string_literal: true

require_relative "lib/ct_merkle/version"

Gem::Specification.new do |spec|
  spec.name = "ct_merkle"
  spec.version = CTMerkle::VERSION
  spec.authors = ["Ken Tanaka"]
  spec.email = ["tanaka-ken@netlab.jp"]

  spec.summary = "Append-only Merkle trees compliant with RFC 6962 / RFC 9162"
  spec.description = "Merkle tree hashing, inclusion proofs and consistency proofs as defined in " \
                     "RFC 6962 and RFC 9162 (Certificate Transparency), with no runtime dependencies."
  spec.homepage = "https://github.com/xketanaka/ct_merkle"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["documentation_uri"] = "#{spec.homepage}/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"
end
