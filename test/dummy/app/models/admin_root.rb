class AdminRoot < ApplicationRecord
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  RecordingStudio.enable_capability(:accessible, on: self) if defined?(RecordingStudioAccessible)

  recording_studio_admin_sections do
    section :root
    section :admin_activity_logs
    section :broadcasts
  end
end
