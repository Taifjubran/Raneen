module Shared
  module Events
    class DomainEvent
      attr_reader :data, :occurred_at, :event_id
      
      def initialize(data = {})
        @data = data.freeze
        @occurred_at = Time.current
        @event_id = SecureRandom.uuid
      end
      
      def event_name
        self.class.name.demodulize.underscore
      end
      
      def to_h
        {
          event_id: event_id,
          event_name: event_name,
          occurred_at: occurred_at,
          data: data
        }
      end
    end
    
    class ProgramCreated < DomainEvent; end
    class ProgramPublished < DomainEvent; end
    class ProgramUnpublished < DomainEvent; end
    class ProgramDeleted < DomainEvent; end
    class MediaProcessingStarted < DomainEvent; end
    class TranscodingCompleted < DomainEvent; end
    class TranscodingFailed < DomainEvent; end
    class TranscodingProgressUpdated < DomainEvent; end
    
    class UserRoleChanged < DomainEvent; end
    class UserCreated < DomainEvent; end
    class UserLoggedIn < DomainEvent; end
    
    class ProgramViewed < DomainEvent; end
    class VideoPlayStarted < DomainEvent; end
    class VideoPlayCompleted < DomainEvent; end
    class SearchPerformed < DomainEvent; end
  end
  
  module EventPublisher
    @observers = {}
    @async_observers = {}
    
    def self.publish(event)
      Rails.logger.info "Publishing event: #{event.event_name} (#{event.event_id})"
      
      observers_for(event.class).each do |observer|
        begin
          observer.handle(event)
        rescue => error
          Rails.logger.error "Observer #{observer.class.name} failed: #{error.message}"
        end
      end
      
      async_observers_for(event.class).each do |observer_class|
        begin
          observer_class.perform_later(event.to_h)
        rescue => error
          Rails.logger.error "Async observer #{observer_class.name} failed to enqueue: #{error.message}"
        end
      end
    end
    
    def self.register_observer(event_class, observer)
      @observers[event_class] ||= []
      @observers[event_class] << observer
      Rails.logger.info "Registered observer #{observer.class.name} for #{event_class.name}"
    end
    
    def self.register_async_observer(event_class, observer_job_class)
      @async_observers[event_class] ||= []
      @async_observers[event_class] << observer_job_class
      Rails.logger.info "Registered async observer #{observer_job_class.name} for #{event_class.name}"
    end
    
    def self.unregister_observer(event_class, observer)
      return unless @observers[event_class]
      @observers[event_class].delete(observer)
    end
    
    def self.clear_observers(event_class = nil)
      if event_class
        @observers[event_class] = []
        @async_observers[event_class] = []
      else
        @observers.clear
        @async_observers.clear
      end
    end
    
    def self.observers_for(event_class)
      @observers[event_class] || []
    end
    
    def self.async_observers_for(event_class)
      @async_observers[event_class] || []
    end
    
    def self.all_observers
      {
        synchronous: @observers,
        asynchronous: @async_observers
      }
    end
  end
end