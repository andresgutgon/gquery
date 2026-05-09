import gleam/option
import gleam_query
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// --- is_stale ---

pub fn is_stale_not_asked_test() {
  gleam_query.NotAsked
  |> gleam_query.is_stale(30_000, 0)
  |> should.be_true
}

pub fn is_stale_failed_test() {
  gleam_query.Failed("error")
  |> gleam_query.is_stale(30_000, 0)
  |> should.be_true
}

pub fn is_stale_loading_test() {
  gleam_query.Loading(stale: option.None)
  |> gleam_query.is_stale(30_000, 99_999)
  |> should.be_false
}

pub fn is_stale_loaded_fresh_test() {
  gleam_query.Loaded(data: "x", at: 1000)
  |> gleam_query.is_stale(30_000, 5000)
  |> should.be_false
}

pub fn is_stale_loaded_exactly_on_boundary_test() {
  gleam_query.Loaded(data: "x", at: 0)
  |> gleam_query.is_stale(30_000, 30_000)
  |> should.be_true
}

pub fn is_stale_loaded_past_boundary_test() {
  gleam_query.Loaded(data: "x", at: 0)
  |> gleam_query.is_stale(30_000, 30_001)
  |> should.be_true
}

pub fn is_stale_always_stale_test() {
  gleam_query.Loaded(data: "x", at: 0)
  |> gleam_query.is_stale(gleam_query.always_stale, 0)
  |> should.be_true
}

pub fn is_stale_never_stale_test() {
  gleam_query.Loaded(data: "x", at: 0)
  |> gleam_query.is_stale(gleam_query.never_stale, 999_999_999)
  |> should.be_false
}

// --- get_data ---

pub fn get_data_loaded_test() {
  gleam_query.Loaded(data: "hello", at: 0)
  |> gleam_query.get_data
  |> should.equal(option.Some("hello"))
}

pub fn get_data_loading_with_stale_test() {
  gleam_query.Loading(stale: option.Some("cached"))
  |> gleam_query.get_data
  |> should.equal(option.Some("cached"))
}

pub fn get_data_loading_no_stale_test() {
  gleam_query.Loading(stale: option.None)
  |> gleam_query.get_data
  |> should.equal(option.None)
}

pub fn get_data_not_asked_test() {
  gleam_query.NotAsked
  |> gleam_query.get_data
  |> should.equal(option.None)
}

pub fn get_data_failed_test() {
  gleam_query.Failed("err")
  |> gleam_query.get_data
  |> should.equal(option.None)
}

// --- invalidate ---

pub fn invalidate_loaded_preserves_stale_data_test() {
  gleam_query.Loaded(data: "x", at: 0)
  |> gleam_query.invalidate
  |> should.equal(gleam_query.Loading(stale: option.Some("x")))
}

pub fn invalidate_loading_is_noop_test() {
  let entry = gleam_query.Loading(stale: option.Some("x"))
  entry
  |> gleam_query.invalidate
  |> should.equal(entry)
}

pub fn invalidate_not_asked_is_noop_test() {
  gleam_query.NotAsked
  |> gleam_query.invalidate
  |> should.equal(gleam_query.NotAsked)
}

pub fn invalidate_failed_resets_to_not_asked_test() {
  gleam_query.Failed("err")
  |> gleam_query.invalidate
  |> should.equal(gleam_query.NotAsked)
}

// --- record ---

pub fn record_ok_creates_loaded_test() {
  gleam_query.record(Ok("data"), 1000)
  |> should.equal(gleam_query.Loaded(data: "data", at: 1000))
}

pub fn record_error_creates_failed_test() {
  gleam_query.record(Error("oops"), 1000)
  |> should.equal(gleam_query.Failed("oops"))
}
