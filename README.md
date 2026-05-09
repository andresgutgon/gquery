# gleam_query

A type-safe async data fetching and caching library for Gleam, inspired by [TanStack Query](https://tanstack.com/query).

Tracks the full lifecycle of remote data — `NotAsked → Loading → Loaded | Failed` — with stale-while-revalidate built in. The core is framework-agnostic pure Gleam; a first-class [Lustre](https://lustre.build) integration is included.

## Installation

```sh
gleam add gleam_query
```

## Core concept

Every piece of remote data is an `Entry`:

```gleam
pub type Entry(data, err) {
  NotAsked                      // no fetch attempted yet
  Loading(stale: Option(data))  // fetching — stale data available for display
  Loaded(data: data, at: Int)   // succeeded — `at` is Unix ms timestamp
  Failed(err: err)              // last fetch failed
}
```

`gleam_query` never stores data for you. You own the cache — a plain record in your app model — and use `Entry` as the value type. This keeps the cache fully typed and under your control.

## Usage with Lustre

### 1. Define your cache

```gleam
import gleam/dict.{type Dict}
import gleam_query.{type Entry}

pub type Cache {
  Cache(
    contacts: Dict(String, Entry(List(Contact), ApiError)),
    contact:  Dict(Int,    Entry(Contact, ApiError)),
  )
}
```

### 2. Add it to your app model

```gleam
pub type Model {
  Model(page: Page, cache: Cache)
}
```

### 3. Query data

Call `gleam_query/lustre.query` inside `update` whenever you need remote data. It checks staleness and fires the fetch only when necessary.

```gleam
import gleam_query/lustre as gq

// in your Msg type:
pub type Msg {
  UserNavigatedToContacts(key: String)
  CacheGotContacts(key: String, result: Result(List(Contact), ApiError))
}

// in update:
UserNavigatedToContacts(key) -> {
  let entry =
    dict.get(model.cache.contacts, key)
    |> result.unwrap(gleam_query.NotAsked)

  let #(new_entry, eff) = gq.query(
    entry:     entry,
    stale_ms:  30_000,
    fetch:     contact_service.list(params),
    on_result: fn(result) { CacheGotContacts(key, result) },
  )

  let cache =
    Cache(..model.cache,
      contacts: dict.insert(model.cache.contacts, key, new_entry),
    )
  #(Model(..model, cache: cache), eff)
}
```

- **Fresh entry** → no fetch, `effect.none()` returned immediately.
- **Stale or missing** → entry moves to `Loading(stale_data)` so the UI can
  keep displaying previous data, and the fetch effect fires.

### 4. Handle the result

```gleam
CacheGotContacts(key, result) -> {
  let entry = gq.record(result)
  let contacts = dict.insert(model.cache.contacts, key, entry)
  #(Model(..model, cache: Cache(..model.cache, contacts: contacts)), effect.none())
}
```

### 5. Render with stale data

`get_data` returns data for both `Loaded` and `Loading(Some(_))`, so the UI
can always show something while a background revalidation is in progress.

```gleam
case gleam_query.get_data(entry) {
  option.Some(contacts) -> view_table(contacts, loading: entry == gleam_query.Loading)
  option.None -> view_spinner()
}
```

### 6. Invalidate after a mutation

After a write, mark related cache entries stale. The next navigation will
trigger a background refetch automatically.

```gleam
UserSavedContact -> {
  let contacts =
    dict.map_values(model.cache.contacts, fn(_, e) { gleam_query.invalidate(e) })
  #(
    Model(..model, cache: Cache(..model.cache, contacts: contacts)),
    save_contact_effect(),
  )
}
```

## API reference

### `gleam_query` — pure core

| Symbol | Description |
|---|---|
| `type Entry(data, err)` | The four-state lifecycle type |
| `is_stale(entry, stale_ms, now_ms)` | `True` when entry needs a fresh fetch |
| `get_data(entry)` | Returns data from `Loaded` or `Loading(Some(_))` |
| `invalidate(entry)` | Marks loaded data stale; preserves it for display |
| `record(result, now_ms)` | Builds an `Entry` from a `Result` and timestamp |
| `always_stale` | Constant `0` — always refetch |
| `never_stale` | Constant `max_int` — fetch once, never expire |

### `gleam_query/lustre` — Lustre integration

| Function | Description |
|---|---|
| `query(entry:, stale_ms:, fetch:, on_result:)` | Fetches if stale, returns `#(Entry, Effect(msg))` |
| `record(result)` | Records a fetch result timestamped to `Date.now()` |

## Design notes

**Why own your cache?**  
Gleam's type system makes a single heterogeneous cache (like react-query's `QueryCache`) awkward without `Dynamic`. Owning a typed record is idiomatic, explicit, and zero overhead.

**Why no automatic background refetch on focus/reconnect?**  
These are opt-in Lustre effect subscriptions that belong in your app. `gleam_query` stays small and composable so you wire them how you like.

**Erlang target?**  
`gleam_query/lustre` uses `Date.now()` via JavaScript FFI and requires `target = "javascript"`. The core `gleam_query` module is pure Gleam with no FFI; an Erlang-compatible wrapper is feasible if there is demand.

## Licence

MIT
