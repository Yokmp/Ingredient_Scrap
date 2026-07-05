# Ingredient Scrap Legacy Code

This folder keeps resolver experiments that are no longer part of the active runtime path.

- `static`: the former collector/baseline resolver path that staged scrap directly from matched ingredients.
- `recipe-chain`: the passive recipe-chain target analysis and decider experiments.
- `weighted`: reserved for older scoring/weight experiments if they need to be archived.

The active resolver is the iterative ancestry/lookup resolver under `code/resolver/ancestry`.
Legacy files are kept for reference only and must not be required by release code.
