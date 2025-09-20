module ContentManagement
  module Services
    class NotificationBroadcaster
      # Single responsibility: Handle real-time notifications and broadcasts
      
      def self.broadcast_status_update(program)
        channel_name = "program_status_#{program.id}"
        data = build_status_data(program)
        
        Rails.logger.info "📡 Broadcasting to #{channel_name}: #{data.inspect}"
        ActionCable.server.broadcast(channel_name, data)
        Rails.logger.info "✅ Broadcast sent successfully"
      end
      
      def self.broadcast_completion(program)
        data = build_status_data(program).merge(
          message: "Processing completed successfully",
          completed_at: Time.current.iso8601
        )
        
        broadcast_to_channel(program, data)
      end
      
      def self.broadcast_failure(program, error_message)
        data = build_status_data(program).merge(
          error: error_message,
          failed_at: Time.current.iso8601
        )
        
        broadcast_to_channel(program, data)
      end
      
      def self.broadcast_progress_update(program, progress)
        data = build_status_data(program).merge(
          transcoding_progress: progress,
          progress_updated_at: Time.current.iso8601
        )
        
        broadcast_to_channel(program, data)
      end
      
      def self.broadcast_media_ready(program)
        data = build_status_data(program).merge(
          stream_url: program.full_stream_url,
          thumbnail_url: program.full_thumbnail_url,
          duration: program.duration_formatted,
          media_ready_at: Time.current.iso8601
        )
        
        broadcast_to_channel(program, data)
      end
      
      private
      
      def self.build_status_data(program)
        {
          id: program.id,
          status: program.status,
          transcoding_progress: program.transcoding_progress || 0,
          updated_at: program.updated_at.iso8601
        }
      end
      
      def self.broadcast_to_channel(program, data)
        channel_name = "program_status_#{program.id}"
        
        Rails.logger.info "📡 Broadcasting to #{channel_name}: #{data.inspect}"
        ActionCable.server.broadcast(channel_name, data)
        Rails.logger.info "✅ Broadcast sent successfully"
      end
    end
  end
end