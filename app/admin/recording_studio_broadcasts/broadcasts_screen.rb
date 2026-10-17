# frozen_string_literal: true

module RecordingStudioBroadcasts
  class BroadcastsScreen < RecordingStudioAdmin::Screen
    key "broadcasts"
    icon :megaphone
    title "Broadcasts"
    # Admin tables have no empty-state slot, so the subtitle carries it.
    subtitle do |context|
      parent = context.access_recording
      parent && Campaign.recordings(parent).exists? ? "Product updates sent by email" : "No broadcasts yet."
    end

    button :new_broadcast, text: "New broadcast", style: :primary,
                           url: ->(context) { context.routes.new_broadcast_path },
                           visible_if: ->(context) { creatable?(context) }

    def self.creatable?(context)
      RecordingStudioAdmin.authorize_resource!(key: "broadcasts", action: :create, context:)
      true
    rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
      false
    end

    query { |context| Campaign.recordings(context.access_recording).includes(:recordable) }

    table do
      title "All broadcasts"
      column :title, sortable: false, value: ->(row, _context) { row.recordable.title }
      column :subject, sortable: false, value: ->(row, _context) { row.recordable.subject }
      column :status, sortable: false, display: :badge,
                      value: ->(row, _context) { Campaign::STATUS_LABELS.fetch(row.recordable.status) },
                      display_options: ->(row) { { style: BroadcastsHelper::STATUS_STYLES.fetch(row.recordable.status) } }
      column :created_at, title: "Created"
      admin_action "broadcasts.show", as: :open
      default_sort :created_at, direction: :desc
      paginate per_page: 25
    end
  end
end
