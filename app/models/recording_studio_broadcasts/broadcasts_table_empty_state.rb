# frozen_string_literal: true

module RecordingStudioBroadcasts
  # Admin's screen table renders Flatpack's default "No data available" cell.
  # The broadcasts screen replaces that cell with Flatpack's empty state.
  module BroadcastsTableEmptyState
    def render_empty_state
      return super unless broadcasts_screen_table?

      tag.tr do
        tag.td(colspan: column_count, class: body_cell_classes) do
          render(FlatPack::EmptyState::Component.new(
                   title: "No broadcasts yet",
                   description: "Write a product update, choose who should get it, and send it now or at a set time.",
                   icon: :megaphone
                 ))
        end
      end
    end

    def broadcasts_screen_table?
      helpers.controller.params[:key].to_s == "broadcasts"
    rescue StandardError
      false
    end
  end
end
