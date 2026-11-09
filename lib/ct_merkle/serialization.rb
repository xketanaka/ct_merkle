# frozen_string_literal: true

module CTMerkle
  # Shared helpers for to_h / from_h of the proof classes.
  module Serialization
    ENCODINGS = %i[hex base64].freeze

    module_function

    def encode(digest, encoding)
      case check_encoding!(encoding)
      when :hex then digest.to_hex
      when :base64 then digest.to_base64
      end
    end

    def decode(value, encoding, name)
      raise ArgumentError, "#{name} must be a String, got #{value.class}" unless value.is_a?(String)

      case check_encoding!(encoding)
      when :hex then Digest.from_hex(value)
      when :base64 then Digest.from_base64(value)
      end
    end

    def check_encoding!(encoding)
      return encoding if ENCODINGS.include?(encoding)

      raise ArgumentError, "encoding must be one of #{ENCODINGS.inspect}, got #{encoding.inspect}"
    end

    # Normalizes keys to Symbols and checks that exactly the expected keys exist.
    def normalize_keys(hash, keys)
      raise ArgumentError, "expected a Hash, got #{hash.class}" unless hash.is_a?(Hash)

      normalized = hash.to_h { |k, v| [k.is_a?(String) ? k.to_sym : k, v] }
      raise ArgumentError, "duplicate keys in #{hash.keys.inspect}" if normalized.size != hash.size

      missing = keys - normalized.keys
      unknown = normalized.keys - keys
      raise ArgumentError, "missing keys: #{missing.join(", ")}" unless missing.empty?
      raise ArgumentError, "unknown keys: #{unknown.join(", ")}" unless unknown.empty?

      normalized
    end

    def decode_path(value, encoding, name)
      raise ArgumentError, "#{name} must be an Array, got #{value.class}" unless value.is_a?(Array)

      value.each_with_index.map { |v, i| decode(v, encoding, "#{name}[#{i}]") }
    end
  end
  private_constant :Serialization
end
