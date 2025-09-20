module Shared
  module Exceptions
    # Base domain exception
    class DomainError < StandardError; end
    
    # Permission-related errors
    class PermissionError < DomainError; end
    
    # Validation errors
    class ValidationError < DomainError; end
    
    # Business logic errors
    class BusinessError < DomainError; end
    
    # External service errors
    class ExternalServiceError < DomainError; end
  end
end

# Make the exceptions available in the ContentManagement namespace
module ContentManagement
  PermissionError = Shared::Exceptions::PermissionError
  ValidationError = Shared::Exceptions::ValidationError
  BusinessError = Shared::Exceptions::BusinessError
  ExternalServiceError = Shared::Exceptions::ExternalServiceError
end

# Make the exceptions available in other domain namespaces
module Discovery
  PermissionError = Shared::Exceptions::PermissionError
  ValidationError = Shared::Exceptions::ValidationError
  BusinessError = Shared::Exceptions::BusinessError
  ExternalServiceError = Shared::Exceptions::ExternalServiceError
end

module Streaming
  PermissionError = Shared::Exceptions::PermissionError
  ValidationError = Shared::Exceptions::ValidationError
  BusinessError = Shared::Exceptions::BusinessError
  ExternalServiceError = Shared::Exceptions::ExternalServiceError
end

module UserManagement
  PermissionError = Shared::Exceptions::PermissionError
  ValidationError = Shared::Exceptions::ValidationError
  BusinessError = Shared::Exceptions::BusinessError
  ExternalServiceError = Shared::Exceptions::ExternalServiceError
end