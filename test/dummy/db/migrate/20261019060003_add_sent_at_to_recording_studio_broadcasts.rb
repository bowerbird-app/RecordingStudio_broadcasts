# frozen_string_literal: true

# Nullable column, no default, no index, and no rewrite of existing rows.
# Recording primary keys stay UUIDs; this migration does not touch them.
class AddSentAtToRecordingStudioBroadcasts < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_broadcasts, :sent_at, :datetime
  end
end
