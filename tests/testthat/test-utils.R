context("utils")

test_that("assertions", {
  expect_error(assert_logical("a"), "must be a logical")
  expect_error(assert_logical(1), "must be a logical")

  expect_error(assert_character(1), "must be a character")
  expect_error(assert_character(TRUE), "must be a character")

  expect_error(assert_scalar(NULL), "must be a scalar")
  expect_error(assert_scalar(1:2), "must be a scalar")

  expect_error(assert_nonmissing(NA), "must not be NA")
  expect_error(assert_nonmissing(NA_integer_), "must not be NA")

  expect_error(assert_scalar_positive_integer(-1), "must be a positive integer")
  expect_error(assert_scalar_positive_integer(0), "must be a positive integer")
  expect_silent(assert_scalar_positive_integer(0, TRUE))

  expect_error(assert_integer_like(pi), "is not integer like")
})
