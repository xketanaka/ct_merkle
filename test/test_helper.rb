# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "ct_merkle"
require "json"
require "minitest/autorun"

module TestData
  module_function

  def hd(hex)
    [hex].pack("H*")
  end

  # testonly/constants.go of transparency-dev/merkle (Apache-2.0, Google LLC).
  LEAF_INPUTS = %w[
    00 10 2021 3031 40414243 5051525354555657 606162636465666768696a6b6c6d6e6f
  ].map { |h| [h].pack("H*") }.unshift("".b).freeze

  # ROOT_HASHES[n] is the root of the tree built from the first n LEAF_INPUTS.
  ROOT_HASHES = %w[
    e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d
    fac54203e7cc696cf0dfcb42c92a1d9dbaf70ad9e621f4bd8d98662f00e3c125
    aeb6bcfe274b70a14fb067a5e5578264db0fa9b51af5e0ba159158f329e06e77
    d37ee418976dd95753c1c73862b9398fa2a2cf9b4ff0fdfe8b30cd95209614b7
    4e3bbb1f7b478dcfe71fb631631519a3bca12c9aefca1612bfce4c13a86264d4
    76e67dadbcdf1e10e1b74ddc608abd2f98dfb16fbce75277b5232a127f2087ef
    ddb89be403809e325750d3d263cd78929c2942b7942a34b77e122c9594a74c8c
    5dc9da79a70659a9ad559cb701ded9a2ab9d823aad2f4960cfe370eff4604328
  ].freeze

  # NODE_HASHES[level][index]: complete subtree hashes; level 0 is leaf hashes.
  NODE_HASHES = [
    %w[
      6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d
      96a296d224f285c67bee93c30f8a309157f0daa35dc5b87e410b78630a09cfc7
      0298d122906dcfc10892cb53a73992fc5b9f493ea4c9badb27b791b4127a7fe7
      07506a85fd9dd2f120eb694f86011e5bb4662e5c415a62917033d4a9624487e7
      bc1a0643b12e4d2d7c77918f44e0f4f79a838b6cf9ec5b5c283e1f4d88599e6b
      4271a26be0d8a84f0bd54c8c302e7cb3a3b5d1fa6780a40bcce2873477dab658
      b08693ec2e721597130641e8211e7eedccb4c26413963eee6c1e2ed16ffb1a5f
      46f6ffadd3d06a09ff3c5860d2755c8b9819db7df44251788c7d8e3180de8eb1
    ],
    %w[
      fac54203e7cc696cf0dfcb42c92a1d9dbaf70ad9e621f4bd8d98662f00e3c125
      5f083f0a1a33ca076a95279832580db3e0ef4584bdff1f54c8a360f50de3031e
      0ebc5d3437fbe2db158b9f126a1d118e308181031d0a949f8dededebc558ef6a
      ca854ea128ed050b41b35ffc1b87b8eb2bde461e9e3b5596ece6b9d5975a0ae0
    ],
    %w[
      d37ee418976dd95753c1c73862b9398fa2a2cf9b4ff0fdfe8b30cd95209614b7
      6b47aaf29ee3c2af9af889bc1fb9254dabd31177f16232dd6aab035ca39bf6e4
    ],
    %w[
      5dc9da79a70659a9ad559cb701ded9a2ab9d823aad2f4960cfe370eff4604328
    ],
  ].freeze
end

# A deliberately naive implementation written straight from the recursive
# definitions in RFC 9162 §2.1, used to cross-check CTMerkle::Tree.
module Reference
  H = CTMerkle::Hasher::SHA256

  module_function

  def k_for(n)
    k = 1
    k <<= 1 while k << 1 < n
    k
  end

  def mth(leaves)
    return H.empty_root if leaves.empty?
    return H.leaf(leaves[0]) if leaves.size == 1

    k = k_for(leaves.size)
    H.node(mth(leaves[0...k]), mth(leaves[k..]))
  end

  def path(m, leaves)
    return [] if leaves.size == 1

    k = k_for(leaves.size)
    if m < k
      path(m, leaves[0...k]) + [mth(leaves[k..])]
    else
      path(m - k, leaves[k..]) + [mth(leaves[0...k])]
    end
  end

  def proof(m, leaves)
    subproof(m, leaves, true)
  end

  def subproof(m, leaves, b)
    n = leaves.size
    return(b ? [] : [mth(leaves)]) if m == n

    k = k_for(n)
    if m <= k
      subproof(m, leaves[0...k], b) + [mth(leaves[k..])]
    else
      subproof(m - k, leaves[k..], false) + [mth(leaves[0...k])]
    end
  end
end
