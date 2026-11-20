# frozen_string_literal: true

require "test_helper"

class RecordingStudioBroadcastsTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.7.0", ::RecordingStudioBroadcasts::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioBroadcasts::Engine
  end

  def test_gemspec_pins_sibling_gems
    gemspec = File.read(File.expand_path("../recording_studio_broadcasts.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", ">= 7.0", "< 8.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", ">= 0.44.0", "< 1.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_admin", ">= 2.16.0", "< 3.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_notifications", ">= 0.18.0", "< 1.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_notifications_email", ">= 0.5.4", "< 1.0"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_publishable", ">= 1.0.0"'
    refute_includes gemspec, 'recording_studio_publishable", ">= 1.0.0", "<'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_attachable", ">= 0.28.0", "< 1.0"'
    assert_includes gemspec, 'spec.add_dependency "flat_pack", ">= 0.1.376", "< 1.0"'
  end

  def test_gemspec_allows_flat_pack_0_2_0
    spec = Gem::Specification.load(File.expand_path("../recording_studio_broadcasts.gemspec", __dir__))
    requirement = spec.dependencies.find { |dependency| dependency.name == "flat_pack" }.requirement

    assert_equal Gem::Requirement.new(">= 0.1.376", "< 1.0"), requirement
    assert requirement.satisfied_by?(Gem::Version.new("0.1.376"))
    assert requirement.satisfied_by?(Gem::Version.new("0.2.0"))
    refute requirement.satisfied_by?(Gem::Version.new("1.0.0"))
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_broadcasts.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-broadcasts", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_dummy_database_defaults_are_broadcasts_named
    database_yml = File.read(File.expand_path("dummy/config/database.yml", __dir__))

    assert_includes database_yml, '"broadcasts_development"'
    assert_includes database_yml, '"broadcasts_test"'
    assert_includes database_yml, "database: broadcasts_production"
    refute_includes database_yml, "app_development"
    refute_includes database_yml, "app_test"
    refute_includes database_yml, "dummy_production"
  end

  def test_readme_install_pin_matches_shipped_broadcasts_tag
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, github_gem_pin(
      "recording_studio_broadcasts", "~> 0.7", "RecordingStudio_broadcasts", "v0.7.0"
    )
    assert_includes readme, github_gem_pin(
      "recording_studio_publishable", "~> 1.5", "RecordingStudio_publishable", "v1.5.0"
    )
    refute_includes readme, 'RecordingStudio_broadcasts", tag: "v0.6.0"'
    refute_includes readme, 'RecordingStudio_broadcasts", tag: "v0.5.0"'
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_both_gemfiles_pin_verified_github_tags
    shared = [
      github_gem_pin("flat_pack", "~> 0.2", "flatpack", "v0.2.0"),
      github_gem_pin("recording_studio", "~> 7.8", "RecordingStudio", "v7.8.0"),
      github_gem_pin("recording_studio_accessible", "~> 0.58", "RecordingStudio_accessible", "v0.58.0"),
      github_gem_pin("recording_studio_admin", "~> 2.20", "RecordingStudio_admin", "v2.20.0"),
      github_gem_pin("recording_studio_api", "~> 1.21", "RecordingStudio_api", "v1.21.2", require_gem: false),
      github_gem_pin("recording_studio_attachable", "~> 0.34", "RecordingStudio_attachable", "v0.34.0"),
      github_gem_pin("recording_studio_cache", "~> 0.8", "RecordingStudio_cache", "v0.8.0"),
      github_gem_pin("recording_studio_icons", "~> 0.5", "RecordingStudio_icons", "v0.5.0", require_gem: false),
      github_gem_pin("recording_studio_logs", "~> 0.9", "RecordingStudio_logs", "v0.9.0"),
      github_gem_pin("recording_studio_metrics", "~> 0.10", "RecordingStudio_metrics", "v0.10.0"),
      github_gem_pin("recording_studio_notifications", "~> 0.21", "RecordingStudio_notifications", "v0.21.0"),
      github_gem_pin("recording_studio_publishable", "~> 1.5", "RecordingStudio_publishable", "v1.5.0")
    ]
    root = File.read(File.expand_path("../Gemfile", __dir__))
    dummy = File.read(File.expand_path("dummy/Gemfile", __dir__))

    shared.each do |line|
      assert_includes root, line
      assert_includes dummy, line
    end

    assert_includes root, <<~PIN
      gem "recording_studio_moveable", "~> 6.1",
          github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0", require: false
    PIN
    assert_includes root, <<~PIN
      gem "recording_studio_notifications_email", "~> 0.7",
          github: "bowerbird-app/RecordingStudio_notifications_email", tag: "v0.7.0"
    PIN
    assert_includes root, <<~PIN
      gem "recording_studio_root_switchable", "~> 0.17",
          github: "bowerbird-app/RecordingStudio_root_switchable", tag: "v0.17.0"
    PIN
    trashable = github_gem_pin("recording_studio_trashable", "~> 1.3", "RecordingStudio_trashable", "v1.3.0")
    assert_includes root, trashable
    refute_includes root, "#{trashable}, require: false"

    assert_includes dummy, github_gem_pin(
      "recording_studio_moveable", "~> 6.1", "RecordingStudio_moveable", "v6.1.0", require_gem: false
    )
    assert_includes dummy, github_gem_pin(
      "recording_studio_notifications_email", "~> 0.7", "RecordingStudio_notifications_email", "v0.7.0"
    )
    assert_includes dummy, github_gem_pin(
      "recording_studio_root_switchable", "~> 0.17", "RecordingStudio_root_switchable", "v0.17.0"
    )
    assert_includes dummy, github_gem_pin(
      "recording_studio_trashable", "~> 1.3", "RecordingStudio_trashable", "v1.3.0", require_gem: false
    )
  end

  def github_gem_pin(name, requirement, repo, tag, require_gem: true)
    pin = %(gem "#{name}", "#{requirement}", github: "bowerbird-app/#{repo}", tag: "#{tag}")
    require_gem ? pin : "#{pin}, require: false"
  end

  def test_dummy_schema_includes_accessible_depends_on_recording_id
    schema = File.read(File.expand_path("dummy/db/schema.rb", __dir__))
    migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20260911024811_add_depends_on_recording_id_to_recording_studio_accesses.rb",
        __dir__
      )
    )

    assert_includes schema, 't.uuid "depends_on_recording_id"'
    assert_includes schema, "index_recording_studio_accesses_on_depends_on_recording_id"
    assert_includes migration, "add_column :recording_studio_accesses, :depends_on_recording_id, :uuid"
    assert_includes schema, 'create_table "recording_studio_access_invitations"'
    assert_includes schema, "idx_rs_access_invitations_token_digest"
    invitation_migration = File.read(
      File.expand_path(
        "dummy/db/migrate/20261001000011_create_recording_studio_access_invitations.rb",
        __dir__
      )
    )
    assert_includes invitation_migration, "create_table :recording_studio_access_invitations"
    assert_includes schema, 't.string "role", default: "view", null: false'
    refute_includes schema, 't.integer "role", default: 0, null: false'
    role_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_change_recording_studio_accesses_role_to_string.rb", __dir__)
    ).max
    assert role_migration, "expected role-column migration in dummy db/migrate"
    assert_includes File.read(role_migration), "change_column :recording_studio_accesses, :role, :string"

    assert_includes schema, 'create_table "recording_studio_access_constraints"'
    assert_includes schema, 'create_table "recording_studio_access_rules"'
    assert_includes schema, "index_recording_studio_access_constraints_on_action"
    assert_includes schema, "index_recording_studio_access_rules_on_action"
    constraint_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_constraints.rb", __dir__)
    ).max
    rule_migration = Dir.glob(
      File.expand_path("dummy/db/migrate/*_create_recording_studio_access_rules.rb", __dir__)
    ).max
    assert constraint_migration, "expected access constraints migration in dummy db/migrate"
    assert rule_migration, "expected access rules migration in dummy db/migrate"
    assert_includes File.read(constraint_migration), "create_table :recording_studio_access_constraints"
    assert_includes File.read(rule_migration), "create_table :recording_studio_access_rules"
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "recording_studio_layout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "devise_controller? ? \"application\""
    refute_includes controller_source, "UsesDefaultLayout"
    refute_includes controller_source, "flat_pack_sidebar"
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack_sidebar.html.erb", __dir__))
    refute File.exist?(File.expand_path("dummy/app/views/layouts/flat_pack/_sidebar.html.erb", __dir__))
  end

  def test_dummy_login_layout_keeps_flatpack_assets_without_tight_main_offset
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/application"'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/rich_text"'
    assert_includes application_layout, "javascript_importmap_tags"
    assert_includes application_layout, "min-h-screen"
    refute_includes application_layout, "mt-28"
    refute_includes application_layout, "flat_pack_sidebar"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, "../../../vendor/engines/flat_pack/app/components"
    assert_includes tailwind_source, "../../../vendor/engines/recording_studio/app/views"
    refute_includes tailwind_source, "vendor/bundle/**/flatpack/app/components"
    refute_includes tailwind_source, "recordingstudio-*"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, ":root {"
    refute_includes tailwind_source, "--color-fp-primary"

    head_partial = File.read(
      File.expand_path("dummy/app/views/recording_studio/_default_layout_head.html.erb", __dir__)
    )
    assert_includes head_partial, 'stylesheet_link_tag "flat_pack/application"'

    rake_task = File.read(File.expand_path("dummy/lib/tasks/tailwindcss.rake", __dir__))
    assert_includes rake_task, "FlatPack::Engine.root"
    assert_includes rake_task, "RecordingStudio::Engine.root"
    assert_includes rake_task, "tailwindcss:link_engine_sources"
  end

  def test_recording_studio_keeps_strict_recordable_declarations_enabled
    initializer_path = File.expand_path("dummy/config/initializers/recording_studio.rb", __dir__)
    initializer_source = File.read(initializer_path)

    assert_includes initializer_source, "config.require_recordable_declarations = true"
    [
      "AdminRoot", "Workspace", "Folder", "Page",
      "RecordingStudioBroadcasts::Broadcast",
      "RecordingStudioPublishable::Publishable",
      "RecordingStudioAttachable::Attachment"
    ].each do |type|
      assert_includes initializer_source, type
    end
    refute_includes initializer_source, "config.include_children"
    refute_includes initializer_source, "config.features."
    refute_includes initializer_source, "v3"
  end
end
