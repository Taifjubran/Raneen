module ContentManagement
  module Services
    module TranscodingStrategies
      class Base
        def start_transcoding(program_id, source_key)
          raise NotImplementedError, "Subclasses must implement start_transcoding"
        end
        
        def get_job_status(job_id)
          raise NotImplementedError, "Subclasses must implement get_job_status"
        end
        
        def cancel_job(job_id)
          raise NotImplementedError, "Subclasses must implement cancel_job"
        end
        
        protected
        
        def validate_input(program_id, source_key)
          raise ArgumentError, "Program ID is required" unless program_id
          raise ArgumentError, "Source key is required" unless source_key.present?
        end
        
        def log_transcoding_start(program_id, job_id)
          Rails.logger.info "Started transcoding for program #{program_id}, job: #{job_id}"
        end
        
        def log_transcoding_error(program_id, error)
          Rails.logger.error "Transcoding failed for program #{program_id}: #{error.message}"
        end
      end
    end
  end
end