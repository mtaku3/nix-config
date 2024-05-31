export default {
  "*.nix": "alejandra -q",
  "*.hs": "ormolu --no-cabal",
  "*.lua": (filenames) => filenames.map((x) => `stylua '${x}'`)
}
