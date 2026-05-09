import gleam/option
import gquery
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// --- is_stale ---

pub fn is_stale_not_asked_test() {
  gquery.NotAsked
  |> gquery.is_stale(30_000, 0)
  |> should.be_true
}

pub fn is_stale_failed_test() {
  gquery.Failed("error")
  |> gquery.is_stale(30_000, 0)
  |> should.be_true
}

pub fn is_stale_loading_test() {
  gquery.Loading(stale: option.None)
  |> gquery.is_stale(30_000, 99_999)
  |> should.be_false
}

pub fn is_stale_loaded_fresh_test() {
  gquery.Loaded(data: "x", at: 1000)
  |> gquery.is_stale(30_000, 5000)
  |> should.be_false
}

pub fn is_stale_loaded_exactly_on_boundary_test() {
  gquery.Loaded(data: "x", at: 0)
  |> gquery.is_stale(30_000, 30_000)
  |> should.be_true
}

pub fn is_stale_loaded_past_boundary_test() {
  gquery.Loaded(data: "x", at: 0)
  |> gquery.is_stale(30_000, 30_001)
  |> should.be_true
}

pub fn is_stale_always_stale_test() {
  gquery.Loaded(data: "x", at: 0)
  |> gquery.is_stale(gquery.always_stale, 0)
  |> should.be_true
}

pub fn is_stale_never_stale_test() {
  gquery.Loaded(data: "x", at: 0)
  |> gquery.is_stale(gquery.never_stale, 999_999_999)
  |> should.be_false
}

// --- get_data ---

pub fn get_data_loaded_test() {
  gquery.Loaded(data: "hello", at: 0)
  |> gquery.get_data
  |> should.equal(option.Some("hello"))
}

pub fn get_data_loading_with_stale_test() {
  gquery.Loading(stale: option.Some("cached"))
  |> gquery.get_data
  |> should.equal(option.Some("cached"))
}

pub fn get_data_loading_no_stale_test() {
  gquery.Loading(stale: option.None)
  |> gquery.get_data
  |> should.equal(option.None)
}

pub fn get_data_not_asked_test() {
  gquery.NotAsked
  |> gquery.get_data
  |> should.equal(option.None)
}

pub fn get_data_failed_test() {
  gquery.Failed("err")
  |> gquery.get_data
  |> should.equal(option.None)
}

// --- invalidate ---

pub fn invalidate_loaded_preserves_stale_data_test() {
  gquery.Loaded(data: "x", at: 0)
  |> gquery.invalidate
  |> should.equal(gquery.Loading(stale: option.Some("x")))
}

pub fn invalidate_loading_is_noop_test() {
  let entry = gquery.Loading(stale: option.Some("x"))
  entry
  |> gquery.invalidate
  |> should.equal(entry)
}

pub fn invalidate_not_asked_is_noop_test() {
  gquery.NotAsked
  |> gquery.invalidate
  |> should.equal(gquery.NotAsked)
}

pub fn invalidate_failed_resets_to_not_asked_test() {
  gquery.Failed("err")
  |> gquery.invalidate
  |> should.equal(gquery.NotAsked)
}

// --- record ---

pub fn record_ok_creates_loaded_test() {
  gquery.record(Ok("data"), 1000)
  |> should.equal(gquery.Loaded(data: "data", at: 1000))
}

pub fn record_error_creates_failed_test() {
  gquery.record(Error("oops"), 1000)
  |> should.equal(gquery.Failed("oops"))
}
