module ContentManagement
  module Commands
    # Base command class following Command Pattern
    class BaseCommand
      attr_reader :user, :params, :errors, :result
      
      def initialize(user:, **params)
        @user = user
        @params = params
        @errors = []
        @result = nil
      end
      
      def execute
        validate!
        return false if errors.any?
        
        @result = perform
        true
      rescue => error
        @errors << error.message
        Rails.logger.error "Command #{self.class.name} failed: #{error.message}"
        false
      end
      
      def success?
        errors.empty? && result.present?
      end
      
      def failure?
        !success?
      end
      
      private
      
      def validate!
        raise NotImplementedError, "Subclasses must implement validate!"
      end
      
      def perform
        raise NotImplementedError, "Subclasses must implement perform"
      end
    end
    
    # Command for creating programs
    class CreateProgramCommand < BaseCommand
      def validate!
        @errors << "Title is required" if params[:title].blank?
        @errors << "Title too long" if params[:title] && params[:title].length > 255
        @errors << "Description too long" if params[:description] && params[:description].length > 5000
        @errors << "User cannot create programs" unless user.can_create_programs?
        
        if params[:kind] && !Program.kinds.key?(params[:kind])
          @errors << "Invalid program kind: #{params[:kind]}"
        end
      end
      
      def perform
        program = Program.create!(
          title: params[:title],
          description: params[:description],
          status: 'draft',
          kind: params[:kind] || 'podcast',
          language: params[:language] || 'en',
          category: params[:category],
          tags: params[:tags] || [],
          created_by: user.id
        )
        
        # Publish domain event
        event = Shared::Events::ProgramCreated.new(
          program_id: program.id,
          created_by: user.id,
          program_data: program.attributes.slice('title', 'kind', 'language')
        )
        Shared::EventPublisher.publish(event)
        
        Rails.logger.info "Program created: #{program.id} by user #{user.id}"
        program
      end
    end
    
    # Command for publishing programs
    class PublishProgramCommand < BaseCommand
      def validate!
        @errors << "Program not found" unless program
        @errors << "User cannot publish programs" unless user.can_publish_programs?
        @errors << "Program not ready for publishing" unless program&.ready_for_publishing?
      end
      
      def perform
        program.update!(published_at: Time.current)
        
        # Publish domain event
        event = Shared::Events::ProgramPublished.new(
          program_id: program.id,
          published_by: user.id,
          published_at: Time.current
        )
        Shared::EventPublisher.publish(event)
        
        Rails.logger.info "Program published: #{program.id} by user #{user.id}"
        program
      end
      
      private
      
      def program
        @program ||= Program.find_by(id: params[:program_id])
      end
    end
    
    # Command for unpublishing programs
    class UnpublishProgramCommand < BaseCommand
      def validate!
        @errors << "Program not found" unless program
        @errors << "User cannot unpublish programs" unless user.can_unpublish_programs?
        @errors << "Program is not published" unless program&.published_at.present?
      end
      
      def perform
        old_published_at = program.published_at
        program.update!(published_at: nil)
        
        # Publish domain event
        event = Shared::Events::ProgramUnpublished.new(
          program_id: program.id,
          unpublished_by: user.id,
          was_published_at: old_published_at
        )
        Shared::EventPublisher.publish(event)
        
        Rails.logger.info "Program unpublished: #{program.id} by user #{user.id}"
        program
      end
      
      private
      
      def program
        @program ||= Program.find_by(id: params[:program_id])
      end
    end
    
    # Command for deleting programs
    class DeleteProgramCommand < BaseCommand
      def validate!
        @errors << "Program not found" unless program
        @errors << "User cannot delete programs" unless user.can_delete_programs?
        @errors << "Cannot delete published program" if program&.published_at.present?
      end
      
      def perform
        program_data = program.attributes.dup
        program_id = program.id
        
        program.destroy!
        
        # Publish domain event
        event = Shared::Events::ProgramDeleted.new(
          program_id: program_id,
          deleted_by: user.id,
          program_data: program_data
        )
        Shared::EventPublisher.publish(event)
        
        Rails.logger.info "Program deleted: #{program_id} by user #{user.id}"
        true
      end
      
      private
      
      def program
        @program ||= Program.find_by(id: params[:program_id])
      end
    end
    
    # Command for starting media processing
    class StartMediaProcessingCommand < BaseCommand
      def validate!
        @errors << "Program not found" unless program
        @errors << "Source S3 key is required" if params[:source_s3_key].blank?
        @errors << "Program not in correct status" unless program&.can_transition_to?('processing')
        
        if params[:source_s3_key] && !valid_media_format?(params[:source_s3_key])
          @errors << "Invalid media format"
        end
      end
      
      def perform
        processor = MediaProcessor.new(
          transcoding_service: params[:transcoding_service],
          notification_service: params[:notification_service]
        )
        
        result = processor.process(program, params[:source_s3_key])
        
        # Publish domain event
        event = Shared::Events::MediaProcessingStarted.new(
          program_id: program.id,
          source_s3_key: params[:source_s3_key],
          job_id: result.mediaconvert_job_id
        )
        Shared::EventPublisher.publish(event)
        
        result
      end
      
      private
      
      def program
        @program ||= Program.find_by(id: params[:program_id])
      end
      
      def valid_media_format?(filename)
        allowed_formats = %w[.mp4 .mov .avi .mkv .webm]
        extension = File.extname(filename).downcase
        allowed_formats.include?(extension)
      end
    end
    
    # Command for updating user roles
    class UpdateUserRoleCommand < BaseCommand
      def validate!
        @errors << "Target user not found" unless target_user
        @errors << "New role is required" if params[:new_role].blank?
        @errors << "Invalid role" unless User.roles.key?(params[:new_role])
        @errors << "Cannot change own role" if target_user == user
        
        unless UserManagement::Services::RoleManager.can_assign_role?(
          assigner: user,
          target_user: target_user,
          new_role: params[:new_role]
        )
          @errors << "Permission denied for role assignment"
        end
      end
      
      def perform
        old_role = target_user.role
        UserManagement::Services::RoleManager.assign_role(
          user: target_user,
          role: params[:new_role],
          assigned_by: user
        )
        
        # Publish domain event
        event = Shared::Events::UserRoleChanged.new(
          user_id: target_user.id,
          old_role: old_role,
          new_role: params[:new_role],
          changed_by: user.id
        )
        Shared::EventPublisher.publish(event)
        
        target_user
      end
      
      private
      
      def target_user
        @target_user ||= User.find_by(id: params[:user_id])
      end
    end
  end
end