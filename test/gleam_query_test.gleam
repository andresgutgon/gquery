import gleam/option
import gleam_query
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn is_stale_not_asked_test() {
  gleam_query.NotAsked
  |> gleam_query.is_stale(30_000, 0)
  |> should.be_true
}

pub fn is_stale_loaded_fresh_test() {
  gleam_query.Loaded(data: "x", at: 1000)
  |> gleam_query.is_stale(30_000, 5000)
  |> should.be_false
}

pub fn is_stale_loaded_stale_test() {
  gleam_query.Loaded(data: "x", at: 0)
  |> gleam_query.is_stale(30_000, 31_000)
  |> should.be_true
}

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

pub fn invalidate_loaded_test() {
  gleam_query.Loaded(data: "x", at: 0)
  |> gleam_query.invalidate
  |> should.equal(gleam_query.Loading(stale: option.Some("x")))
}
