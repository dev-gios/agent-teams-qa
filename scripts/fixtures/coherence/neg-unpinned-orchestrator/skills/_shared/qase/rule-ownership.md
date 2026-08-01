# QASE Rule Ownership Registry (neg-unpinned-orchestrator fixture)
# This fixture has examples/new-tool/new-tool.md as an orchestrator (via qase.json)
# but the required table only pins claude-code/CLAUDE.md.
# C12 must detect that new-tool is unpinned and exit non-zero.

<!-- coherence:table rules -->
| rule_id | owner | literal | scope | allow_regex | allow_count |
|---------|-------|---------|-------|-------------|-------------|
<!-- /coherence:table -->

<!-- coherence:table required -->
| check_id | literal | files | min_count |
|----------|---------|-------|-----------|
| orch-no-auto-start | never starts the application | examples/claude-code/CLAUDE.md | 1 |
<!-- /coherence:table -->

<!-- coherence:table forbidden -->
| check_id | token | files | allow_regex | allow_count |
|----------|-------|-------|-------------|-------------|
<!-- /coherence:table -->

<!-- coherence:table placeholders -->
| token | class | derivation_owner | derivation_anchor |
|-------|-------|------------------|-------------------|
<!-- /coherence:table -->

<!-- coherence:table capabilities -->
| agent | class | model |
|-------|-------|-------|
<!-- /coherence:table -->

<!-- coherence:table classes -->
| class | tools |
|-------|-------|
<!-- /coherence:table -->
