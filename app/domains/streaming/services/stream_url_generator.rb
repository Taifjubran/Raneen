module Streaming
  module Services
    class StreamUrlGenerator
      def self.generate(program)
        return nil unless program.can_be_streamed?
        
        cloudfront_domain = ENV['CLOUDFRONT_DOMAIN']
        return nil unless cloudfront_domain.present?
        
        if program.stream_path.start_with?('http')
          program.stream_path
        else
          "https://#{cloudfront_domain}#{program.stream_path}"
        end
      end
      
      def self.generate_thumbnail(program)
        return nil unless program.thumbnail_url.present?
        
        cloudfront_domain = ENV['CLOUDFRONT_DOMAIN']
        return nil unless cloudfront_domain.present?
        
        if program.thumbnail_url.start_with?('http')
          program.thumbnail_url
        else
          "https://#{cloudfront_domain}#{program.thumbnail_url}"
        end
      end
      
      def self.generate_preview_video(program)
        return nil unless program.preview_video_url.present?
        
        cloudfront_domain = ENV['CLOUDFRONT_DOMAIN']
        return nil unless cloudfront_domain.present?
        
        if program.preview_video_url.start_with?('http')
          program.preview_video_url
        else
          "https://#{cloudfront_domain}#{program.preview_video_url}"
        end
      end
      
      def self.generate_sprite_sheet(program)
        return nil unless program.sprite_sheet_url.present?
        
        cloudfront_domain = ENV['CLOUDFRONT_DOMAIN']
        return nil unless cloudfront_domain.present?
        
        if program.sprite_sheet_url.start_with?('http')
          program.sprite_sheet_url
        else
          "https://#{cloudfront_domain}#{program.sprite_sheet_url}"
        end
      end
    end
  end
end