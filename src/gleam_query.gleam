import gleam/option.{type Option}

pub type Entry(data, err) {
  NotAsked
  Loading(stale: Option(data))
  Loaded(data: data, at: Int)
  Failed(err: err)
}

pub fn is_stale(entry: Entry(a, e), stale_ms: Int, now_ms: Int) -> Bool {
  case entry {
    Loaded(_, at) -> now_ms - at > stale_ms
    NotAsked -> True
    Failed(_) -> True
    Loading(_) -> False
  }
}

pub fn get_data(entry: Entry(a, e)) -> Option(a) {
  case entry {
    Loaded(data, _) -> option.Some(data)
    Loading(stale) -> stale
    NotAsked | Failed(_) -> option.None
  }
}

pub fn invalidate(entry: Entry(a, e)) -> Entry(a, e) {
  case entry {
    Loaded(data, _) -> Loading(stale: option.Some(data))
    Loading(_) -> entry
    NotAsked | Failed(_) -> NotAsked
  }
}

pub fn record(
  result: Result(data, err),
  at: Int,
) -> Entry(data, err) {
  case result {
    Ok(data) -> Loaded(data: data, at: at)
    Error(err) -> Failed(err)
  }
}
