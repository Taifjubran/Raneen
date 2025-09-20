module ContentManagement
  module Services
    # Template Method Pattern for media processing workflow
    class MediaProcessingTemplate
      def process(program, source_key)
        # Template method defining the algorithm structure
        validate_input(program, source_key)
        prepare_processing(program)
        start_transcoding(program, source_key)
        schedule_monitoring(program)
        notify_completion(program)
        
        program
      rescue => error
        handle_error(program, error)
        raise
      end
      
      private
      
      # Template method steps - some can be overridden by subclasses
      
      def validate_input(program, source_key)
        raise ArgumentError, "Program is required" unless program
        raise ArgumentError, "Source key is required" unless source_key.present?
        raise ArgumentError, "Invalid file format" unless valid_format?(source_key)
        raise ContentManagement::BusinessError, "Program not ready for processing" unless can_process?(program)
      end
      
      def prepare_processing(program)
        StatusUpdater.update_to_processing(program)
        create_processing_record(program)
      end
      
      # Abstract method - must be implemented by subclasses
      def start_transcoding(program, source_key)
        raise NotImplementedError, "Subclasses must implement start_transcoding"
      end
      
      def schedule_monitoring(program)
        ContentManagement::Jobs::TranscodingMonitorJob
          .set(wait: monitoring_interval)
          .perform_later(program.id)
      end
      
      def notify_completion(program)
        Rails.logger.info "Media processing started for program #{program.id}"
        
        # Publish domain event
        event = Shared::Events::MediaProcessingStarted.new(
          program_id: program.id,
          processing_strategy: self.class.name.demodulize.underscore
        )
        Shared::EventPublisher.publish(event)
      end
      
      def handle_error(program, error)
        StatusUpdater.update_to_failed(program, error.message)
        
        # Publish failure event
        event = Shared::Events::TranscodingFailed.new(
          program_id: program.id,
          error_message: error.message,
          error_class: error.class.name
        )
        Shared::EventPublisher.publish(event)
        
        Rails.logger.error "Media processing failed for program #{program.id}: #{error.message}"
      end
      
      # Hook methods that can be overridden
      
      def valid_format?(source_key)
        allowed_extensions = %w[.mp4 .mov .avi .mkv .webm .m4v]
        extension = File.extname(source_key).downcase
        allowed_extensions.include?(extension)
      end
      
      def can_process?(program)
        program.can_transition_to?('processing')
      end
      
      def monitoring_interval
        10.seconds
      end
      
      def create_processing_record(program)
        # Hook for subclasses to create additional processing records
        # Default implementation does nothing
      end
    end
    
    # AWS MediaConvert implementation using template
    class AwsMediaProcessing < MediaProcessingTemplate
      private
      
      def start_transcoding(program, source_key)
        strategy = AwsMediaConvertService.new
        result = strategy.start_transcoding(program.id, source_key)
        program.update!(
          mediaconvert_job_id: result[:job_id],
          source_s3_key: source_key
        )
      end
      
      def valid_format?(source_key)
        # AWS MediaConvert supports additional formats
        aws_formats = %w[.mp4 .mov .avi .mkv .webm .m4v .mxf .gxf .ts .mts .m2ts]
        extension = File.extname(source_key).downcase
        aws_formats.include?(extension)
      end
      
      def monitoring_interval
        # AWS jobs might take longer, check less frequently
        30.seconds
      end
      
      def create_processing_record(program)
        # Create AWS-specific processing metadata
        Rails.logger.debug "Creating AWS MediaConvert processing record for program #{program.id}"
      end
    end
  end
end