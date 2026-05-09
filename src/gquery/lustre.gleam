import gquery.{type Entry}
import lustre/effect.{type Effect}

@external(javascript, "./lustre_ffi.mjs", "now")
fn now() -> Int

/// Fetches data if the entry is stale, otherwise returns as-is.
///
/// This is the primary API for integrating `gleam_query` with Lustre. Call it
/// inside your `update` function whenever you need remote data. It decides
/// whether to fire a fetch based on the entry's age and your `stale_ms`
/// threshold.
///
/// - If the entry is **fresh** — returns the entry unchanged and `effect.none()`.
/// - If the entry is **stale or missing** — transitions it to
///   `Loading(stale_data)` (preserving any previous data for display) and
///   returns the fetch effect mapped through `on_result`.
///
/// ## Example
///
/// ```gleam
/// import gquery/lustre as gq
///
/// UserNavigatedToContacts(key) -> {
///   let entry =
///     dict.get(model.cache.contacts, key)
///     |> result.unwrap(gquery.NotAsked)
///   let #(new_entry, eff) = gq.query(
///     entry:     entry,
///     stale_ms:  30_000,
///     fetch:     contact_service.list(params),
///     on_result: fn(result) { CacheGotContacts(key, result) },
///   )
///   let cache = Cache(..model.cache, contacts: dict.insert(model.cache.contacts, key, new_entry))
///   #(Model(..model, cache: cache), eff)
/// }
/// ```
pub fn query(
  entry entry: Entry(data, err),
  stale_ms stale_ms: Int,
  fetch fetch: Effect(Result(data, err)),
  on_result on_result: fn(Result(data, err)) -> msg,
) -> #(Entry(data, err), Effect(msg)) {
  case gquery.is_stale(entry, stale_ms, now()) {
    False -> #(entry, effect.none())
    True -> {
      let loading = gquery.Loading(stale: gquery.get_data(entry))
      #(loading, effect.map(fetch, on_result))
    }
  }
}

/// Records a fetch result as a cache entry, timestamped to right now.
///
/// Call this in the `update` branch that handles your fetch response to
/// store the result back into your cache.
///
/// - `Ok(data)` → `Loaded(data, at: now())`
/// - `Error(err)` → `Failed(err)`
///
/// ## Example
///
/// ```gleam
/// import gquery/lustre as gq
///
/// CacheGotContacts(key, result) -> {
///   let entry = gq.record(result)
///   let contacts = dict.insert(model.cache.contacts, key, entry)
///   #(Model(..model, cache: Cache(..model.cache, contacts: contacts)), effect.none())
/// }
/// ```
pub fn record(result: Result(data, err)) -> Entry(data, err) {
  gquery.record(result, now())
}
