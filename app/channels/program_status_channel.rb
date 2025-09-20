class ProgramStatusChannel < ApplicationCable::Channel
  def subscribed
    program_id = params[:program_id]
    if program_id.present?

      normalized_id = program_id.to_i.to_s
      channel_name = "program_status_#{normalized_id}"
      Rails.logger.info "🔌 Subscribing to channel: #{channel_name} (original param: #{program_id})"
      stream_from channel_name
    end
  end
end
