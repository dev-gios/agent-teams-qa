# QASE Rule Ownership Registry (neg-empty-required-table fixture)
# This fixture tests C9: required table present but has zero data rows.
# A check that reads 0 rows would pass vacuously — C9 must fail loudly.

<!-- coherence:table required -->
| check_id | literal | files | min_count |
|----------|---------|-------|-----------|
<!-- /coherence:table -->
