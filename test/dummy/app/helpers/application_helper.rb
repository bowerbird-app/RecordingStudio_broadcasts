module ApplicationHelper
  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    content_for(:title, title)
    flat_pack_page_nav(round: true, style: :default) do |nav|
      nav.with_back(href: back_url, tooltip: back_label)
    end

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          href: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end
end
