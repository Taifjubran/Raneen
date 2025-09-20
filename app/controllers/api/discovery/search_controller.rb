module Api
  module Discovery
    class SearchController < ApplicationController
      def index
        result = Discovery::Services::SearchEngine.search(
          query: params[:q],
          filters: filter_params,
          page: params[:page]&.to_i || 1,
          per_page: params[:per_page]&.to_i || 20
        )
        
        render json: {
          programs: result[:programs],
          pagination: {
            current_page: result[:page],
            per_page: result[:per_page],
            total_pages: result[:total_pages],
            total_count: result[:total_count]
          }
        }
      rescue Discovery::ValidationError => error
        render json: { error: error.message }, status: :bad_request
      end
      
      def featured
        programs = Discovery::Services::SearchEngine.featured_programs(
          limit: params[:limit]&.to_i || 10
        )
        
        render json: programs
      end
      
      def recent
        programs = Discovery::Services::SearchEngine.recent_programs(
          limit: params[:limit]&.to_i || 10
        )
        
        render json: programs
      end
      
      def suggestions
        @query = params[:q]
        return render json: { suggestions: [] } if @query.blank?
        
        # Get title matches
        suggestions = Program.published
                            .where("title ILIKE :query", query: "#{@query}%")
                            .limit(5)
                            .pluck(:title)
        
        # Get category matches
        categories = Program.published
                           .where("category ILIKE :query", query: "#{@query}%")
                           .distinct
                           .limit(3)
                           .pluck(:category)
        
        render json: {
          suggestions: suggestions + categories
        }
      end
      
      private
      
      def filter_params
        params.permit(:kind, :language, :category).to_h.compact
      end
    end
  end
end