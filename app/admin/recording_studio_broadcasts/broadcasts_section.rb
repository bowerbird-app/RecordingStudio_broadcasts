# frozen_string_literal: true

module RecordingStudioBroadcasts
  class BroadcastsSection < RecordingStudioAdmin::Section
    key "broadcasts"
    icon :megaphone
    title "Broadcasts"
    subtitle "Email product updates to the people you choose"
    availability_scope :root

    link :broadcasts, text: "View broadcasts", url: ->(context) { context.admin_screen_path("broadcasts") }
  end
end
