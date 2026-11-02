# frozen_string_literal: true

module RecordingStudioBroadcasts
  class BroadcastsController < RecordingStudioAdmin::ApplicationController
    # The routes live on the admin engine, so its helpers must win over this isolated engine's empty set.
    include RecordingStudioAdmin::Engine.routes.url_helpers

    include SentBroadcastEdit

    helper BroadcastsHelper
    helper_method :offered?

    before_action :set_recording, except: %i[new create]
    rescue_from InvalidTransition, with: :refuse

    def new
      authorize_broadcasts!(:create)
      @broadcast = Broadcast.new
    end

    def create
      recording = perform(:create, nil) { Campaign.create(access_recording, actor: current_actor, **broadcast_params) }
      redirect_to broadcast_path(recording), notice: "Saved."
    rescue ActiveRecord::RecordInvalid => e
      @broadcast = e.record
      render :new, status: :unprocessable_content
    end

    def show
      @broadcast = @recording.recordable
      @preview = RecordingStudioBroadcasts.preview(@recording)
      @delivery = Recipient.where(recording_id: @recording.id).group(:status).count
    end

    def edit
      return redirect_sent_broadcast if sent_broadcast?

      authorize_broadcasts!(:update)
      @broadcast = @recording.recordable
    end

    def update
      perform(:update) { Campaign.update(@recording, actor: current_actor, **broadcast_params) }
      redirect_to broadcast_path(@recording), notice: "Saved."
    rescue ActiveRecord::RecordInvalid => e
      @broadcast = e.record
      render :edit, status: :unprocessable_content
    end

    def destroy
      perform(:delete) { Campaign.destroy(@recording, actor: current_actor) }
      redirect_to recording_studio_admin_context.admin_screen_path("broadcasts"), notice: "Deleted."
    end

    def send_message
      perform(:send) { RecordingStudioBroadcasts.publish_now(@recording, actor: current_actor) }
      redirect_to broadcast_path(@recording), notice: "Sending now."
    end

    def schedule
      at = Time.zone.parse(params[:scheduled_at].to_s)
      perform(:schedule) { RecordingStudioBroadcasts.schedule(@recording, at:, actor: current_actor) }
      redirect_to broadcast_path(@recording), notice: "Scheduled."
    rescue ActiveRecord::RecordInvalid
      redirect_to broadcast_path(@recording), alert: "Pick a time to send it."
    end

    def unpublish
      perform(:unpublish) { RecordingStudioBroadcasts.unpublish(@recording, actor: current_actor) }
      redirect_to broadcast_path(@recording), notice: "Unpublished. It will not be sent."
    end

    def cancel
      perform(:cancel) { RecordingStudioBroadcasts.cancel(@recording, actor: current_actor) }
      redirect_to broadcast_path(@recording), notice: "Cancelled."
    end

    def test_send
      notification = perform(:test_send) { RecordingStudioBroadcasts.test_send(@recording, actor: current_actor) }
      if notification.nil?
        redirect_to broadcast_path(@recording), alert: "No test went out because product updates are off for you."
      elsif notification.previously_new_record?
        redirect_to broadcast_path(@recording), notice: "Test sent to you."
      else
        redirect_to broadcast_path(@recording), notice: "You already got a test of this broadcast."
      end
    end

    private

    def set_recording
      authorize_broadcasts!(:show)
      @recording = Campaign.recordings(access_recording).find(params[:id])
    end

    def access_recording
      recording_studio_admin_context.access_recording
    end

    def perform(action_key, record = @recording, &)
      perform_recording_studio_admin_action!("broadcasts", action_key, record, &)
    end

    def authorize_broadcasts!(action_key)
      RecordingStudioAdmin.authorize_resource!(
        key: "broadcasts", action: action_key, context: recording_studio_admin_context, record: @recording
      )
    end

    def offered?(action_key)
      return false unless Campaign.actions_for(@broadcast.status).include?(action_key)

      authorize_broadcasts!(action_key)
      true
    rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
      false
    end

    def broadcast_params
      filter_keys = RecordingStudioBroadcasts.filters.all.map(&:key)
      attributes = params.require(:broadcast).permit(:title, :subject, :body, filter_params: filter_keys)
      attributes[:filter_params] = attributes[:filter_params].to_h.compact_blank if attributes.key?(:filter_params)
      attributes.to_h.symbolize_keys
    end

    def refuse(error)
      redirect_to broadcast_path(@recording), alert: error.message
    end
  end
end
