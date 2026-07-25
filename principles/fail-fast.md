# Fail fast — an operation that cannot do its job says so immediately

## Definition

An operation that cannot do what it was asked must report that at the point it happens,
with the context the caller needs to act. An error that is swallowed, defaulted away, or
returned as a benign-looking value is not handled — it is deferred to a later point in
the system where the evidence is gone and the symptom no longer names the cause.

This is about *where* a failure surfaces, not about crashing. Handling an error properly
at a boundary is failing fast; converting it into a plausible-looking value is not.

## How to spot it

- Empty or comment-only catch blocks: `catch {}`, `except: pass`, `rescue nil`,
  `if err != nil { }`. Greppable in most languages, and the highest-yield single search.
- Overbroad catches: `except Exception:`, `catch (Throwable)`, `catch (...)` around a
  block where exactly one call can realistically fail.
- Log-and-continue where the code cannot actually continue correctly — the error is
  written at `debug`/`warn` and execution proceeds as though it succeeded.
- Errors flattened into sentinel values: returning `null`, `nil`, `-1`, `""`, or an empty
  collection where the caller cannot distinguish "no result" from "it broke".
- Required configuration read with a silent default: `os.getenv("API_KEY", "")`,
  `?? ""`, `config.get(k, None)` on a value the system cannot run without. A missing
  credential then surfaces as a 401 three layers away.
- Validation deferred past a trust boundary: request bodies, CLI args, file contents, or
  env accepted unchecked and only rejected deep in the call stack, if at all.
- `try` blocks spanning far more than the statement that can fail, so an unrelated error
  is absorbed by a handler written for a different one.
- Async results never awaited or joined — a rejected promise, an unchecked goroutine
  error, a thread that dies alone. The failure vanishes with the task.

## How to fix it

Smallest intervention first:

1. **Narrow the catch** to the error the code genuinely handles, and let everything else
   propagate. Often a one-word change with the largest effect.
2. **Re-raise with context** instead of logging and continuing — `raise ... from err`,
   `fmt.Errorf("loading config: %w", err)`, `throw new Error(msg, { cause })`.
3. **Validate required config once, at startup**, so a missing key fails at boot naming
   the key, rather than at first use naming nothing.
4. **Move validation to the boundary** — reject malformed input where it enters the
   system, so nothing downstream has to re-check it.
5. **Make the failure unrepresentable in the return type** — `Result`/`Either`, a
   `(value, error)` pair, or an exception, rather than a sentinel the caller can ignore
   by accident. This is the largest change; reach for it when the same sentinel has
   already caused a bug.

## When NOT to apply

- **A retry loop, supervisor, or event pump that must survive one failure.** Swallowing
  is the design there — provided the error is recorded somewhere durable and the retries
  are bounded. Flag it only if the error is discarded silently or the loop is unbounded.
- **A top-level handler** whose job is to turn an exception into an HTTP response, an
  exit code, or a user-facing message. That is where propagation is supposed to stop.
- **Genuinely optional features degrading on purpose** — a missing analytics key, an
  unreachable cache. A default is correct when the system still meets its contract
  without the value. The test is the contract, not the presence of a default.
- **Cleanup in `finally`/`defer`/`ensure`.** An error there should be reported but must
  not replace the original failure; suppressing it to preserve the first exception is
  correct, not a defect.
- **A language where a sentinel is the idiom and the caller is forced to check it** —
  Go's `(T, error)` is fail-fast, not a violation, as long as the returned error is not
  discarded with `_`.
