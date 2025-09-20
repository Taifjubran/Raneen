module Streaming
  module Services
    class AnalyticsTracker
      def self.track_view(program:, user: nil, session_id: nil, metadata: {})
        view_event = ViewEvent.create!(
          program: program,
          user: user,
          session_id: session_id || generate_session_id,
          ip_address: metadata[:ip_address],
          user_agent: metadata[:user_agent],
          referrer: metadata[:referrer],
          viewed_at: Time.current
        )
        
        # Update program view count
        program.increment!(:view_count)
        
        Rails.logger.info "View tracked for program #{program.id}: #{view_event.id}"
        view_event
      end
      
      def self.track_play(program:, user: nil, session_id: nil, position: 0)
        # Track when user starts playing a video
        Rails.logger.info "Play event for program #{program.id} at position #{position}"
        
        # Could store play events in a separate table if needed for detailed analytics
        # For now, just log it
      end
      
      def self.track_pause(program:, user: nil, session_id: nil, position: 0, duration_watched: 0)
        # Track when user pauses a video
        Rails.logger.info "Pause event for program #{program.id} at position #{position}, watched for #{duration_watched}s"
      end
      
      def self.track_completion(program:, user: nil, session_id: nil, total_duration: 0)
        # Track when user completes watching a video
        Rails.logger.info "Completion event for program #{program.id}, total duration #{total_duration}s"
        
        # Could update view_event with completion status
      end
      
      def self.get_program_analytics(program:, time_range: 30.days)
        {
          total_views: program.view_count || 0,
          recent_views: ViewEvent.where(program: program)
                                .where('viewed_at > ?', time_range.ago)
                                .count,
          unique_viewers: ViewEvent.where(program: program)
                                  .where('viewed_at > ?', time_range.ago)
                                  .distinct
                                  .count(:user_id),
          views_by_day: ViewEvent.where(program: program)
                                .where('viewed_at > ?', time_range.ago)
                                .group("DATE(viewed_at)")
                                .count
        }
      end
      
      private
      
      def self.generate_session_id
        SecureRandom.uuid
      end
    end
  end
end