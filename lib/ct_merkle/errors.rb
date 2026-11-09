# frozen_string_literal: true

module CTMerkle
  # Base class of all errors raised by this library.
  # Invalid arguments are reported with the standard ArgumentError instead.
  class Error < StandardError; end

  # Raised by verify! when a proof does not verify.
  class VerificationError < Error; end

  # The proof is structurally invalid: wrong path length, index out of range,
  # hash of the wrong size, and so on.
  class MalformedProofError < VerificationError; end

  # The root computed from the proof does not match the expected root.
  class RootMismatchError < VerificationError; end
end
