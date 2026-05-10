import gleam/option.{type Option}
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
/// ### `placeholder`
///
/// Supply `placeholder` to implement the *keepPreviousData* pattern: when
/// switching to a new cache key, pass the old key's data as the placeholder so
/// the UI stays populated while the new fetch loads.  If the entry already has
/// its own data it always takes priority over `placeholder`.
///
/// ```gleam
/// import gquery/lustre as gq
///
/// UserChangedFilter(stage) -> {
///   let old_key = contacts.cache_key(model)
///   let new_model = Model(..model, filter_stage: stage)
///   let new_key = contacts.cache_key(new_model)
///   let entry = dict.get(cache, new_key) |> result.unwrap(gquery.NotAsked)
///   let placeholder =
///     dict.get(cache, old_key)
///     |> result.map(gquery.get_data)
///     |> result.unwrap(option.None)
///   let #(new_entry, eff) = gq.query(
///     entry:       entry,
///     stale_ms:    30_000,
///     placeholder: placeholder,
///     fetch:       contact_service.list(params),
///     on_result:   fn(result) { GotContacts(new_key, result) },
///   )
///   ...
/// }
/// ```
pub fn query(
  entry entry: Entry(data, err),
  stale_ms stale_ms: Int,
  placeholder placeholder: Option(data),
  fetch fetch: Effect(Result(data, err)),
  on_result on_result: fn(Result(data, err)) -> msg,
) -> #(Entry(data, err), Effect(msg)) {
  case gquery.is_stale(entry, stale_ms, now()) {
    False -> #(entry, effect.none())
    True -> {
      let loading = gquery.Loading(stale: gquery.stale_for(entry, placeholder))
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
