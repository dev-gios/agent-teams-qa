# QASE Rule Ownership Registry (neg-missing-derivation fixture)

<!-- coherence:table rules -->
| rule_id | owner | literal | scope | allow_regex | allow_count |
|---------|-------|---------|-------|-------------|-------------|
| veto-ack | skills/_shared/qase/severity-contract.md | requires explicit user acknowledgment | skills/**,agents/** | — | 0 |
<!-- /coherence:table -->

<!-- coherence:table forbidden -->
| check_id | token | files | allow_regex | allow_count |
|----------|-------|-------|-------------|-------------|
| visual-no-blockers | HAS_BLOCKERS | skills/qa-visual/SKILL.md | never HAS_BLOCKERS\|intentionally absent | 2 |
<!-- /coherence:table -->

<!-- coherence:table placeholders -->
| token | class | derivation_owner | derivation_anchor |
|-------|-------|------------------|-------------------|
| {page-slug} | derived | skills/_shared/qase/openspec-convention.md | ### `{page-slug}` — THIS ANCHOR DOES NOT EXIST |
| {count} | descriptive | — | — |
<!-- /coherence:table -->

<!-- coherence:table capabilities -->
| agent | class | model |
|-------|-------|-------|
| qa-security | static | sonnet |
<!-- /coherence:table -->

<!-- coherence:table classes -->
| class | tools |
|-------|-------|
| static | Read, Grep, Glob, mem_search, mem_get_observation, mem_save |
<!-- /coherence:table -->
