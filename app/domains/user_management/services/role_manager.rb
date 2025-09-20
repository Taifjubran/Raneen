module UserManagement
  module Services
    class RoleManager
      def self.assign_role(user:, role:, assigned_by:)
        validate_role_assignment!(user, role, assigned_by)
        
        old_role = user.role
        user.update!(role: role)
        
        Rails.logger.info "User #{user.id} role changed from #{old_role} to #{role} by #{assigned_by.id}"
        
        user
      end
      
      def self.available_roles_for_assignment(assigner:)
        case assigner.role
        when 'admin'
          User.roles.keys # Admins can assign any role
        when 'editor'
          ['viewer'] # Editors can only assign viewer role
        else
          [] # Viewers cannot assign roles
        end
      end
      
      def self.can_assign_role?(assigner:, target_user:, new_role:)
        return false unless assigner.can_manage_users?
        return false if target_user == assigner # Cannot change own role
        return false unless available_roles_for_assignment(assigner).include?(new_role)
        
        # Additional business rules
        case new_role
        when 'admin'
          # Only existing admins can create new admins
          assigner.admin?
        when 'editor'
          # Admins can create editors
          assigner.admin?
        when 'viewer'
          # Admins and editors can create viewers
          assigner.admin? || assigner.editor?
        else
          false
        end
      end
      
      private
      
      def self.validate_role_assignment!(user, role, assigned_by)
        unless User.roles.key?(role)
          raise UserManagement::ValidationError, "Invalid role: #{role}"
        end
        
        unless can_assign_role?(assigner: assigned_by, target_user: user, new_role: role)
          raise UserManagement::PermissionError, "Cannot assign role #{role} to user #{user.id}"
        end
        
        if user == assigned_by
          raise UserManagement::BusinessError, "Cannot change own role"
        end
      end
    end
  end
end