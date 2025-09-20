module ContentManagement
  module Services
    class MediaProcessor
      def initialize(transcoding_service: nil, notification_service: nil)
        @transcoding_service = transcoding_service || default_transcoding_service
        @notification_service = notification_service || default_notification_service
      end
      
      def self.start_processing(program:, source_s3_key:, **options)
        processor = create_processor(options)
        processor.process(program, source_s3_key)
      end
      
      def self.create_processor(options = {})
        ContentManagement::Services::AwsMediaProcessing.new
      end
      
      def self.determine_strategy
        :aws
      end
      
      def process(program, source_s3_key)
        template = self.class.create_processor
        template.process(program, source_s3_key)
      end
      
      def self.handle_completion(program:)
        StatusUpdater.update_to_ready(program)
        NotificationBroadcaster.broadcast_completion(program)
        
        event = Shared::Events::TranscodingCompleted.new(
          program_id: program.id,
          completed_at: Time.current
        )
        Shared::EventPublisher.publish(event)
        
        Rails.logger.info "Media processing completed for program #{program.id}"
      end
      
      def self.handle_failure(program:, error_message:)
        StatusUpdater.update_to_failed(program, error_message)
        NotificationBroadcaster.broadcast_failure(program, error_message)
        
        event = Shared::Events::TranscodingFailed.new(
          program_id: program.id,
          error_message: error_message,
          failed_at: Time.current
        )
        Shared::EventPublisher.publish(event)
        
        Rails.logger.error "Media processing failed for program #{program.id}: #{error_message}"
      end
      
      private
    end
  end
end