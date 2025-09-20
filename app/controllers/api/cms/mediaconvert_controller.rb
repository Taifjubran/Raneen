module Api
  module Cms
    class MediaconvertController < ApplicationController
      skip_before_action :verify_authenticity_token if respond_to?(:verify_authenticity_token)
      
      def callback
        begin
          raw_body = request.body.read
          message = JSON.parse(raw_body)
          
          if verify_sns_signature(message, raw_body)
            handle_sns_message(message)
            head :ok
          else
            Rails.logger.error "Invalid SNS signature"
            head :unauthorized
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Invalid JSON in SNS callback: #{e.message}"
          head :bad_request
        rescue => e
          Rails.logger.error "MediaConvert callback error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")

          head :ok
        end
      end

      private

      def verify_sns_signature(message, raw_body)
        begin
          verifier = Aws::SNS::MessageVerifier.new
          verifier.authenticate!(raw_body)
          true
        rescue => e
          Rails.logger.error "SNS signature verification failed: #{e.message}"
          false
        end
      end

      def handle_sns_message(message)
        case message['Type']
        when 'SubscriptionConfirmation'
          confirm_subscription(message)
        when 'Notification'
          process_mediaconvert_event(JSON.parse(message['Message']))
        when 'UnsubscribeConfirmation'
          Rails.logger.info "SNS Unsubscribe confirmation received"
        else
          Rails.logger.warn "Unknown SNS message type: #{message['Type']}"
        end
      end

      def confirm_subscription(message)
        require 'net/http'
        uri = URI(message['SubscribeURL'])
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          Rails.logger.info "SNS subscription confirmed successfully"
          Rails.logger.info "Subscription ARN will be: #{message['TopicArn']}"
          
          Rails.cache.write("sns_subscription_confirmed", true, expires_in: 1.year)
        else
          Rails.logger.error "Failed to confirm SNS subscription: #{response.code}"
        end
      end

      def process_mediaconvert_event(event)
        detail = event['detail']
        return unless detail
        
        job_id = detail['jobId']
        status = detail['status']
        
        Rails.logger.info "Processing MediaConvert job: #{job_id} with status: #{status}"
        
        program_id = extract_program_id(detail)
        
        unless program_id
          Rails.logger.error "Could not extract program_id from MediaConvert event"
          return
        end
        
        program = Program.find_by(id: program_id)
        unless program
          Rails.logger.error "Program not found with id: #{program_id}"
          return
        end

        case status
        when 'COMPLETE'
          handle_job_complete(program, detail)
        when 'ERROR'
          handle_job_error(program, detail)
        when 'PROGRESSING'
          Rails.logger.info "Job #{job_id} is progressing for program #{program_id}"
        when 'SUBMITTED', 'PENDING'
          Rails.logger.info "Job #{job_id} is #{status} for program #{program_id}"
        else
          Rails.logger.warn "Unknown MediaConvert status: #{status}"
        end
      end

      def extract_program_id(detail)
        user_metadata = detail.dig('userMetadata', 'programId')
        return user_metadata if user_metadata
        
        output_details = detail.dig('outputGroupDetails', 0, 'outputDetails', 0)
        if output_details && output_details['outputFilePaths']
          path = output_details['outputFilePaths'].first
          match = path&.match(/\/hls\/(\d+)\//)
          return match[1] if match
        end
        
        if detail['jobTemplate']
          template_metadata = detail.dig('jobTemplate', 'settings', 'userMetadata', 'programId')
          return template_metadata if template_metadata
        end
        
        nil
      end

      def handle_job_complete(program, detail)
        output_group = detail['outputGroupDetails']&.first
        return unless output_group
      
        Rails.logger.info "Output group details: #{output_group.inspect}"
        
        stream_path = nil
        
        playlist_paths = output_group['playlistFilePaths'] || []
        if playlist_paths.any?
          master_playlist = playlist_paths.find { |p| p.include?('.m3u8') } || playlist_paths.first
          if master_playlist

            stream_path = master_playlist.sub(/^s3:\/\/[^\/]+/, '')
          end
        end
        
        if stream_path.nil? && detail['outputGroupDetails']

          if program.source_s3_key.present?
            filename_base = File.basename(program.source_s3_key, '.*')
            stream_path = "/hls/#{program.id}/#{filename_base}.m3u8"
            Rails.logger.info "Constructed stream path: #{stream_path}"
          end
        end
        
        duration = output_group.dig('outputDetails', 0, 'durationInMs')
        duration_seconds = duration ? (duration / 1000.0).round : nil
        
        filename_base = File.basename(program.source_s3_key, '.*') if program.source_s3_key
        thumbnail_path = "/thumbnails/#{program.id}/#{filename_base}_thumbnail.0000000.jpg" if filename_base
        
        program.update!(
          status: 'ready',
          stream_path: stream_path,
          thumbnail_url: thumbnail_path,
          duration_seconds: duration_seconds,
          mediaconvert_job_id: detail['jobId']
        )
        
        Rails.logger.info "Program #{program.id} marked as ready with stream path: #{stream_path}"
      end

      def handle_job_error(program, detail)
        error_code = detail.dig('errorCode')
        error_message = detail.dig('errorMessage')
        
        program.update!(
          status: 'failed',
          mediaconvert_job_id: detail['jobId']
        )
        
        Rails.logger.error "Program #{program.id} processing failed: #{error_code} - #{error_message}"
      end
    end
  end
end