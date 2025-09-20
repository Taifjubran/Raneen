module Api
  module Cms
    class ProgramsController < ApplicationController
      before_action :authenticate_cms!
      before_action :ensure_cms_access!
      before_action :set_program, only: [:show, :update, :destroy, :publish, :ingest_complete]
      
      def index
        @programs = Program.where(created_by: current_user.id)
                          .order(created_at: :desc)
                          .page(params[:page])
        
        render json: @programs
      end
      
      def show
        render json: @program
      end

      def create
        program = ContentManagement::Services::ProgramCreator.create(
          user: current_user,
          **program_params
        )
        
        render json: program, status: :created
      rescue ContentManagement::PermissionError => error
        render json: { error: error.message }, status: :forbidden
      rescue ContentManagement::ValidationError => error
        render json: { error: error.message }, status: :unprocessable_entity
      end

      def update
        if @program.update(program_params)
          render json: @program
        else
          render json: { errors: @program.errors }, status: :unprocessable_entity
        end
      end
      
      def publish
        @program.publish!(user: current_user)
        render json: @program
      rescue ContentManagement::PermissionError => error
        render json: { error: error.message }, status: :forbidden
      rescue ContentManagement::BusinessError => error
        render json: { error: error.message }, status: :unprocessable_entity
      end

      def destroy
        unless current_user.can_delete_programs?
          return render json: { error: 'Permission denied' }, status: :forbidden
        end
        
        @program.destroy
        head :no_content
      end

      def ingest_complete
        @program.start_media_processing!(source_s3_key: params[:s3_key])
        render json: { status: 'processing' }, status: :accepted
      rescue ContentManagement::ExternalServiceError => error
        render json: { error: error.message }, status: :service_unavailable
      end

      private

      def set_program
        @program = Program.find(params[:id])
      end

      def program_params
        params.require(:program).permit(:title, :description, :kind, :language, :category, tags: [])
      end
      
      def ensure_cms_access!
        unless current_user.can_access_cms?
          render json: { error: 'Access denied' }, status: :forbidden
        end
      end
      
      def broadcast_status_update(program)
        channel_name = "program_status_#{program.id}"
        data = {
          id: program.id,
          status: program.status,
          transcoding_progress: program.transcoding_progress,
          stream_path: program.stream_path,
          thumbnail_url: program.thumbnail_url,
          updated_at: program.updated_at.iso8601
        }
        
        Rails.logger.info "📡 Controller broadcasting to #{channel_name}: #{data.inspect}"
        
        ActionCable.server.broadcast(channel_name, data)
        
        Rails.logger.info "✅ Controller broadcast sent successfully"
      end
    end
  end
end