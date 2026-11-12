# frozen_string_literal: true

RecordingStudioApi.configure do |config|
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.api_request_logging_enabled = false
  config.api_management_authorization_required = false

  config.api :operations do |api|
    api.openapi_title = "Operations API"
    api.api_versions = %w[v1]
    api.default_access = :read_only
    api.api_management_authorization_required = false
    api.rate_limit_oauth_enabled = false
    api.rate_limit_api_pre_auth_enabled = false
    api.rate_limit_api_enabled = false
    api.api_request_logging_enabled = false
  end
end

RecordingStudioApi.register_recordable_type_api(
  "AdminRoot",
  api: :operations,
  operations: %i[index show],
  serializer: ->(recordable, **) { { name: recordable.name } },
  output_keys: %i[name]
)
