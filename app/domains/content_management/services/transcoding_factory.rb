module ContentManagement
  module Services
    class TranscodingFactory      
      def self.create_strategy(environment = Rails.env, options = {})
        strategy_class = determine_strategy_class(environment, options)
        strategy_class.new
      end
      
      def self.available_strategies
        {
          'aws_mediaconvert' => AwsMediaConvertService
        }
      end
      
      def self.strategy_for_environment(environment)
        # Always use AWS MediaConvert for all environments
        'aws_mediaconvert'
      end
      
      def self.create_strategy_by_name(strategy_name)
        strategy_class = available_strategies[strategy_name.to_s]
        
        unless strategy_class
          raise ContentManagement::ValidationError, 
                "Unknown transcoding strategy: #{strategy_name}. " \
                "Available: #{available_strategies.keys.join(', ')}"
        end
        
        strategy_class.new
      end
      
      # Advanced factory method with business logic
      def self.create_optimal_strategy_for_program(program)
        # For now, always use AWS MediaConvert
        # Future: Could implement priority queues or different processing tiers
        create_strategy_by_name('aws_mediaconvert')
      end
      
      def self.create_strategy_with_fallback(primary_strategy = nil)
        primary = primary_strategy || strategy_for_environment(Rails.env)
        create_strategy_by_name(primary)
      end
      
      private
      
      def self.determine_strategy_class(environment, options)
        if options[:strategy_name]
          return available_strategies[options[:strategy_name].to_s]
        end
        
        if ENV['TRANSCODING_STRATEGY'].present?
          strategy_name = ENV['TRANSCODING_STRATEGY']
          return available_strategies[strategy_name] if available_strategies[strategy_name]
        end
        
        strategy_name = strategy_for_environment(environment)
        available_strategies[strategy_name]
      end
    end
  end
end