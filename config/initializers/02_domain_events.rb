# Domain Events and Observers Configuration
# This initializer sets up all domain event observers following the Observer pattern

Rails.application.config.after_initialize do
  # Skip if classes aren't loaded (useful for rake tasks that don't need events)
  unless defined?(Shared::EventPublisher) && defined?(Shared::Events)
    Rails.logger.warn "Domain event classes not loaded, skipping observer registration" if Rails.logger
    next
  end
  
  # Content Management Events - only register if handler exists
  if defined?(ContentManagement::EventHandlers::ProgramEventHandler)
    [
      Shared::Events::ProgramCreated,
      Shared::Events::ProgramPublished,
      Shared::Events::ProgramUnpublished,
      Shared::Events::ProgramDeleted
    ].each do |event_class|
      if defined?(event_class)
        Shared::EventPublisher.register_observer(
          event_class,
          ContentManagement::EventHandlers::ProgramEventHandler
        )
      end
    end
  end
  
  # Transcoding Events - only register if handler exists
  if defined?(ContentManagement::EventHandlers::TranscodingEventHandler)
    [
      Shared::Events::MediaProcessingStarted,
      Shared::Events::TranscodingCompleted,
      Shared::Events::TranscodingFailed,
      Shared::Events::TranscodingProgressUpdated
    ].each do |event_class|
      if defined?(event_class)
        Shared::EventPublisher.register_observer(
          event_class,
          ContentManagement::EventHandlers::TranscodingEventHandler
        )
      end
    end
  end
  
  # Cache Invalidation Events - only register if handler exists
  if defined?(ContentManagement::EventHandlers::CacheInvalidationHandler)
    [
      Shared::Events::ProgramPublished,
      Shared::Events::ProgramUnpublished,
      Shared::Events::TranscodingCompleted
    ].each do |event_class|
      if defined?(event_class)
        Shared::EventPublisher.register_observer(
          event_class,
          ContentManagement::EventHandlers::CacheInvalidationHandler
        )
      end
    end
  end
  
  Rails.logger.info "✅ Domain event observers registered successfully" if Rails.logger
end

# Development/debugging helper
if Rails.env.development?
  Rails.application.config.after_initialize do
    if defined?(Shared::EventPublisher)
      # Log all registered observers
      observers = Shared::EventPublisher.all_observers
      Rails.logger.info "📋 Registered Domain Event Observers:" if Rails.logger
      observers[:synchronous].each do |event_class, handler_list|
        Rails.logger.info "  #{event_class.name}: #{handler_list.map(&:name).join(', ')}" if Rails.logger
      end
    end
  end
end