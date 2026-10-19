# frozen_string_literal: true

module RecordingStudioBroadcasts
  class BroadcastsScreen < RecordingStudioAdmin::Screen
    key "broadcasts"
    icon :megaphone
    title "Broadcasts"
    subtitle "Product updates sent by email"

    button :new_broadcast, text: "New broadcast", style: :primary,
                           url: ->(context) { context.routes.new_broadcast_path },
                           visible_if: ->(context) { creatable?(context) }

    def self.creatable?(context)
      RecordingStudioAdmin.authorize_resource!(key: "broadcasts", action: :create, context:)
      true
    rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
      false
    end

    query do |context|
      Campaign.recordings(context.access_recording).includes(:recordable).preload(child_recordings: :recordable)
    end

    table do
      title "All broadcasts"
      column :title, sortable: false, value: lambda { |row, context|
        title = row.recordable.title
        view = context.view_context
        next title if view.nil?

        view.link_to(title, context.routes.broadcast_path(row))
      }
      column :subject, sortable: false, value: ->(row, _context) { row.recordable.subject }
      column :status, sortable: false, display: :badge,
                      value: ->(row, _context) { Campaign::STATUS_LABELS.fetch(row.recordable.status) },
                      display_options: ->(row) { { style: BroadcastsHelper::STATUS_STYLES.fetch(row.recordable.status) } }
      column :sends_at, title: "Sends at", sortable: false, value: lambda { |row, _context|
        BroadcastsHelper.schedule_text(row)
      }
      column :created_at, title: "Created"
      admin_action "broadcasts.show", as: :open
      default_sort :created_at, direction: :desc
      paginate per_page: 25
    end
  end
end
