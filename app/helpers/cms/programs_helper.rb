module Cms::ProgramsHelper
  def time_duration_in_words(seconds)
    return "0:00" if seconds.nil? || seconds <= 0
    
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    remaining_seconds = seconds % 60
    
    if hours > 0
      sprintf("%d:%02d:%02d", hours, minutes, remaining_seconds)
    else
      sprintf("%d:%02d", minutes, remaining_seconds)
    end
  end

  def program_thumbnail_url(program)
    return nil unless program.thumbnail_url.present? && program.status == 'ready'
    
    cloudfront_domain = ENV['CLOUDFRONT_DOMAIN']
    return nil unless cloudfront_domain.present?
    
    "https://#{cloudfront_domain}#{program.thumbnail_url}"
  end

  def program_has_thumbnail?(program)
    program.thumbnail_url.present? && program.status == 'ready'
  end
end
