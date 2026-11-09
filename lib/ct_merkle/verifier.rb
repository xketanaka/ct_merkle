# frozen_string_literal: true

module CTMerkle
  # Proof verification that does not need the tree itself.
  #
  # The algorithms follow RFC 9162 §2.1.3.2 (inclusion) and §2.1.4.2
  # (consistency). Hash arguments accept CTMerkle::Digest or binary Strings.
  module Verifier
    module_function

    # Returns true or false.
    def verify_inclusion(leaf_hash:, leaf_index:, tree_size:, inclusion_path:, root:, hasher: Hasher::SHA256)
      verify_inclusion!(leaf_hash: leaf_hash, leaf_index: leaf_index, tree_size: tree_size,
                        inclusion_path: inclusion_path, root: root, hasher: hasher)
    rescue VerificationError
      false
    end

    # Returns true, or raises MalformedProofError / RootMismatchError.
    def verify_inclusion!(leaf_hash:, leaf_index:, tree_size:, inclusion_path:, root:, hasher: Hasher::SHA256)
      check_integer!(leaf_index, "leaf_index")
      check_integer!(tree_size, "tree_size")
      leaf = hash_bytes(leaf_hash, "leaf_hash", hasher)
      expected_root = hash_bytes(root, "root", hasher)
      path = path_bytes(inclusion_path, "inclusion_path", hasher)

      if leaf_index.negative? || tree_size.negative?
        raise MalformedProofError, "leaf_index and tree_size must not be negative"
      end
      # Step 1
      if leaf_index >= tree_size
        raise MalformedProofError, "leaf_index (#{leaf_index}) must be less than tree_size (#{tree_size})"
      end

      # Steps 2-3
      fn = leaf_index
      sn = tree_size - 1
      r = leaf

      # Step 4
      path.each do |p|
        raise MalformedProofError, "inclusion_path is too long" if sn.zero?

        if fn.odd? || fn == sn
          r = hasher.node(p, r)
          until fn.odd? || fn.zero?
            fn >>= 1
            sn >>= 1
          end
        else
          r = hasher.node(r, p)
        end
        fn >>= 1
        sn >>= 1
      end

      # Step 5
      raise MalformedProofError, "inclusion_path is too short" unless sn.zero?
      raise RootMismatchError, "calculated root does not match the expected root" unless r == expected_root

      true
    end

    # Returns true or false.
    def verify_consistency(old_size:, new_size:, old_root:, new_root:, consistency_path:, hasher: Hasher::SHA256)
      verify_consistency!(old_size: old_size, new_size: new_size, old_root: old_root, new_root: new_root,
                          consistency_path: consistency_path, hasher: hasher)
    rescue VerificationError
      false
    end

    # Returns true, or raises MalformedProofError / RootMismatchError.
    def verify_consistency!(old_size:, new_size:, old_root:, new_root:, consistency_path:, hasher: Hasher::SHA256)
      check_integer!(old_size, "old_size")
      check_integer!(new_size, "new_size")
      first_hash = hash_bytes(old_root, "old_root", hasher)
      second_hash = hash_bytes(new_root, "new_root", hasher)
      path = path_bytes(consistency_path, "consistency_path", hasher)

      raise MalformedProofError, "old_size and new_size must not be negative" if old_size.negative? || new_size.negative?
      raise MalformedProofError, "old_size (#{old_size}) is greater than new_size (#{new_size})" if old_size > new_size
      raise MalformedProofError, "a consistency proof from an empty tree is not defined" if old_size.zero?

      if old_size == new_size
        raise MalformedProofError, "consistency_path must be empty when old_size == new_size" unless path.empty?
        raise RootMismatchError, "old_root and new_root differ although the sizes are equal" unless first_hash == second_hash

        return true
      end

      # Step 1
      raise MalformedProofError, "consistency_path is empty" if path.empty?

      # Step 2
      path = [first_hash, *path] if power_of_two?(old_size)

      # Step 3
      fn = old_size - 1
      sn = new_size - 1

      # Step 4
      while fn.odd?
        fn >>= 1
        sn >>= 1
      end

      # Step 5
      fr = sr = path.first

      # Step 6
      path.drop(1).each do |c|
        raise MalformedProofError, "consistency_path is too long" if sn.zero?

        if fn.odd? || fn == sn
          fr = hasher.node(c, fr)
          sr = hasher.node(c, sr)
          until fn.odd? || fn.zero?
            fn >>= 1
            sn >>= 1
          end
        else
          sr = hasher.node(sr, c)
        end
        fn >>= 1
        sn >>= 1
      end

      # Step 7
      raise MalformedProofError, "consistency_path is too short" unless sn.zero?
      raise RootMismatchError, "calculated old root does not match old_root" unless fr == first_hash
      raise RootMismatchError, "calculated new root does not match new_root" unless sr == second_hash

      true
    end

    def power_of_two?(n)
      n.positive? && n.nobits?(n - 1)
    end

    def check_integer!(value, name)
      raise ArgumentError, "#{name} must be an Integer, got #{value.class}" unless value.is_a?(Integer)
    end

    def hash_bytes(value, name, hasher)
      bytes = Digest.bytes_of(value, name)
      unless bytes.bytesize == hasher.digest_size
        raise MalformedProofError, "#{name} must be #{hasher.digest_size} bytes, got #{bytes.bytesize}"
      end

      bytes
    end

    def path_bytes(path, name, hasher)
      raise ArgumentError, "#{name} must be an Array, got #{path.class}" unless path.is_a?(Array)

      path.each_with_index.map { |h, i| hash_bytes(h, "#{name}[#{i}]", hasher) }
    end

    private_class_method :power_of_two?, :check_integer!, :hash_bytes, :path_bytes
  end
end
