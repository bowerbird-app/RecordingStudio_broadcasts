# frozen_string_literal: true

require "test_helper"

class DevisePagesTest < ActionDispatch::IntegrationTest
  test "a wrong password shows the Devise alert" do
    get "/users/sign_in"
    assert_response :success

    post "/users/sign_in", params: { user: { email: "admin@admin.com", password: "wrong-password" } }

    assert_response :unprocessable_content
    assert_includes response.body, "Invalid email or password."
    assert_includes response.body, "role=\"alert\""
  end

  test "sign up, forgot password, and reset use the centered flatpack card" do
    get "/users/sign_up"
    assert_response :success
    assert_includes response.body, "Sign up"
    assert_includes response.body, "fp-card"
    assert_includes response.body, "max-w-md"

    get "/users/password/new"
    assert_response :success
    assert_includes response.body, "Forgot your password?"
    assert_includes response.body, "fp-card"

    get "/users/password/edit", params: { reset_password_token: "sample-token" }
    assert_response :success
    assert_includes response.body, "Change your password"
    assert_includes response.body, "reset_password_token"
  end

  test "an empty sign up shows the flatpack error alert" do
    post "/users", params: { user: { email: "", password: "", password_confirmation: "" } }

    assert_response :unprocessable_content
    assert_includes response.body, "prohibited this user from being saved"
    assert_includes response.body, "role=\"alert\""
  end
end
