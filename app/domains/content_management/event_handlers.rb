module ContentManagement
  module EventHandlers
    # Synchronous event handlers for Content Management domain
    
    class ProgramEventHandler
      def self.handle(event)
        case event
        when Shared::Events::ProgramCreated
          handle_program_created(event)
        when Shared::Events::ProgramPublished
          handle_program_published(event)
        when Shared::Events::ProgramUnpublished
          handle_program_unpublished(event)
        when Shared::Events::ProgramDeleted
          handle_program_deleted(event)
        end
      end
      
      private
      
      def self.handle_program_created(event)
        program_id = event.data[:program_id]
        Rails.logger.info "Handling program created event for program #{program_id}"
        
        # Could trigger welcome email, setup default permissions, etc.
        # For now, just log
      end
      
      def self.handle_program_published(event)
        program_id = event.data[:program_id]
        Rails.logger.info "Handling program published event for program #{program_id}"
        
        # Update search index
        SearchIndexUpdateJob.perform_later(program_id, 'index')
        
        # Notify subscribers (async job)
        NotifySubscribersJob.perform_later(program_id, 'program_published')
        
        # Update recommendation engine
        UpdateRecommendationsJob.perform_later(program_id)
      end
      
      def self.handle_program_unpublished(event)
        program_id = event.data[:program_id]
        Rails.logger.info "Handling program unpublished event for program #{program_id}"
        
        # Remove from search index
        SearchIndexUpdateJob.perform_later(program_id, 'remove')
        
        # Update recommendation engine
        UpdateRecommendationsJob.perform_later(program_id)
      end
      
      def self.handle_program_deleted(event)
        program_id = event.data[:program_id]
        Rails.logger.info "Handling program deleted event for program #{program_id}"
        
        # Clean up associated files
        CleanupProgramFilesJob.perform_later(program_id, event.data[:program_data])
        
        # Remove from all indexes
        SearchIndexUpdateJob.perform_later(program_id, 'remove')
        
        # Update analytics
        AnalyticsUpdateJob.perform_later('program_deleted', program_id)
      end
    end
    
    class TranscodingEventHandler
      def self.handle(event)
        case event
        when Shared::Events::MediaProcessingStarted
          handle_processing_started(event)
        when Shared::Events::TranscodingCompleted
          handle_transcoding_completed(event)
        when Shared::Events::TranscodingFailed
          handle_transcoding_failed(event)
        when Shared::Events::TranscodingProgressUpdated
          handle_progress_updated(event)
        end
      end
      
      private
      
      def self.handle_processing_started(event)
        program_id = event.data[:program_id]
        job_id = event.data[:job_id]
        
        Rails.logger.info "Media processing started for program #{program_id}, job #{job_id}"
        
        # Start monitoring job status
        ContentManagement::Jobs::TranscodingMonitorJob.set(wait: 30.seconds).perform_later(program_id)
        
        # Notify user that processing has started
        NotifyUserJob.perform_later(
          event.data[:created_by] || event.data[:user_id],
          'processing_started',
          { program_id: program_id }
        )
      end
      
      def self.handle_transcoding_completed(event)
        program_id = event.data[:program_id]
        
        Rails.logger.info "Transcoding completed for program #{program_id}"
        
        # Update search index with new media URLs
        SearchIndexUpdateJob.perform_later(program_id, 'update_media')
        
        # Generate video preview/thumbnails
        GeneratePreviewsJob.perform_later(program_id)
        
        # Notify user of completion
        NotifyUserJob.perform_later(
          event.data[:user_id],
          'processing_completed',
          { program_id: program_id }
        )
        
        # Update analytics
        AnalyticsUpdateJob.perform_later('transcoding_completed', program_id)
      end
      
      def self.handle_transcoding_failed(event)
        program_id = event.data[:program_id]
        error_message = event.data[:error_message]
        
        Rails.logger.error "Transcoding failed for program #{program_id}: #{error_message}"
        
        # Notify user of failure
        NotifyUserJob.perform_later(
          event.data[:user_id],
          'processing_failed',
          { program_id: program_id, error: error_message }
        )
        
        # Log for monitoring/alerting
        AlertingService.notify(
          level: :error,
          message: "Transcoding failed for program #{program_id}",
          context: event.data
        )
        
        # Update analytics
        AnalyticsUpdateJob.perform_later('transcoding_failed', program_id)
      end
      
      def self.handle_progress_updated(event)
        program_id = event.data[:program_id]
        progress = event.data[:progress]
        
        # Broadcast real-time update to frontend
        NotificationBroadcaster.broadcast_progress_update(
          Program.find(program_id),
          progress
        )
      end
    end
    
    # Cache invalidation handler
    class CacheInvalidationHandler
      def self.handle(event)
        case event
        when Shared::Events::ProgramPublished, Shared::Events::ProgramUnpublished
          invalidate_program_caches(event.data[:program_id])
        when Shared::Events::TranscodingCompleted
          invalidate_media_caches(event.data[:program_id])
        end
      end
      
      private
      
      def self.invalidate_program_caches(program_id)
        Rails.cache.delete_matched("programs/#{program_id}/*")
        Rails.cache.delete_matched("discovery/featured*")
        Rails.cache.delete_matched("discovery/recent*")
        Rails.logger.info "Invalidated caches for program #{program_id}"
      end
      
      def self.invalidate_media_caches(program_id)
        Rails.cache.delete_matched("media/#{program_id}/*")
        Rails.cache.delete_matched("streaming/#{program_id}/*")
        Rails.logger.info "Invalidated media caches for program #{program_id}"
      end
    end
  end
end