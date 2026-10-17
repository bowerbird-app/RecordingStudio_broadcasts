# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.where(RecordingStudio::Recording.recording_studio_trashable_kept_sql).find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

previous_actor = Current.actor
Current.actor = user

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)
ensure
  Current.actor = previous_actor
end

find_or_create_user = lambda do |email, created_at: nil|
  User.find_or_create_by!(email: email) do |record|
    record.password = "Password"
    record.password_confirmation = "Password"
    record.created_at = created_at if created_at
  end
end

viewer = find_or_create_user.call("viewer@example.com")
{ "early@example.com" => 90.days.ago, "spring@example.com" => 30.days.ago, "recent@example.com" => 2.days.ago }
  .each { |email, created_at| find_or_create_user.call(email, created_at: created_at) }

admin_root = AdminRoot.find_or_create_by!(name: "Admin")
Current.actor = user

begin
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)

  unless RecordingStudioAccessible.role_for(actor: user, recording: admin_root_recording) == :admin
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: admin_root_recording, actor: user)
    raise "Failed to grant admin access: #{result.error}" if result.failure?
  end

  unless RecordingStudioAccessible.role_for(actor: viewer, recording: admin_root_recording)
    result = RecordingStudioAccessible.grant_access(
      recording: admin_root_recording, actor: viewer, role: "view", manager_actor: user
    )
    raise "Failed to grant view access: #{result.error}" if result.failure?
  end
ensure
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password (admin)"
puts "Seeded: viewer@example.com / Password (view only)"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"
