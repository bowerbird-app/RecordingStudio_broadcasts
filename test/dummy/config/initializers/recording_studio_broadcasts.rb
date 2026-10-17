# frozen_string_literal: true

RecordingStudioBroadcasts.configure do |config|
  config.batch_size = 100
  config.admin_root_type = "AdminRoot"

  config.recipients(
    relation: -> { User.all },
    email: :email,
    name: ->(user) { user.email }
  )
end
