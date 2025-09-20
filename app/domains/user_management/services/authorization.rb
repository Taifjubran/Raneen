module UserManagement
  module Services
    class Authorization
      def self.can_access_resource?(user:, resource:, action:)
        case resource
        when :cms
          user.can_access_cms?
        when :programs
          case action
          when :create then user.can_create_programs?
          when :publish then user.can_publish_programs?
          when :delete then user.can_delete_programs?
          when :manage then user.can_manage_programs?
          else false
          end
        when :users
          case action
          when :manage then user.can_manage_users?
          else false
          end
        when :analytics
          user.can_view_analytics?
        else
          false
        end
      end
      
      def self.ensure_can_access!(user:, resource:, action:)
        unless can_access_resource?(user: user, resource: resource, action: action)
          raise UserManagement::PermissionError, "User cannot #{action} #{resource}"
        end
      end
      
      def self.filter_accessible_programs(user:, programs:)
        # For now, users can see all published programs
        # In the future, this could filter by user permissions, geographic restrictions, etc.
        programs.published
      end
    end
  end
end