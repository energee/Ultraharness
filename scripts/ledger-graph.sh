#!/usr/bin/env bash
# ledger-graph.sh — deterministic, read-only readiness analysis for a seeded ledger.
# Scheduling fields are optional; incomplete actionable entries keep serial fallback.
set -u

GRAPH_CONTRACT_VERSION=1
export LC_ALL=C

usage_error() {
  printf '%s\n' \
    "error: expected exactly one seeded ledger path" \
    "root cause: ledger-graph.sh received $# path arguments; it requires one readable Markdown ledger" \
    "safe next action: rerun as bash scripts/ledger-graph.sh <target>/.agents/ledger.md" \
    "stop condition: do not schedule or mutate findings until a ledger can be analyzed"
  exit 2
}

[ "$#" -eq 1 ] || usage_error "$@"

LEDGER_ARG=$1
if [ ! -f "$LEDGER_ARG" ] || [ ! -r "$LEDGER_ARG" ]; then
  printf '%s\n' \
    "error: ledger is not a readable file: $LEDGER_ARG" \
    "root cause: the supplied path is missing, is not a regular file, or cannot be read" \
    "safe next action: supply the seeded target's .agents/ledger.md path and check its permissions" \
    "stop condition: do not schedule or mutate findings until the ledger is readable"
  exit 2
fi

if ! LEDGER_DIR=$(cd "$(dirname "$LEDGER_ARG")" && pwd); then
  printf '%s\n' \
    "error: ledger parent directory cannot be resolved: $LEDGER_ARG" \
    "root cause: the parent directory is inaccessible or disappeared during analysis" \
    "safe next action: restore directory access, confirm the ledger path, and rerun this command" \
    "stop condition: do not schedule or mutate findings until the ledger path resolves"
  exit 2
fi
LEDGER="$LEDGER_DIR/$(basename "$LEDGER_ARG")"

awk -v ledger="$LEDGER" -v contract="$GRAPH_CONTRACT_VERSION" '
function trim(value) {
  sub(/^[[:space:]]+/, "", value)
  sub(/[[:space:]]+$/, "", value)
  return value
}

function add_malformed(message) {
  if (!malformed_seen[message]++) malformed[++malformed_count] = message
}

function reset_current(    i) {
  for (i = 1; i <= c_read_path_count; i++) delete c_read_path[i]
  for (i = 1; i <= c_write_path_count; i++) delete c_write_path[i]
  in_section = 0
  c_slug = ""
  c_heading_line = 0
  c_finding = ""
  c_status = ""
  c_id = ""
  c_depends = ""
  c_read_path_count = 0
  c_write_path_count = 0
  c_acceptance = ""
  c_evidence = ""
  c_fixed_by = ""
  c_verified_by = ""
  c_observed_at = ""
  c_attempted_in = ""
  c_learning = ""
  c_finding_seen = c_status_seen = 0
  c_id_seen = c_depends_seen = c_read_path_seen = c_write_path_seen = 0
  c_acceptance_seen = c_evidence_seen = c_fixed_by_seen = 0
  c_verified_by_seen = c_observed_at_seen = c_attempted_in_seen = 0
  c_learning_seen = 0
}

function duplicate_field(key) {
  add_malformed("line " NR " " c_slug ": duplicate graph field " key)
}

function finish_current(    i, j) {
  if (!in_section || !c_finding_seen) return
  i = ++entry_count
  slug[i] = c_slug
  heading_line[i] = c_heading_line
  finding[i] = c_finding
  status[i] = c_status
  id[i] = c_id
  depends_raw[i] = c_depends
  for (j = 1; j <= c_read_path_count; j++) read_path_raw[i, j] = c_read_path[j]
  for (j = 1; j <= c_write_path_count; j++) write_path_raw[i, j] = c_write_path[j]
  read_path_raw_count[i] = c_read_path_count
  write_path_raw_count[i] = c_write_path_count
  acceptance[i] = c_acceptance
  evidence[i] = c_evidence
  fixed_by[i] = c_fixed_by
  verified_by[i] = c_verified_by
  observed_at[i] = c_observed_at
  attempted_in[i] = c_attempted_in
  learning[i] = c_learning
  has_status[i] = c_status_seen
  has_id[i] = c_id_seen
  has_depends[i] = c_depends_seen
  has_read_path[i] = c_read_path_seen
  has_write_path[i] = c_write_path_seen
  has_acceptance[i] = c_acceptance_seen
  has_evidence[i] = c_evidence_seen
  has_fixed_by[i] = c_fixed_by_seen
  has_verified_by[i] = c_verified_by_seen
  has_observed_at[i] = c_observed_at_seen
  has_attempted_in[i] = c_attempted_in_seen
  has_learning[i] = c_learning_seen
}

function set_field(key, value) {
  if (key == "finding") {
    c_finding = value
    c_finding_seen = 1
  } else if (key == "status") {
    c_status = value
    c_status_seen = 1
  } else if (key == "id") {
    if (c_id_seen) duplicate_field(key)
    c_id = value
    c_id_seen = 1
  } else if (key == "depends-on") {
    if (c_depends_seen) duplicate_field(key)
    c_depends = value
    c_depends_seen = 1
  } else if (key == "read-path") {
    c_read_path[++c_read_path_count] = value
    c_read_path_seen = 1
  } else if (key == "write-path") {
    c_write_path[++c_write_path_count] = value
    c_write_path_seen = 1
  } else if (key == "reads") {
    add_malformed("line " NR " " c_slug ": deprecated graph field reads; use repeatable read-path")
  } else if (key == "writes") {
    add_malformed("line " NR " " c_slug ": deprecated graph field writes; use repeatable write-path")
  } else if (key == "acceptance") {
    if (c_acceptance_seen) duplicate_field(key)
    c_acceptance = value
    c_acceptance_seen = 1
  } else if (key == "evidence") {
    if (c_evidence_seen) c_evidence = c_evidence " ; " value
    else c_evidence = value
    c_evidence_seen = 1
  } else if (key == "fixed-by") {
    if (c_fixed_by_seen) duplicate_field(key)
    c_fixed_by = value
    c_fixed_by_seen = 1
  } else if (key == "verified-by") {
    if (c_verified_by_seen) duplicate_field(key)
    c_verified_by = value
    c_verified_by_seen = 1
  } else if (key == "observed-at") {
    if (c_observed_at_seen) duplicate_field(key)
    c_observed_at = value
    c_observed_at_seen = 1
  } else if (key == "attempted-in") {
    if (c_attempted_in_seen) duplicate_field(key)
    c_attempted_in = value
    c_attempted_in_seen = 1
  } else if (key == "learning") {
    if (c_learning_seen) c_learning = c_learning " ; " value
    else c_learning = value
    c_learning_seen = 1
  }
}

function valid_commit(value) {
  return value ~ /^[0-9A-Fa-f]+$/ && length(value) >= 7 && length(value) <= 64
}

function normalize_path(value, field, owner,    path) {
  path = trim(value)
  if (substr(path, 1, 1) == "`" || substr(path, length(path), 1) == "`") {
    if (length(path) < 2 || substr(path, 1, 1) != "`" || substr(path, length(path), 1) != "`") {
      add_malformed("line " heading_line[owner] " " label(owner) ": " field " path has an unmatched backtick: " path)
      return ""
    }
    path = substr(path, 2, length(path) - 2)
    path = trim(path)
  }
  if (path == "") {
    add_malformed("line " heading_line[owner] " " label(owner) ": " field " contains an empty path")
    return ""
  }
  if (index(path, "\\") || index(path, "*") || index(path, "?") || index(path, "[")) {
    add_malformed("line " heading_line[owner] " " label(owner) ": " field " path \047" path "\047 must be a concrete slash-separated path")
    return ""
  }
  while (index(path, "//")) gsub(/\/\//, "/", path)
  while (substr(path, 1, 2) == "./") path = substr(path, 3)
  while (length(path) > 0 && substr(path, length(path), 1) == "/") path = substr(path, 1, length(path) - 1)
  if (substr(path, 1, 1) == "/" || path ~ /^[A-Za-z]:[\\\/]/) {
    add_malformed("line " heading_line[owner] " " label(owner) ": " field " path \047" path "\047 is not repository-relative")
    return ""
  }
  if (path == "" || path == "." || path == ".." || path ~ /(^|\/)\.\.?(\/|$)/) {
    add_malformed("line " heading_line[owner] " " label(owner) ": " field " path \047" path "\047 is not a normalized repository path")
    return ""
  }
  return path
}

function parse_dependencies(i, raw,    count, part, value, seen_key, values) {
  if (raw == "none") return
  count = split(raw, values, ",")
  for (part = 1; part <= count; part++) {
    value = trim(values[part])
    if (value == "") {
      add_malformed("line " heading_line[i] " " label(i) ": depends-on contains an empty list member")
      continue
    }
    if (value == "none") {
      add_malformed("line " heading_line[i] " " label(i) ": depends-on mixes none with dependency IDs")
      continue
    }
    if (value !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) {
      add_malformed("line " heading_line[i] " " label(i) ": invalid dependency ID \047" value "\047")
      continue
    }
    seen_key = i SUBSEP value
    if (dependency_seen[seen_key]++) {
      add_malformed("line " heading_line[i] " " label(i) ": duplicate dependency ID \047" value "\047")
      continue
    }
    dependency[i, ++dependency_count[i]] = value
  }
}

function parse_path(i, field, raw, occurrence_count,    value, path, seen_key) {
  value = trim(raw)
  if (value == "none") {
    if (occurrence_count > 1) {
      add_malformed("line " heading_line[i] " " label(i) ": " field " mixes none with paths")
    }
    return
  }
  if (value == "") {
    add_malformed("line " heading_line[i] " " label(i) ": " field " is empty; use none for an empty set")
    return
  }
  path = normalize_path(value, field, i)
  if (path == "") return
  seen_key = field SUBSEP i SUBSEP path
  if (normalized_path_seen[seen_key]++) {
    add_malformed("line " heading_line[i] " " label(i) ": " field " repeats normalized path \047" path "\047")
    return
  }
  if (field == "read-path") read_path[i, ++read_count[i]] = path
  else write_path[i, ++write_count[i]] = path
}

function active(i) {
  return status[i] == "open" || status[i] == "in-progress"
}

function valid_id_for(i) {
  return has_id[i] && id[i] != "none" && id[i] ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/
}

function label(i) {
  if (valid_id_for(i)) return id[i]
  return "legacy:" slug[i]
}

function display(i) {
  if (valid_id_for(i)) return id[i] " (" slug[i] "; " status[i] ")"
  return "legacy:" slug[i] " (" status[i] ")"
}

function owner_display(i) {
  if (valid_id_for(i)) return id[i] " (" slug[i] ")"
  return "legacy:" slug[i]
}

function append_csv(current, value) {
  return current == "" ? value : current ", " value
}

function dfs(i,    dep_id, j, k, pos, cycle) {
  visit_state[i] = 1
  stack[++stack_depth] = i
  stack_position[i] = stack_depth
  for (k = 1; k <= dependency_count[i]; k++) {
    dep_id = dependency[i, k]
    if (!(dep_id in id_index)) continue
    j = id_index[dep_id]
    if (!visit_state[j]) {
      dfs(j)
    } else if (visit_state[j] == 1) {
      cycle = ""
      for (pos = stack_position[j]; pos <= stack_depth; pos++) {
        cycle = cycle (cycle == "" ? "" : " -> ") id[stack[pos]]
      }
      cycle = cycle " -> " id[j]
      if (!cycle_seen[cycle]++) cycles[++cycle_count] = cycle
    }
  }
  visit_state[i] = 2
  delete stack_position[i]
  delete stack[stack_depth]
  stack_depth--
}

function paths_overlap(left, right) {
  return left == right || index(left, right "/") == 1 || index(right, left "/") == 1
}

function overlap_display(left, right) {
  return left == right ? left : left " <-> " right
}

function analyze(    i, j, k, m, dep_id, dep_entry, blockers, missing_fields,
                         verifier_commit, verifier_identity, at_pos, pair_overlap,
                         overlap, fatal_count) {
  if (!saw_boundary) add_malformed("ledger: missing --- documentation/entry boundary")

  for (i = 1; i <= entry_count; i++) {
    if (!has_status[i] || status[i] == "") {
      add_malformed("line " heading_line[i] " " label(i) ": finding has no status")
    } else if (status[i] != "open" && status[i] != "in-progress" && status[i] != "done" &&
               status[i] !~ /^parked\((context|capability|authority|proof|feedback)\)$/) {
      add_malformed("line " heading_line[i] " " label(i) ": invalid status \047" status[i] "\047")
    }

    if (has_id[i]) {
      if (id[i] == "none") {
        add_malformed("line " heading_line[i] " legacy:" slug[i] ": id \047none\047 is reserved for empty lists")
      } else if (id[i] == "" || id[i] !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) {
        add_malformed("line " heading_line[i] " legacy:" slug[i] ": invalid id \047" id[i] "\047")
      } else if (id[i] in id_index) {
        add_malformed("line " heading_line[i] " " id[i] ": duplicate id; first declared on line " heading_line[id_index[id[i]]])
      } else {
        id_index[id[i]] = i
      }
    }

    if (has_depends[i]) {
      if (depends_raw[i] == "") add_malformed("line " heading_line[i] " " label(i) ": depends-on is empty; use none for an empty set")
      else parse_dependencies(i, depends_raw[i])
    }
    if (has_read_path[i]) {
      for (k = 1; k <= read_path_raw_count[i]; k++) {
        parse_path(i, "read-path", read_path_raw[i, k], read_path_raw_count[i])
      }
    }
    if (has_write_path[i]) {
      for (k = 1; k <= write_path_raw_count[i]; k++) {
        parse_path(i, "write-path", write_path_raw[i, k], write_path_raw_count[i])
      }
    }
    if (has_acceptance[i] && (acceptance[i] == "" || acceptance[i] ~ /^<.*>$/)) {
      add_malformed("line " heading_line[i] " " label(i) ": acceptance is empty or still a placeholder")
    }
    if (has_evidence[i] && (evidence[i] == "" || evidence[i] == "none" || evidence[i] ~ /^<.*>$/)) {
      add_malformed("line " heading_line[i] " " label(i) ": evidence is empty, none, or still a placeholder")
    }
    if (has_fixed_by[i] && !valid_commit(fixed_by[i])) {
      add_malformed("line " heading_line[i] " " label(i) ": fixed-by must be a 7-64 digit hexadecimal commit ID")
    }
    if (has_observed_at[i] && !valid_commit(observed_at[i])) {
      add_malformed("line " heading_line[i] " " label(i) ": observed-at must be a 7-64 digit hexadecimal commit ID")
    }
    if (has_verified_by[i]) {
      at_pos = match(verified_by[i], / @ [0-9A-Fa-f]+$/)
      if (!at_pos) {
        add_malformed("line " heading_line[i] " " label(i) ": verified-by must be <identity> @ <commit>")
      } else {
        verifier_identity = trim(substr(verified_by[i], 1, at_pos - 1))
        verifier_commit = substr(verified_by[i], at_pos + 3)
        if (verifier_identity == "" || !valid_commit(verifier_commit)) {
          add_malformed("line " heading_line[i] " " label(i) ": verified-by must be <identity> @ <commit>")
        } else if (has_fixed_by[i] && valid_commit(fixed_by[i]) && tolower(verifier_commit) != tolower(fixed_by[i])) {
          add_malformed("line " heading_line[i] " " label(i) ": verified-by commit does not match fixed-by")
        }
      }
    }
    if (has_attempted_in[i] && (attempted_in[i] == "" || attempted_in[i] ~ /^<.*>$/)) {
      add_malformed("line " heading_line[i] " " label(i) ": attempted-in is empty or still a placeholder")
    }
    if (has_learning[i] && (learning[i] == "" || learning[i] ~ /^<.*>$/)) {
      add_malformed("line " heading_line[i] " " label(i) ": learning is empty or still a placeholder")
    }

    if (has_id[i] && status[i] == "done") {
      if (!has_evidence[i] || evidence[i] == "") add_malformed("line " heading_line[i] " " label(i) ": typed done finding requires evidence")
      if (!has_fixed_by[i] || fixed_by[i] == "") add_malformed("line " heading_line[i] " " label(i) ": typed done finding requires fixed-by")
      if (!has_verified_by[i] || verified_by[i] == "") add_malformed("line " heading_line[i] " " label(i) ": typed done finding requires verified-by")
    }

    if (active(i)) {
      missing_fields = ""
      if (!has_id[i]) missing_fields = append_csv(missing_fields, "id")
      if (!has_depends[i]) missing_fields = append_csv(missing_fields, "depends-on")
      if (!has_read_path[i]) missing_fields = append_csv(missing_fields, "read-path")
      if (!has_write_path[i]) missing_fields = append_csv(missing_fields, "write-path")
      if (!has_acceptance[i]) missing_fields = append_csv(missing_fields, "acceptance")
      if (missing_fields != "") {
        serial_fallback = 1
        fallback_reason[++fallback_count] = display(i) ": missing " missing_fields
      }
    }
  }

  for (i = 1; i <= entry_count; i++) {
    for (k = 1; k <= dependency_count[i]; k++) {
      dep_id = dependency[i, k]
      if (!(dep_id in id_index)) {
        missing_dependency[++missing_count] = dep_id " <- " owner_display(i)
      }
    }
  }

  for (i = 1; i <= entry_count; i++) {
    if (valid_id_for(i) && !visit_state[i]) dfs(i)
  }

  for (i = 1; i <= entry_count; i++) {
    if (!active(i)) continue
    blockers = ""
    for (k = 1; k <= dependency_count[i]; k++) {
      dep_id = dependency[i, k]
      if (!(dep_id in id_index)) {
        blockers = append_csv(blockers, dep_id " (missing)")
      } else {
        dep_entry = id_index[dep_id]
        if (status[dep_entry] != "done") blockers = append_csv(blockers, dep_id " (" status[dep_entry] ")")
      }
    }
    if (blockers == "") ready[++ready_count] = display(i)
    else blocked[++blocked_count] = display(i) " <- " blockers
  }

  for (i = 1; i <= entry_count; i++) {
    if (!active(i)) continue
    for (j = i + 1; j <= entry_count; j++) {
      if (!active(j)) continue
      pair_overlap = ""
      for (k = 1; k <= write_count[i]; k++) {
        for (m = 1; m <= write_count[j]; m++) {
          if (paths_overlap(write_path[i, k], write_path[j, m])) {
            overlap = overlap_display(write_path[i, k], write_path[j, m])
            pair_overlap = append_csv(pair_overlap, overlap)
          }
        }
      }
      if (pair_overlap != "") write_conflict[++conflict_count] = label(i) " <-> " label(j) ": " pair_overlap
    }
  }

  print "ledger-graph v" contract " — ledger: " ledger
  print "serial fallback required: " (serial_fallback ? "yes" : "no")

  print "ready findings:"
  if (!ready_count) print "  none"
  else for (i = 1; i <= ready_count; i++) print "  " ready[i]

  print "blocked findings:"
  if (!blocked_count) print "  none"
  else for (i = 1; i <= blocked_count; i++) print "  " blocked[i]

  print "dependency cycles:"
  if (!cycle_count) print "  none"
  else for (i = 1; i <= cycle_count; i++) print "  " cycles[i]

  print "missing dependency IDs:"
  if (!missing_count) print "  none"
  else for (i = 1; i <= missing_count; i++) print "  " missing_dependency[i]

  print "active write conflicts:"
  if (!conflict_count) print "  none"
  else for (i = 1; i <= conflict_count; i++) print "  " write_conflict[i]

  print "malformed graph fields:"
  if (!malformed_count) print "  none"
  else for (i = 1; i <= malformed_count; i++) print "  " malformed[i]

  print "serial fallback reasons:"
  if (!fallback_count) print "  none"
  else for (i = 1; i <= fallback_count; i++) print "  " fallback_reason[i]

  print "summary: ready=" (ready_count + 0) " blocked=" (blocked_count + 0) \
        " cycles=" (cycle_count + 0) " missing=" (missing_count + 0) \
        " conflicts=" (conflict_count + 0) " malformed=" (malformed_count + 0)

  fatal_count = malformed_count + cycle_count + missing_count
  if (fatal_count) {
    print "result: INVALID"
    print "root cause: malformed=" (malformed_count + 0) ", cycles=" (cycle_count + 0) \
          ", missing-dependencies=" (missing_count + 0)
    print "safe next action: correct the listed ledger entries, commit that record, and rerun this analyzer"
    print "stop condition: do not schedule, mutate, or merge findings while result is INVALID"
    exit 1
  }

  print "result: OK"
  if (serial_fallback) print "next action: preserve ledger rank and execute one ready finding at a time"
  else print "next action: use the ready and conflict sections as input to the bounded execution-wave contract"
  exit 0
}

BEGIN {
  reset_current()
}

$0 == "---" && !saw_boundary {
  saw_boundary = 1
  next
}

saw_boundary && /^## / {
  finish_current()
  reset_current()
  in_section = 1
  c_heading_line = NR
  heading = trim(substr($0, 4))
  separator = index(heading, " ")
  c_slug = separator ? trim(substr(heading, separator + 1)) : heading
  next
}

saw_boundary && in_section && /^- [A-Za-z][A-Za-z-]*:/ {
  field_line = substr($0, 3)
  colon = index(field_line, ":")
  key = substr(field_line, 1, colon - 1)
  value = trim(substr(field_line, colon + 1))
  set_field(key, value)
  next
}

END {
  finish_current()
  analyze()
}
' "$LEDGER"
AWK_RC=$?

if [ "$AWK_RC" -gt 1 ]; then
  printf '%s\n' \
    "error: ledger analysis could not complete" \
    "root cause: awk failed while reading or evaluating the ledger (exit $AWK_RC)" \
    "safe next action: confirm the ledger stayed readable and rerun; if it repeats, repair the analyzer before proceeding" \
    "stop condition: do not schedule or mutate findings without a complete analyzer report"
  exit 2
fi

exit "$AWK_RC"
