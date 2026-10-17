# frozen_string_literal: true

RecordingStudioBroadcasts.configure do |config|
  config.batch_size = 100
  config.admin_root_type = "<%= options[:admin_root_type] %>"

  config.recipients(
    relation: -> { User.all },
    email: :email,
    name: :email
  )
end

# When the address is not `#email`, give the email channel the same lookup:
# RecordingStudioNotificationsEmail.config.recipients.register("User", ->(user) { user.contact_email })

# RecordingStudioBroadcasts.register_filter(:registered_after, label: "Joined after", input: :date) do |scope, value|
#   scope.where(users: { created_at: Time.zone.parse(value.to_s).. })
# end
