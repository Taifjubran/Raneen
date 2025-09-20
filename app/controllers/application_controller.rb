class ApplicationController < ActionController::Base
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include Pagy::Backend
  include LocaleConcern
  
  protect_from_forgery with: :exception, unless: -> { 
    request.format.json? || request.path.start_with?('/api/')
  }
  
  private

  def authenticate_cms!
    if request.format.json?
      if user_signed_in? && current_user.can_manage_programs?

        return true
      else

        authenticate_or_request_with_http_basic do |username, password|
          username == ENV['CMS_USERNAME'] && password == ENV['CMS_PASSWORD']
        end
      end
    else

      authenticate_user!
      unless current_user.can_manage_programs?
        redirect_to root_path, alert: 'Access denied. You need editor privileges.'
      end
    end
  end
end
