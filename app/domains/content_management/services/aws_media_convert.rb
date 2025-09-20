module ContentManagement
  module Services
    class AwsMediaConvert
      def self.start_transcoding(program_id:, source_key:)
        client = build_client
        
        job_settings = build_job_settings(program_id, source_key)
        
        response = client.create_job(
          role: ENV['MEDIACONVERT_ROLE_ARN'],
          settings: job_settings
        )
        
        response.job.id
      rescue Aws::MediaConvert::Errors::ServiceError => error
        Rails.logger.error "MediaConvert failed: #{error.message}"
        raise ExternalServiceError, "Transcoding failed: #{error.message}"
      end
      
      def self.get_job_status(job_id)
        client = build_client
        response = client.get_job(id: job_id)
        
        {
          status: response.job.status,
          progress: response.job.job_percent_complete,
          error_message: response.job.error_message
        }
      rescue Aws::MediaConvert::Errors::NotFound
        Rails.logger.warn "MediaConvert job not found: #{job_id}"
        { status: 'NOT_FOUND', progress: 0 }
      end
      
      private
      
      def self.build_client
        # Build AWS MediaConvert client
        endpoints = Aws::MediaConvert::Client.new(
          region: ENV['AWS_REGION'],
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        ).describe_endpoints
        
        Aws::MediaConvert::Client.new(
          region: ENV['AWS_REGION'],
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
          endpoint: endpoints.endpoints.first.url
        )
      end
      
      def self.build_job_settings(program_id, source_key)
        {
          inputs: [{
            file_input: "s3://#{ENV['S3_UPLOADS_BUCKET']}/#{source_key}"
          }],
          output_groups: [
            # HLS output configuration
            {
              name: "HLS",
              output_group_settings: {
                type: "HLS_GROUP_SETTINGS",
                hls_group_settings: {
                  destination: "s3://#{ENV['S3_OUTPUTS_BUCKET']}/hls/#{program_id}/"
                }
              },
              outputs: [{
                name_modifier: "_hls",
                video_description: {
                  codec_settings: {
                    codec: "H_264"
                  }
                }
              }]
            },
            # Thumbnail output
            {
              name: "Thumbnails",
              output_group_settings: {
                type: "FILE_GROUP_SETTINGS",
                file_group_settings: {
                  destination: "s3://#{ENV['S3_OUTPUTS_BUCKET']}/thumbnails/#{program_id}/"
                }
              },
              outputs: [{
                name_modifier: "_thumbnail",
                video_description: {
                  codec_settings: {
                    codec: "FRAME_CAPTURE"
                  }
                }
              }]
            }
          ]
        }
      end
    end
  end
end