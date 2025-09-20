module LocaleConcern
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
    around_action :switch_locale
  end

  private

  def set_locale
    requested_locale = params[:locale] || session[:locale] || I18n.default_locale
    
    # If no locale in URL and it's the root path, redirect to Arabic
    if params[:locale].blank? && request.path == '/' && requested_locale == :ar
      redirect_to url_for(locale: :ar, **params.permit!)
      return
    end
    
    I18n.locale = requested_locale
    session[:locale] = I18n.locale
  end

  def switch_locale(&action)
    locale = params[:locale] || session[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def default_url_options
    { locale: I18n.locale }
  end
end