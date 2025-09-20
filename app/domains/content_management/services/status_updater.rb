module ContentManagement
  module Services
    class StatusUpdater
      # Single responsibility: Handle program status updates
      
      def self.update_to_processing(program, progress = 0)
        program.update!(
          status: 'processing',
          transcoding_progress: progress
        )
        Rails.logger.info "Program #{program.id} status updated to processing"
      end
      
      def self.update_to_ready(program)
        program.update!(
          status: 'ready',
          transcoding_progress: 100
        )
        Rails.logger.info "Program #{program.id} status updated to ready"
      end
      
      def self.update_to_failed(program, error_message)
        program.update!(
          status: 'failed',
          transcoding_progress: 0
        )
        Rails.logger.error "Program #{program.id} failed: #{error_message}"
      end
      
      def self.update_progress(program, progress_percentage)
        return unless program.processing?
        return unless (0..100).include?(progress_percentage)
        
        program.update!(transcoding_progress: progress_percentage)
      end
      
      def self.can_transition_to?(program, new_status)
        program.can_transition_to?(new_status)
      end
      
      def self.transition_to!(program, new_status)
        unless can_transition_to?(program, new_status)
          raise ContentManagement::BusinessError, 
                "Cannot transition from #{program.status} to #{new_status}"
        end
        
        case new_status
        when 'processing'
          update_to_processing(program)
        when 'ready'
          update_to_ready(program)
        when 'failed'
          update_to_failed(program, 'Manual status change')
        else
          raise ContentManagement::ValidationError, "Unknown status: #{new_status}"
        end
      end
    end
  end
end