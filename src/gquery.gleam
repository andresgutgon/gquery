import gleam/option.{type Option}

/// Represents the full lifecycle of a remotely fetched value.
///
/// - `NotAsked`  — no fetch has been attempted yet.
/// - `Loading`   — a fetch is in progress. Carries optional stale data so the
///                 UI can display the previous value while revalidating.
/// - `Loaded`    — the last fetch succeeded. `at` is the Unix timestamp in
///                 milliseconds at which the data was recorded.
/// - `Failed`    — the last fetch failed with an error.
pub type Entry(data, err) {
  NotAsked
  Loading(stale: Option(data))
  Loaded(data: data, at: Int)
  Failed(err: err)
}

/// Pass to `stale_ms` to always consider an entry stale.
/// The fetch will fire on every call to `query`.
pub const always_stale: Int = 0

/// Pass to `stale_ms` to never consider a loaded entry stale.
/// The fetch fires only once; the data is kept until manually invalidated.
pub const never_stale: Int = 2_147_483_647

/// Returns `True` when the entry needs a fresh fetch.
///
/// - `NotAsked` and `Failed` are always considered stale.
/// - `Loading` is never stale (a fetch is already in flight).
/// - `Loaded` is stale when `now_ms - at > stale_ms`.
///
/// ```gleam
/// gleam_query.is_stale(entry, stale_ms: 30_000, now_ms: now())
/// ```
pub fn is_stale(entry: Entry(a, e), stale_ms: Int, now_ms: Int) -> Bool {
  case entry {
    NotAsked -> True
    Failed(_) -> True
    Loading(_) -> False
    Loaded(_, at) -> now_ms - at >= stale_ms
  }
}

/// Returns the most recent data held by the entry, if any.
///
/// Returns `Some(data)` for `Loaded` and `Loading(Some(data))` (stale-while-
/// revalidate). Returns `None` for `NotAsked`, `Failed`, and `Loading(None)`.
///
/// ```gleam
/// case gleam_query.get_data(entry) {
///   Some(contacts) -> render_list(contacts)
///   None -> render_empty()
/// }
/// ```
pub fn get_data(entry: Entry(a, e)) -> Option(a) {
  case entry {
    Loaded(data, _) -> option.Some(data)
    Loading(stale) -> stale
    NotAsked | Failed(_) -> option.None
  }
}

/// Marks a loaded entry as stale, transitioning it to `Loading` while
/// preserving the existing data for display during revalidation.
///
/// - `Loaded(data, _)` → `Loading(Some(data))`
/// - `Loading(_)`      → unchanged (fetch already in progress)
/// - `NotAsked`        → unchanged (nothing to preserve)
/// - `Failed(_)`       → `NotAsked` (retry from a clean state)
///
/// Call this after a successful mutation to trigger a background refetch
/// on the next access.
///
/// ```gleam
/// let contacts = dict.map_values(cache.contacts, fn(_, e) {
///   gleam_query.invalidate(e)
/// })
/// ```
pub fn invalidate(entry: Entry(a, e)) -> Entry(a, e) {
  case entry {
    Loaded(data, _) -> Loading(stale: option.Some(data))
    Loading(_) -> entry
    NotAsked -> entry
    Failed(_) -> NotAsked
  }
}

/// Creates an `Entry` from a fetch result and a current timestamp.
///
/// - `Ok(data)` → `Loaded(data, at: now_ms)`
/// - `Error(err)` → `Failed(err)`
///
/// Prefer `gleam_query/lustre.record` in Lustre apps — it captures the
/// current timestamp automatically.
///
/// ```gleam
/// let entry = gleam_query.record(result, now_ms: current_time_ms())
/// ```
pub fn record(result: Result(data, err), now_ms: Int) -> Entry(data, err) {
  case result {
    Ok(data) -> Loaded(data: data, at: now_ms)
    Error(err) -> Failed(err)
  }
}
