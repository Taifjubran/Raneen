module ContentManagement
  module Services
    class ProgramPublisher
      # Updated to use Command Pattern
      def self.publish(program:, user:)
        command = Commands::PublishProgramCommand.new(
          user: user,
          program_id: program.id
        )
        
        if command.execute
          command.result
        else
          raise ContentManagement::BusinessError, command.errors.join(', ')
        end
      end
      
      def self.unpublish(program:, user:)
        command = Commands::UnpublishProgramCommand.new(
          user: user,
          program_id: program.id
        )
        
        if command.execute
          command.result
        else
          raise ContentManagement::BusinessError, command.errors.join(', ')
        end
      end
    end
  end
end