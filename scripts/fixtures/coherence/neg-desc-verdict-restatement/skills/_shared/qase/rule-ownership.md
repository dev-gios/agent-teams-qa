# QASE Rule Ownership Registry (neg-desc-verdict-restatement fixture)
# This fixture proves C13 fires when a description names CLEAN as a returned verdict token.

<!-- coherence:table desc-verdict -->
| check_id | token | allow_regex | allow_count |
|----------|-------|-------------|-------------|
| desc-no-clean | CLEAN | — | 0 |
| desc-no-unverified | UNVERIFIED | — | 0 |
| desc-no-warnings | HAS_WARNINGS | — | 0 |
| desc-no-blockers | HAS_BLOCKERS | MUST NOT declare HAS_BLOCKERS | 1 |
<!-- /coherence:table -->
