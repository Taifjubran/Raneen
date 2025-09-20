module Shared
  module Interfaces
    # Abstract interface for transcoding services
    class TranscodingServiceInterface
      def start_transcoding(program_id, source_key)
        raise NotImplementedError, "Must implement start_transcoding"
      end
      
      def get_job_status(job_id)
        raise NotImplementedError, "Must implement get_job_status"
      end
      
      def cancel_job(job_id)
        raise NotImplementedError, "Must implement cancel_job"
      end
    end
    
    # Abstract interface for notification services
    class NotificationServiceInterface
      def send_notification(recipient:, message:, type: :info)
        raise NotImplementedError, "Must implement send_notification"
      end
      
      def broadcast_to_channel(channel:, data:)
        raise NotImplementedError, "Must implement broadcast_to_channel"
      end
    end
    
    # Abstract interface for storage services
    class StorageServiceInterface
      def upload_file(file_path:, destination:, options: {})
        raise NotImplementedError, "Must implement upload_file"
      end
      
      def download_file(source:, destination:)
        raise NotImplementedError, "Must implement download_file"
      end
      
      def delete_file(file_path:)
        raise NotImplementedError, "Must implement delete_file"
      end
      
      def generate_signed_url(file_path:, expires_in: 3600)
        raise NotImplementedError, "Must implement generate_signed_url"
      end
    end
    
    # Abstract interface for analytics services
    class AnalyticsServiceInterface
      def track_event(event_name:, properties: {}, user: nil)
        raise NotImplementedError, "Must implement track_event"
      end
      
      def get_analytics(resource:, time_range:)
        raise NotImplementedError, "Must implement get_analytics"
      end
    end
    
    # Abstract interface for search services
    class SearchServiceInterface
      def index_document(id:, document:, index_name:)
        raise NotImplementedError, "Must implement index_document"
      end
      
      def search(query:, filters: {}, options: {})
        raise NotImplementedError, "Must implement search"
      end
      
      def delete_document(id:, index_name:)
        raise NotImplementedError, "Must implement delete_document"
      end
    end
  end
end