module Api
  module Discovery
    class AnalyticsController < ApplicationController
      skip_before_action :verify_authenticity_token
      
      def track_view
        @program = Program.find(params[:program_id])
        
        @view_event = ViewEvent.create!(
          program: @program,
          user: current_user,
          session_id: session.id,
          event_type: params[:event_type] || 'play',
          duration_seconds: params[:duration_seconds],
          ip_address: request.remote_ip,
          user_agent: request.user_agent
        )
        
        # Update program view count
        @program.increment!(:view_count) if params[:event_type] == 'play'
        
        render json: { success: true, event_id: @view_event.id }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Program not found' }, status: :not_found
      end
      
      def track_progress
        @program = Program.find(params[:program_id])
        
        # Find or create watch session
        @view_event = ViewEvent.find_or_create_by(
          program: @program,
          session_id: session.id,
          event_type: 'watch_progress'
        ) do |event|
          event.user = current_user
          event.ip_address = request.remote_ip
          event.user_agent = request.user_agent
        end
        
        # Update watch duration
        @view_event.update!(
          duration_seconds: params[:current_time].to_i
        )
        
        render json: { 
          success: true, 
          progress_saved: true,
          duration: @view_event.duration_seconds
        }
      end
      
      def popular
        # Get most viewed programs
        popular_programs = Program.published
                                 .where.not(view_count: nil)
                                 .order(view_count: :desc)
                                 .limit(10)
        
        render json: {
          popular: popular_programs.map do |program|
            {
              id: program.id,
              title: program.title,
              thumbnail_url: program.thumbnail_url,
              view_count: program.view_count,
              category: program.category
            }
          end
        }
      end
    end
  end
end