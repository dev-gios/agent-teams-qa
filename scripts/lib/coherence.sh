#!/usr/bin/env bash
# ============================================================================
# QASE Coherence Check Library
# Sourced by lint_skills.sh — defines no executable top-level code.
# Callers provide: pass(), fail(), warn() functions.
# ============================================================================

# Emits TSV rows of a named coherence table.
# Anchored to HTML comment markers, not line numbers.
# Usage: coh_table <file> <table-name>
coh_table() {
    local file="$1"
    local tname="$2"
    awk -v t="$tname" '
      $0 == "<!-- coherence:table " t " -->" { on=1; next }
      $0 == "<!-- /coherence:table -->"      { on=0 }
      on && /^\|/ && !/^\|[- |]*\|$/ {
          # Replace escaped pipes \| with a placeholder before splitting
          # so regex fields like "never HAS_BLOCKERS\|other" stay intact.
          gsub(/\\\|/, "\x01")
          sub(/^\|/,""); sub(/\|$/,"")
          n=split($0, f, /\|/)
          for (i=1;i<=n;i++) {
              gsub(/^[ \t]+|[ \t]+$/,"",f[i])
              # Restore placeholder back to \| in the field value
              gsub(/\x01/, "\\|", f[i])
          }
          # skip header row by checking first-column keyword
          if (f[1] ~ /^(rule_id|check_id|token|agent|class)$/) next
          line=f[1]; for(i=2;i<=n;i++) line=line "\t" f[i]; print line
      }' "$file"
}

# C1 — Forbidden-token check.
# For each row in the `forbidden` table, count occurrences of the token in each
# listed file; subtract exemptions matching allow_regex; fail if any remain.
# Usage: check_c1_forbidden_token <registry-file> [<corpus-root>]
check_c1_forbidden_token() {
    local reg="$1"
    local root="${2:-.}"

    local c1_passed=1

    while IFS=$'\t' read -r id token files allow_re allow_n; do
        [ -z "$id" ] && continue
        # allow_re is stored as "re1\|re2" (markdown-escaped pipe); convert to ERE alternation
        # by replacing literal \| with | for grep -E use.
        local grep_re
        grep_re=$(printf '%s' "$allow_re" | sed 's/\\|/|/g')

        # Split comma-separated file list
        local flist_str="$files"
        while [ -n "$flist_str" ]; do
            local f="${flist_str%%,*}"
            flist_str="${flist_str#"$f"}"
            flist_str="${flist_str#,}"
            f="${f// /}"
            [ -z "$f" ] && continue
            # Resolve relative to corpus root if not absolute
            [[ "$f" != /* ]] && f="$root/$f"
            if [ ! -f "$f" ]; then
                fail "C1 $id: file not found: $f"
                c1_passed=0
                continue
            fi
            local total exempt expected_exempt surplus
            total=$(grep -cF -- "$token" "$f" 2>/dev/null || true)
            if [ "$allow_re" = "—" ] || [ -z "$allow_re" ]; then
                exempt=0
            else
                # grep_re has | as alternation (grep -E)
                exempt=$(grep -F -- "$token" "$f" 2>/dev/null | grep -Ec -- "$grep_re" 2>/dev/null || true)
            fi
            # Validate that actual exempt count matches declared allow_count
            expected_exempt="${allow_n:-0}"
            if [ "$exempt" -ne "$expected_exempt" ]; then
                fail "C1 $id: exemption drift in $f (expected allow_count=$expected_exempt, found $exempt matching allow_regex)"
                c1_passed=0
            fi
            surplus=$(( total - exempt ))
            if [ "$surplus" -gt 0 ]; then
                fail "C1 $id: forbidden token '$token' appears $surplus non-exempt time(s) in $f"
                c1_passed=0
            fi
        done
    done < <(coh_table "$reg" forbidden)

    [ "$c1_passed" -eq 1 ] && pass "C1 forbidden-token: no violations"
}

# C2 — Undefined-placeholder check.
# Scoped to: agents/**, skills/_shared/qase/**, and skills/qa-*/SKILL.md.
# Extracts {token} and <token> patterns (lowercase only); fails on undeclared tokens;
# warns on declared-but-unused tokens.
# Usage: check_c2_undefined_placeholder <registry-file> [<corpus-root>]
check_c2_undefined_placeholder() {
    local reg="$1"
    local root="${2:-.}"
    local tmp
    tmp=$(mktemp -d)

    # Scope: agents/, skills/_shared/qase/, and skills/qa-*/SKILL.md
    local corpus_files=()
    while IFS= read -r -d '' f; do
        corpus_files+=("$f")
    done < <(
        find "$root/agents" "$root/skills/_shared/qase" -name "*.md" -print0 2>/dev/null
        find "$root/skills" -maxdepth 2 -name "SKILL.md" -path "*/qa-*/SKILL.md" -print0 2>/dev/null
    )

    if [ "${#corpus_files[@]}" -eq 0 ]; then
        warn "C2: no corpus files found under $root/agents or $root/skills/_shared/qase"
        rm -rf "$tmp"
        return
    fi

    # Extract all {lowercase-token} and <lowercase-token> occurrences
    grep -ohE '\{[a-z][a-z0-9_-]*\}|<[a-z][a-z0-9_-]*>' \
        "${corpus_files[@]}" 2>/dev/null \
        | sort -u > "$tmp/used" || true

    # Extract declared tokens from registry
    coh_table "$reg" placeholders | cut -f1 | sort -u > "$tmp/declared"

    local undeclared
    undeclared=$(comm -23 "$tmp/used" "$tmp/declared" 2>/dev/null || true)
    local unused
    unused=$(comm -13 "$tmp/used" "$tmp/declared" 2>/dev/null || true)

    if [ -n "$undeclared" ]; then
        fail "C2: token(s) used but not declared in rule-ownership.md placeholders table: $undeclared"
    else
        pass "C2 undefined-placeholder: all tokens declared"
    fi

    if [ -n "$unused" ]; then
        warn "C2: declared placeholder(s) unused in scoped corpus (may be used in skills/qa-*/): $unused"
    fi

    rm -rf "$tmp"
}

# C3 — Derivation-anchor check.
# For each `class: derived` placeholder in the registry, verifies the anchor heading
# exists in the owner file and the section has non-empty body content.
# Usage: check_c3_derivation_anchor <registry-file> [<corpus-root>]
check_c3_derivation_anchor() {
    local reg="$1"
    local root="${2:-.}"

    local c3_passed=1

    while IFS=$'\t' read -r token class owner anchor; do
        [ -z "$token" ] && continue
        [ "$class" != "derived" ] && continue
        # Resolve owner relative to corpus root if not absolute
        [[ "$owner" != /* ]] && owner="$root/$owner"
        if [ ! -f "$owner" ]; then
            fail "C3 $token: derivation owner file missing: $owner"
            c3_passed=0
            continue
        fi
        if ! grep -qF -- "$anchor" "$owner" 2>/dev/null; then
            fail "C3 $token: anchor '$anchor' not found in $owner"
            c3_passed=0
            continue
        fi
        # Check section body is non-empty (content after anchor heading before next heading)
        local body
        body=$(awk -v a="$anchor" '
            index($0,a){f=1;next}
            f && /^#{2,3} /{exit}
            f{print}
        ' "$owner" | tr -d '[:space:]')
        if [ -z "$body" ]; then
            fail "C3 $token: derivation section '$anchor' is empty in $owner"
            c3_passed=0
        fi
    done < <(coh_table "$reg" placeholders)

    [ "$c3_passed" -eq 1 ] && pass "C3 derivation-anchor: all derived tokens have non-empty anchor sections"
}

# C4 — Single-source-of-truth check.
# For each row in the `rules` table, grep the literal across the declared scope;
# fail if count != 1 or if the single match is not in the declared owner file.
# Usage: check_c4_single_source <registry-file> [<corpus-root>]
check_c4_single_source() {
    local reg="$1"
    local root="${2:-.}"

    local c4_passed=1

    while IFS=$'\t' read -r id owner literal scope allow_re allow_n; do
        [ -z "$id" ] && continue
        # Expand scope globs relative to corpus root
        local scope_expanded=()
        IFS=',' read -ra scope_parts <<< "$scope"
        for sp in "${scope_parts[@]}"; do
            sp="${sp// /}"
            [[ "$sp" != /* ]] && sp="$root/$sp"
            # Use find to expand glob patterns
            while IFS= read -r -d '' f; do
                scope_expanded+=("$f")
            done < <(find $sp -name "*.md" -print0 2>/dev/null)
        done

        if [ "${#scope_expanded[@]}" -eq 0 ]; then
            warn "C4 $id: no files matched scope '$scope' under $root"
            continue
        fi

        mapfile -t raw_hits < <(grep -rlF -- "$literal" "${scope_expanded[@]}" 2>/dev/null | sort)

        # Filter out the registry file itself (it contains every literal as meta-text)
        local hits=()
        for h in "${raw_hits[@]}"; do
            # Skip rule-ownership.md — its rows define the literals, not restate them
            [[ "$h" == */rule-ownership.md ]] && continue
            # Skip files whose path matches allow_re (if set)
            if [[ "$allow_re" != "—" && -n "$allow_re" ]]; then
                if echo "$h" | grep -qE "$allow_re" 2>/dev/null; then
                    continue
                fi
            fi
            hits+=("$h")
        done
        local n="${#hits[@]}"

        if [ "$n" -eq 0 ]; then
            fail "C4 $id: registered literal not found anywhere — stale registry entry (owner: $owner)"
            c4_passed=0
        elif [ "$n" -gt 1 ]; then
            fail "C4 $id: literal found in $n files: ${hits[*]} (registered owner: $owner)"
            c4_passed=0
        elif [ "${hits[0]}" != "$root/$owner" ] && [ "${hits[0]}" != "$owner" ]; then
            fail "C4 $id: literal lives in ${hits[0]}, registry says $owner"
            c4_passed=0
        else
            pass "C4 $id: single source of truth ($owner)"
        fi
    done < <(coh_table "$reg" rules)

    [ "$c4_passed" -eq 1 ] || true  # individual messages already emitted
}

# C5 — Bijection check: agents/qa-*.md set == skills/qa-*/ set, cardinality 12.
# Usage: check_c5_bijection <corpus-root>
check_c5_bijection() {
    local root="${1:-.}"
    local agents_dir="$root/agents"
    local skills_dir="$root/skills"

    if [ ! -d "$agents_dir" ] || [ ! -d "$skills_dir" ]; then
        fail "C5: agents/ or skills/ directory missing under $root"
        return
    fi

    local tmp
    tmp=$(mktemp -d)

    # Get sorted stem lists
    find "$agents_dir" -maxdepth 1 -name 'qa-*.md' \
        | sed 's|.*/||; s|\.md$||' | sort > "$tmp/agents"
    find "$skills_dir" -maxdepth 1 -type d -name 'qa-*' \
        | sed 's|.*/||' | sort > "$tmp/skills"

    local agent_count skill_count
    agent_count=$(wc -l < "$tmp/agents")
    skill_count=$(wc -l < "$tmp/skills")

    local orphan_agents orphan_skills
    orphan_agents=$(comm -23 "$tmp/agents" "$tmp/skills")
    orphan_skills=$(comm -13 "$tmp/agents" "$tmp/skills")

    local c5_ok=1
    if [ -n "$orphan_agents" ]; then
        fail "C5 bijection: agents without matching skill: $orphan_agents"
        c5_ok=0
    fi
    if [ -n "$orphan_skills" ]; then
        fail "C5 bijection: skills without matching agent: $orphan_skills"
        c5_ok=0
    fi
    if [ "$agent_count" -ne 12 ]; then
        fail "C5 bijection: expected 12 agents, found $agent_count"
        c5_ok=0
    fi
    [ "$c5_ok" -eq 1 ] && pass "C5 bijection: 12 agents ↔ 12 skills, no orphans"
    rm -rf "$tmp"
}

# C6 — Agent-shape check: required frontmatter + body landmarks.
# Usage: check_c6_agent_shape <corpus-root>
check_c6_agent_shape() {
    local root="${1:-.}"
    local agents_dir="$root/agents"
    local c6_ok=1

    for agent_file in "$agents_dir"/qa-*.md; do
        [ -f "$agent_file" ] || continue
        local stem
        stem=$(basename "$agent_file" .md)

        # Line count <= 120
        local lc
        lc=$(wc -l < "$agent_file")
        if [ "$lc" -gt 120 ]; then
            fail "C6 $stem: file has $lc lines (max 120)"
            c6_ok=0
        fi

        # Frontmatter must contain required fields
        local fm
        fm=$(awk 'NR>1 && /^---$/{exit} NR>1{print}' "$agent_file")
        for field in name description model tools; do
            if ! echo "$fm" | grep -qE "^${field}:"; then
                fail "C6 $stem: missing frontmatter field '$field'"
                c6_ok=0
            fi
        done

        # name must match filename stem
        local name_val
        name_val=$(echo "$fm" | grep -E "^name:" | sed 's/^name: *//')
        if [ "$name_val" != "$stem" ]; then
            fail "C6 $stem: frontmatter name '$name_val' != filename stem '$stem'"
            c6_ok=0
        fi

        # Body must reference SKILL.md and persistence-contract.md
        local body
        body=$(awk 'NR>2 && /^---$/{found++} found>=1{print}' "$agent_file")
        if ! echo "$body" | grep -q 'SKILL\.md'; then
            fail "C6 $stem: body does not reference SKILL.md"
            c6_ok=0
        fi
        if ! echo "$body" | grep -q 'persistence-contract\.md'; then
            fail "C6 $stem: body does not reference persistence-contract.md"
            c6_ok=0
        fi

        # Body must include executor boundary
        if ! echo "$body" | grep -qiE 'Do NOT call the Task tool|Do NOT call Task|do not call.*task'; then
            fail "C6 $stem: body does not contain executor boundary ('Do NOT call the Task tool')"
            c6_ok=0
        fi

        # description must be non-empty and contain a trigger clause
        local desc_val
        desc_val=$(echo "$fm" | awk '/^description:/{found=1; $1=""; sub(/^[[:space:]]*/,""); print; next} found && /^  /{print; next} found && /^[^ ]/{ exit}')
        if ! echo "$desc_val" | grep -qiE 'Use when|Trigger:'; then
            fail "C6 $stem: description does not contain 'Use when' or 'Trigger:'"
            c6_ok=0
        fi
    done

    [ "$c6_ok" -eq 1 ] && pass "C6 agent-shape: all agents pass shape check"
}

# C7 — Capability check: no Write/Edit/MultiEdit/NotebookEdit in agents; only qa-browser + qa-visual have Bash.
# Usage: check_c7_capability <corpus-root>
check_c7_capability() {
    local root="${1:-.}"
    local agents_dir="$root/agents"
    local c7_ok=1

    # No Write/Edit family
    local bad_write
    bad_write=$(grep -rlE '^tools:.*\b(Write|Edit|MultiEdit|NotebookEdit)\b' "$agents_dir"/ 2>/dev/null || true)
    if [ -n "$bad_write" ]; then
        fail "C7 capability: Write/Edit/MultiEdit/NotebookEdit found in: $bad_write"
        c7_ok=0
    fi

    # Exactly qa-browser and qa-visual have Bash
    local bash_agents
    bash_agents=$(grep -rl '^tools:.*\bBash\b' "$agents_dir"/ 2>/dev/null | xargs -I{} basename {} .md | sort || true)
    local expected_bash="qa-browser
qa-visual"
    if [ "$bash_agents" != "$expected_bash" ]; then
        fail "C7 capability: Bash grants expected {qa-browser, qa-visual}, found: $bash_agents"
        c7_ok=0
    fi

    [ "$c7_ok" -eq 1 ] && pass "C7 capability: Write/Edit=0, Bash=exactly {qa-browser, qa-visual}"
}

# C8 — No self-write check.
# Detects two forms of specialist self-writes:
#   (a) 'Write to `qaspec/' — direct filesystem writes to the openspec store
#   (b) mem_save(...topic_key: "qase/{review-id}/...) — Engram review-artifact writes
# Both are sole-writer violations: only the orchestrator may persist review artifacts.
# Usage: check_c8_no_self_write <corpus-root>
check_c8_no_self_write() {
    local root="${1:-.}"
    local c8_ok=1

    # (a) Direct filesystem writes to qaspec/
    local fs_hits
    fs_hits=$(grep -rnF "Write to \`qaspec/" "$root/skills/qa-"*/SKILL.md 2>/dev/null || true)
    if [ -n "$fs_hits" ]; then
        fail "C8 no-self-write: found 'Write to \`qaspec/' in SKILL.md files: $fs_hits"
        c8_ok=0
    fi

    # (b) Engram self-writes: mem_save with a qase/{review-id}/* key where the specialist
    # is the caller (not the orchestrator). Detect lines that instruct the specialist to
    # call mem_save directly: lines containing mem_save( with a review key but NOT preceded
    # by "orchestrator calls" or "orchestrator writes" context in the same line.
    # Pattern: line has mem_save( + qase/{review-id} key but NOT 'orchestrator calls'.
    local engram_hits
    engram_hits=$(grep -rn 'mem_save(' "$root/skills/qa-"*/SKILL.md 2>/dev/null \
        | grep 'qase/{review-id}' \
        | grep -iv 'orchestrator calls\|orchestrator writes\|the orchestrator' \
        || true)
    if [ -n "$engram_hits" ]; then
        fail "C8 no-self-write: found mem_save with qase/{review-id}/ key in SKILL.md (sole-writer violation): $engram_hits"
        c8_ok=0
    fi

    [ "$c8_ok" -eq 1 ] && pass "C8 no-self-write: zero qaspec/ writes and zero review-artifact mem_save calls in SKILL.md files"
}

# C9 — Required-literal-present check.
# For each row in the `required` table, verifies the literal appears at least min_count times
# in every listed file. Fails if the table is empty (vacuous-pass guard).
# Usage: check_c9_required_literal <registry-file> [<corpus-root>]
check_c9_required_literal() {
    local reg="$1" root="${2:-.}" c9_ok=1 rows=0
    while IFS=$'\t' read -r id literal files min_n; do
        [ -z "$id" ] && continue
        rows=$((rows + 1))
        local flist_str="$files"
        while [ -n "$flist_str" ]; do
            local f="${flist_str%%,*}"
            flist_str="${flist_str#"$f"}"; flist_str="${flist_str#,}"; f="${f// /}"
            [ -z "$f" ] && continue
            [[ "$f" != /* ]] && f="$root/$f"
            if [ ! -f "$f" ]; then
                fail "C9 $id: file not found: $f"; c9_ok=0; continue
            fi
            local n
            n=$(grep -cF -- "$literal" "$f" 2>/dev/null || true)
            if [ "$n" -lt "${min_n:-1}" ]; then
                fail "C9 $id: required literal '$literal' missing from $f (found $n, need ${min_n:-1})"
                c9_ok=0
            fi
        done
    done < <(coh_table "$reg" required)

    # A check that reads zero rows would pass vacuously — mirror C4's zero-hit branch.
    if [ "$rows" -eq 0 ]; then
        fail "C9: 'required' table is empty or absent — check would pass vacuously"
        c9_ok=0
    fi
    [ "$c9_ok" -eq 1 ] && pass "C9 required-literal: all required literals present in all declared files"
}

# C10 — Unverified-not-clean check.
# Asserts UNVERIFIED is distinct from CLEAN across five sub-criteria:
# (a) no equate-on-one-line; (b) no bare CLEAN in refusal branches of runtime skills;
# (c) exactly 3 fabrication guards per runtime skill; (d) two-token verdict template present
# and un-suffixed form absent; (e) UNVERIFIED in exactly {qa-browser,qa-report,qa-scan,qa-visual}.
# Usage: check_c10_unverified_not_clean [<corpus-root>]
check_c10_unverified_not_clean() {
    local root="${1:-.}" c10_ok=1
    local sk="$root/skills" ag="$root/agents" ex="$root/examples"

    # (a) No file may EQUATE the two tokens on one line.
    # (a) No file may EQUATE the two tokens on one line.
    # Scope: skills, agents, AND examples (examples/ is where the user actually reads the verdict).
    # Pattern 1: equating operator between UNVERIFIED and CLEAN (no pipe allowed before operator).
    # Pattern 2: pipe-separated equate — "UNVERIFIED | <operator> ... CLEAN" bypasses [^|]* in pattern 1.
    # The legitimate idiom "UNVERIFIED (...) | CLEAN (otherwise)" has CLEAN immediately after | (no equating word).
    local ex_args=()
    [ -d "$ex" ] && ex_args=("$ex")
    local eq eq2
    eq=$(grep -rn 'UNVERIFIED' "$sk" "$ag" "${ex_args[@]}" 2>/dev/null \
         | grep -E 'UNVERIFIED[^|]*(->|→|==?|treated as|maps? to|same as|equivalent to)[[:space:]`]*CLEAN' \
         || true)
    eq2=$(grep -rn 'UNVERIFIED' "$sk" "$ag" "${ex_args[@]}" 2>/dev/null \
          | grep -E 'UNVERIFIED[^C]*\|[[:space:]]*(->|→|==?|treated as|maps? to|same as|equivalent to)[[:space:]`]*CLEAN' \
          || true)
    [ -z "$eq" ] || { fail "C10a: UNVERIFIED equated with CLEAN: $eq"; c10_ok=0; }
    [ -z "$eq2" ] || { fail "C10a: UNVERIFIED equated with CLEAN via pipe-separated form: $eq2"; c10_ok=0; }

    # (b) Refusal branches must not restate the old contribution (proposal criterion 6).
    local old
    old=$(grep -rn 'verdict_contribution: CLEAN' \
            "$sk/qa-browser/SKILL.md" "$sk/qa-visual/SKILL.md" 2>/dev/null || true)
    [ -z "$old" ] || { fail "C10b: refusal branch still returns CLEAN: $old"; c10_ok=0; }

    # (c) The refusal branches must still forbid fabrication — 3 per runtime skill (criterion 7).
    local f
    for f in qa-browser qa-visual; do
        local n
        n=$(grep -cF 'Do NOT fabricate findings from static reading' "$sk/$f/SKILL.md" 2>/dev/null || true)
        [ "$n" -eq 3 ] || { fail "C10c: $f has $n fabrication guards, expected 3"; c10_ok=0; }
    done

    # (d) The verdict template must carry BOTH tokens (M3).
    local tmpl="$sk/qa-report/SKILL.md"
    grep -qF -- '### Verdict: {verdict}{runtime_suffix}' "$tmpl" \
        || { fail "C10d: qa-report verdict template lost {runtime_suffix}"; c10_ok=0; }
    if grep -qE '^### Verdict: \{verdict\}[^{]*$' "$tmpl"; then
        fail "C10d: qa-report contains an unsuffixed verdict template line"; c10_ok=0
    fi

    # (e) R5 containment: UNVERIFIED lives in exactly 4 agent files, no more.
    # xargs -r (--no-run-if-empty) prevents "basename: missing operand" when agents/ dir is absent.
    local got want
    got=$(grep -rlF 'UNVERIFIED' "$ag" 2>/dev/null | xargs -r -n1 basename | sed 's/\.md$//' | sort || true)
    want=$(printf 'qa-browser\nqa-report\nqa-scan\nqa-visual')
    [ "$got" = "$want" ] || { fail "C10e: UNVERIFIED agent set is {$got}, expected {qa-browser,qa-report,qa-scan,qa-visual}"; c10_ok=0; }

    [ "$c10_ok" -eq 1 ] && pass "C10 unverified-not-clean: UNVERIFIED is distinct, contained, and structurally rendered"
}

# C11 — Coverage-resolution mapping check.
# Pins three semantic invariants in qa-report/SKILL.md that static presence checks cannot catch:
# (a) Step 3b ELSE branch MUST resolve to `unverified`, never `verified` — the semantic core of
#     the runtime-routing change. A one-word flip here silently allows bare APPROVE under recommendation.
# (b) Step 8 return envelope MUST declare runtime_coverage as a returned field.
# (c) Step 8 return envelope MUST declare runtime_unverified_reason as a returned field.
# Usage: check_c11_coverage_resolution_mapping [<corpus-root>]
check_c11_coverage_resolution_mapping() {
    local root="${1:-.}" c11_ok=1
    local sk="$root/skills/qa-report/SKILL.md"

    if [ ! -f "$sk" ]; then
        fail "C11: skills/qa-report/SKILL.md not found at $sk"
        return
    fi

    # (a) Step 3b ELSE branch must resolve to unverified.
    # The file must contain the exact string "→ unverified" after an "ELSE:" line, with no "→ verified"
    # in the ELSE branch. We detect by checking the file contains the ELSE branch text with unverified
    # and does NOT contain a pattern where ELSE directly precedes verified resolution.
    # Positive check: "ELSE:" followed within 3 lines by "→ unverified"
    if ! awk '
        /^    ELSE:/ { in_else=1; count=0 }
        in_else { count++ }
        in_else && /→ unverified/ { found=1; exit }
        in_else && count > 4 { in_else=0 }
        END { exit !found }
    ' "$sk"; then
        fail "C11a: Step 3b ELSE branch does not resolve to unverified in $sk — flip protection failed"
        c11_ok=0
    fi

    # Negative check: the ELSE branch must NOT resolve to verified.
    # This fires if someone flips "→ unverified" to "→ verified" in the ELSE block.
    if awk '
        /^    ELSE:/ { in_else=1; count=0 }
        in_else { count++ }
        in_else && /→ verified/ { found=1; exit }
        in_else && count > 4 { in_else=0 }
        END { exit !found }
    ' "$sk" 2>/dev/null; then
        fail "C11a: Step 3b ELSE branch resolves to 'verified' — must be 'unverified'. This is the semantic core of runtime-routing"
        c11_ok=0
    fi

    # (b) Step 8 envelope must declare runtime_coverage.
    if ! grep -qF 'runtime_coverage:' "$sk"; then
        fail "C11b: Step 8 envelope in $sk does not declare runtime_coverage — orchestrators cannot read what is not returned"
        c11_ok=0
    fi

    # (c) Step 8 envelope must declare runtime_unverified_reason.
    if ! grep -qF 'runtime_unverified_reason:' "$sk"; then
        fail "C11c: Step 8 envelope in $sk does not declare runtime_unverified_reason — agents/qa-report.md promises this field"
        c11_ok=0
    fi

    [ "$c11_ok" -eq 1 ] && pass "C11 coverage-resolution-mapping: Step 3b ELSE→unverified, envelope has runtime_coverage + runtime_unverified_reason"
}

# C12 — Orchestrator file set derivation check.
# Derives the expected orchestrator file set from examples/*/qase.json orchestrator.source
# and asserts the required table in rule-ownership.md covers exactly that set.
# A newly-added orchestrator tool that is unpinned in the required table fails this check —
# which is exactly how CRITICAL-1 (opencode.json) was silently missed the first time.
# Usage: check_c12_orchestrator_set_parity <registry-file> [<corpus-root>]
check_c12_orchestrator_set_parity() {
    local reg="$1" root="${2:-.}" c12_ok=1

    # Derive the expected set from qase.json orchestrator.source fields.
    local derived_set=()
    local ex_dir="$root/examples"
    if [ ! -d "$ex_dir" ]; then
        fail "C12: examples/ directory not found at $ex_dir"
        return
    fi

    local qf
    while IFS= read -r qf; do
        local dir
        dir="$(dirname "$qf")"
        # Extract orchestrator.source via grep+sed (no jq dependency in the linter).
        # The "|| true" prevents set -eo pipefail from aborting when grep finds no match.
        local src
        src=$(grep -o '"source":[[:space:]]*"[^"]*"' "$qf" 2>/dev/null \
              | sed 's/.*"source":[[:space:]]*"//;s/"//' \
              | head -1 || true)
        [ -z "$src" ] && continue
        local abs_path="$dir/$src"
        # Normalise to relative path from root.
        local rel_path="${abs_path#$root/}"
        derived_set+=("$rel_path")
    done < <(find "$ex_dir" -maxdepth 2 -name 'qase.json' | sort)

    if [ "${#derived_set[@]}" -eq 0 ]; then
        fail "C12: no qase.json files with orchestrator.source found under $ex_dir"
        return
    fi

    # Build the pinned set from the required table (all unique file paths across all rows).
    local pinned_set=()
    while IFS=$'\t' read -r id literal files min_n; do
        [ -z "$id" ] && continue
        local flist_str="$files"
        while [ -n "$flist_str" ]; do
            local f="${flist_str%%,*}"
            flist_str="${flist_str#"$f"}"; flist_str="${flist_str#,}"; f="${f// /}"
            [ -z "$f" ] && continue
            pinned_set+=("$f")
        done
    done < <(coh_table "$reg" required)

    # Deduplicate and sort both sets.
    # Use "${arr[@]+"${arr[@]}"}" to avoid set -u failure on empty arrays.
    local derived_sorted pinned_sorted
    derived_sorted=$(printf '%s\n' "${derived_set[@]+"${derived_set[@]}"}" | sort -u || true)
    pinned_sorted=$(printf '%s\n' "${pinned_set[@]+"${pinned_set[@]}"}" | sort -u || true)

    # Every derived orchestrator must appear in the pinned set.
    local missing=0
    while IFS= read -r dp; do
        if ! echo "$pinned_sorted" | grep -qxF "$dp"; then
            fail "C12: orchestrator '$dp' (from qase.json) is NOT pinned in the required table — add it to all required rows"
            c12_ok=0
            missing=$((missing + 1))
        fi
    done <<< "$derived_sorted"

    # Every pinned path must exist as a file (catches stale rows).
    while IFS= read -r pp; do
        [[ "$pp" == /* ]] || pp="$root/$pp"
        if [ ! -f "$pp" ]; then
            fail "C12: required table pins '$pp' but the file does not exist — remove stale row or create the file"
            c12_ok=0
        fi
    done <<< "$pinned_sorted"

    [ "$c12_ok" -eq 1 ] && pass "C12 orchestrator-set-parity: derived set from qase.json equals pinned required table (${#derived_set[@]} orchestrators)"
}

# run_coherence_checks — orchestrates C1-C12 in order.
# Usage: run_coherence_checks <corpus-root>
run_coherence_checks() {
    local root="${1:-.}"
    local reg="$root/skills/_shared/qase/rule-ownership.md"

    if [ ! -f "$reg" ]; then
        fail "Coherence: rule-ownership.md not found at $reg"
        return
    fi

    check_c1_forbidden_token "$reg" "$root"
    check_c2_undefined_placeholder "$reg" "$root"
    check_c3_derivation_anchor "$reg" "$root"
    check_c4_single_source "$reg" "$root"
    check_c5_bijection "$root"
    check_c6_agent_shape "$root"
    check_c7_capability "$root"
    check_c8_no_self_write "$root"
    check_c9_required_literal "$reg" "$root"
    check_c10_unverified_not_clean "$root"
    check_c11_coverage_resolution_mapping "$root"
    check_c12_orchestrator_set_parity "$reg" "$root"
}
