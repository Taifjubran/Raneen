require_relative '../../app/domains/shared/exceptions'
require_relative '../../app/domains/shared/events'

require_relative '../../app/domains/content_management/services/transcoding_strategies'
require_relative '../../app/domains/content_management/services/aws_media_convert_service'
require_relative '../../app/domains/content_management/services/media_processing_template'
require_relative '../../app/domains/content_management/services/media_processor'

Dir[Rails.root.join('app/domains/*/services/*.rb')].each do |f| 
  next if f.include?('transcoding_strategies.rb') || f.include?('aws_media_convert_service.rb') || f.include?('media_processing_template.rb') || f.include?('media_processor.rb')
  require f 
end
Dir[Rails.root.join('app/domains/*/event_handlers.rb')].each { |f| require f }
Dir[Rails.root.join('app/domains/*/commands.rb')].each { |f| require f }

Rails.logger.info "Domain classes loaded successfully" if Rails.env.development?