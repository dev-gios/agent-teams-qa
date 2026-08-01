# QASE Rule Ownership Registry (positive fixture)

<!-- coherence:table rules -->
| rule_id | owner | literal | scope | allow_regex | allow_count |
|---------|-------|---------|-------|-------------|-------------|
| veto-ack | skills/_shared/qase/severity-contract.md | requires explicit user acknowledgment | skills/**,agents/** | — | 0 |
<!-- /coherence:table -->

<!-- coherence:table required -->
| check_id | literal | files | min_count |
|----------|---------|-------|-----------|
| orch-no-auto-start | never starts the application | examples/claude-code/CLAUDE.md,examples/opencode/opencode.json | 1 |
<!-- /coherence:table -->

<!-- coherence:table forbidden -->
| check_id | token | files | allow_regex | allow_count |
|----------|-------|-------|-------------|-------------|
| visual-no-blockers | HAS_BLOCKERS | skills/qa-visual/SKILL.md | never HAS_BLOCKERS\|intentionally absent | 2 |
<!-- /coherence:table -->

<!-- coherence:table placeholders -->
| token | class | derivation_owner | derivation_anchor |
|-------|-------|------------------|-------------------|
| {review-id} | derived | skills/_shared/qase/openspec-convention.md | ## Review ID Format |
| {flow-slug} | derived | skills/_shared/qase/openspec-convention.md | ### `{flow-slug}` — from a flow name |
| {page-slug} | derived | skills/_shared/qase/openspec-convention.md | ### `{page-slug}` — from a URL |
| {count} | descriptive | — | — |
| {pr-number} | descriptive | — | — |
| {short-sha} | descriptive | — | — |
| {verdict} | derived | skills/qa-report/SKILL.md | ## Step 6: Report Template |
| {runtime_suffix} | derived | skills/_shared/qase/severity-contract.md | ### Runtime Coverage Suffix |
<!-- /coherence:table -->

<!-- coherence:table desc-verdict -->
| check_id | token | allow_regex | allow_count |
|----------|-------|-------------|-------------|
| desc-no-clean | CLEAN | — | 0 |
| desc-no-unverified | UNVERIFIED | — | 0 |
| desc-no-warnings | HAS_WARNINGS | — | 0 |
| desc-no-blockers | HAS_BLOCKERS | MUST NOT declare HAS_BLOCKERS | 1 |
<!-- /coherence:table -->

<!-- coherence:table capabilities -->
| agent | class | model |
|-------|-------|-------|
| qa-scan | static | sonnet |
| qa-architect | static | sonnet |
| qa-security | static | sonnet |
| qa-advocate | static | sonnet |
| qa-inclusion | static | sonnet |
| qa-performance | static | sonnet |
| qa-test-strategy | static | sonnet |
| qa-browser | runtime | sonnet |
| qa-visual | runtime | sonnet |
| qa-report | aggregator | sonnet |
| qa-init | static | sonnet |
| qa-feedback | static | sonnet |
<!-- /coherence:table -->

<!-- coherence:table classes -->
| class | tools |
|-------|-------|
| static | Read, Grep, Glob, mem_search, mem_get_observation, mem_save |
| runtime | Read, Grep, Glob, Bash, mem_search, mem_get_observation, mem_save |
| aggregator | Read, Glob, mem_search, mem_get_observation, mem_save |
<!-- /coherence:table -->
