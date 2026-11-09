# transparency-dev/merkle test vectors

The `inclusion/` and `consistency/` directories are copied unmodified from
`testdata/` of https://github.com/transparency-dev/merkle
(commit `c39fbf350a405f68571bf4c42a6a518eb0a46a4b`).

They are licensed under the Apache License 2.0 (see `LICENSE` in this
directory), Copyright Google LLC. They are used only by the test suite and are
not included in the packaged gem.

Each file is one verification probe. Byte fields are base64 encoded, `leafIdx`
is 0-based, and `wantErr` tells whether verification must fail.
