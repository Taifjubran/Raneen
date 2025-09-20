module Api
  module Discovery
    class ProgramsController < ApplicationController
      # No authentication needed for discovery endpoints
      
      def index
        # Build the query with filters
        programs = Program.published
        
        # Apply search if query provided
        programs = programs.search(params[:q]) if params[:q].present?
        
        # Apply filters
        programs = programs.by_kind(params[:kind]) if params[:kind].present?
        programs = programs.by_language(params[:language]) if params[:language].present?
        programs = programs.by_category(params[:category]) if params[:category].present?
        programs = programs.published_before(params[:before]) if params[:before].present?
        programs = programs.published_after(params[:after]) if params[:after].present?
        
        # Order by relevance (if searching) or published date
        unless params[:q].present?
          programs = programs.order(published_at: :desc)
        end
        
        # Pagination
        per_page = params[:per_page]&.to_i || 20
        per_page = 100 if per_page > 100 # Max 100 items per page
        
        @pagy, @programs = pagy(programs, items: per_page)
        
        render json: {
          page: @pagy.page,
          per_page: @pagy.items,
          total: @pagy.count,
          total_pages: @pagy.pages,
          items: serialize_programs(@programs)
        }
      end

      def show
        @program = Program.published.find(params[:id])
        
        render json: serialize_program_detail(@program)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Program not found" }, status: :not_found
      end

      private

      def serialize_programs(programs)
        programs.map do |program|
          {
            id: program.id,
            title: program.title,
            description: program.description,
            kind: program.kind,
            language: program.language,
            category: program.category,
            duration_seconds: program.duration_seconds,
            duration_formatted: program.duration_formatted,
            published_at: program.published_at,
            tags: program.tags,
            thumbnail_url: program.full_thumbnail_url,
            poster_url: program.full_poster_url || program.full_thumbnail_url,
            preview_video_url: program.full_preview_video_url,
            sprite_sheet_url: program.full_sprite_sheet_url,
            stream_url: program.stream_url,
            created_at: program.created_at,
            updated_at: program.updated_at
          }
        end
      end

      def serialize_program_detail(program)
        {
          id: program.id,
          title: program.title,
          description: program.description,
          kind: program.kind,
          language: program.language,
          category: program.category,
          duration_seconds: program.duration_seconds,
          duration_formatted: program.duration_formatted,
          published_at: program.published_at,
          tags: program.tags,
          thumbnail_url: program.full_thumbnail_url,
          poster_url: program.full_poster_url || program.full_thumbnail_url,
          stream_url: program.stream_url,
          external_url: program.external_url,
          created_at: program.created_at,
          updated_at: program.updated_at
        }
      end
    end
  end
end