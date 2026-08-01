# QASE Rule Ownership Registry (neg-undefined-placeholder fixture)
# <evid> is intentionally NOT declared — the fixture proves C2 fires when an
# agent uses a token absent from the placeholders table.

<!-- coherence:table rules -->
| rule_id | owner | literal | scope | allow_regex | allow_count |
|---------|-------|---------|-------|-------------|-------------|
<!-- /coherence:table -->

<!-- coherence:table forbidden -->
| check_id | token | files | allow_regex | allow_count |
|----------|-------|-------|-------------|-------------|
<!-- /coherence:table -->

<!-- coherence:table placeholders -->
| token | class | derivation_owner | derivation_anchor |
|-------|-------|------------------|-------------------|
| {count} | descriptive | — | — |
<!-- /coherence:table -->

<!-- coherence:table capabilities -->
| agent | class | model |
|-------|-------|-------|
<!-- /coherence:table -->

<!-- coherence:table classes -->
| class | tools |
|-------|-------|
<!-- /coherence:table -->
