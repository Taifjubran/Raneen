module ContentManagement
  module Services
    class ProgramCreator
      # Updated to use Command Pattern
      def self.create(user:, **params)
        command = Commands::CreateProgramCommand.new(user: user, **params)
        
        if command.execute
          command.result
        else
          raise ContentManagement::ValidationError, command.errors.join(', ')
        end
      end
      
      # Legacy method for backward compatibility
      def self.create_legacy(user:, title:, description:, **options)
        create(
          user: user,
          title: title,
          description: description,
          **options
        )
      end
    end
  end
end