class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Role system
  enum :role, { viewer: "viewer", editor: "editor", admin: "admin" }
  
  before_validation :set_default_role
  
  # Permission methods
  def can_create_programs?
    editor? || admin?
  end
  
  def can_publish_programs?
    admin?
  end
  
  def can_unpublish_programs?
    admin?
  end
  
  def can_delete_programs?
    admin?
  end
  
  def can_manage_users?
    admin?
  end
  
  def can_view_analytics?
    editor? || admin?
  end
  
  def can_access_cms?
    editor? || admin?
  end
  
  # Legacy method for backward compatibility
  def can_manage_programs?
    can_create_programs?
  end
  
  # Role hierarchy
  def role_level
    case role
    when 'viewer' then 1
    when 'editor' then 2
    when 'admin' then 3
    end
  end
  
  def higher_role_than?(other_user)
    role_level > other_user.role_level
  end
  
  def can_manage_user?(other_user)
    admin? && other_user != self
  end
  
  private
  
  def set_default_role
    self.role = 'viewer' if role.blank?
  end
end
