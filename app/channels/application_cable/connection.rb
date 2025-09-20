module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user

      if session_user_id = request.session[:user_id]
        verified_user = User.find_by(id: session_user_id)
        return verified_user if verified_user
      end
      
      if cookies.signed[:user_id].present?
        verified_user = User.find_by(id: cookies.signed[:user_id])
        return verified_user if verified_user
      end
      
      nil
    end
  end
end
