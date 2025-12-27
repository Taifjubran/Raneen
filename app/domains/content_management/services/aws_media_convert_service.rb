module ContentManagement
  module Services
    # AWS MediaConvert transcoding service
    class AwsMediaConvertService < ContentManagement::Services::TranscodingStrategies::Base
      def start_transcoding(program_id, source_key)
        validate_input(program_id, source_key)
        
        client = build_aws_client
        job_settings = build_job_settings(program_id, source_key)
        
        response = client.create_job(
          queue: "arn:aws:mediaconvert:#{ENV['AWS_REGION']}:670914051455:queues/Default",
          user_metadata: {
            "program_id" => program_id.to_s,
            "source_file" => source_key,
            "webhook_url" => "#{ENV['CALLBACK_BASE_URL'] || 'http://localhost:3000'}/api/cms/mediaconvert/callback"
          },
          role: ENV['MEDIACONVERT_ROLE_ARN'],
          settings: job_settings,
          billing_tags_source: "JOB",
          acceleration_settings: {
            mode: "PREFERRED"  # Use accelerated transcoding when available (2-4x faster)
          },
          status_update_interval: "SECONDS_60",
          priority: 0
        )
        
        job_id = response.job.id
        log_transcoding_start(program_id, job_id)
        
        { job_id: job_id, status: 'SUBMITTED' }
      rescue Aws::MediaConvert::Errors::ServiceError => error
        log_transcoding_error(program_id, error)
        raise ContentManagement::ExternalServiceError, "AWS MediaConvert error: #{error.message}"
      end
      
      def get_job_status(job_id)
        client = build_aws_client
        response = client.get_job(id: job_id)
        
        {
          status: response.job.status,
          progress: response.job.job_percent_complete || 0,
          created_at: response.job.created_at,
          finished_at: response.job.finished_at
        }
      rescue Aws::MediaConvert::Errors::ServiceError => error
        Rails.logger.error "Failed to get job status: #{error.message}"
        { status: 'ERROR', progress: 0, error: error.message }
      end
      
      def cancel_job(job_id)
        client = build_aws_client
        client.cancel_job(id: job_id)
        Rails.logger.info "Cancelled AWS MediaConvert job: #{job_id}"
      rescue Aws::MediaConvert::Errors::ServiceError => error
        Rails.logger.error "Failed to cancel job #{job_id}: #{error.message}"
        raise ContentManagement::ExternalServiceError, "Failed to cancel job: #{error.message}"
      end
      
      private
      
      def build_aws_client
        # First create a base client to fetch the account-specific endpoint
        base_client = Aws::MediaConvert::Client.new(
          region: ENV['AWS_REGION'] || 'us-east-1',
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        )

        # Fetch the account-specific endpoint dynamically
        endpoints = base_client.describe_endpoints
        endpoint_url = endpoints.endpoints.first.url

        Rails.logger.info "Using MediaConvert endpoint: #{endpoint_url}"

        # Create the actual client with the correct endpoint
        Aws::MediaConvert::Client.new(
          endpoint: endpoint_url,
          region: ENV['AWS_REGION'] || 'us-east-1',
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        )
      end
      
      def build_job_settings(program_id, source_key)
        {
          inputs: [
            {
              audio_selectors: {
                "Audio Selector 1": {
                  offset: 0,
                  default_selection: "DEFAULT",
                  program_selection: 1
                }
              },
              video_selector: {
                color_space: "FOLLOW"
              },
              filter_enable: "AUTO",
              psi_control: "USE_PSI",
              filter_strength: 0,
              deblock_filter: "DISABLED",
              denoise_filter: "DISABLED",
              timecode_source: "EMBEDDED",
              file_input: "s3://#{ENV['S3_UPLOADS_BUCKET']}/#{source_key}"
            }
          ],
          output_groups: [
            build_thumbnail_output_group(program_id),
            build_hls_output_group(program_id)
          ]
        }
      end
      
      def build_hls_output_group(program_id)
        {
          name: "Apple HLS",
          outputs: [
            {
              container_settings: {
                container: "M3U8"
              },
              video_description: {
                width: 1280,
                scaling_behavior: "DEFAULT",
                height: 720,
                sharpness: 50,  # Reduced from 100 for faster processing
                codec_settings: {
                  codec: "H_264",
                  h264_settings: {
                    max_bitrate: 4000000,  # Reduced from 5Mbps for faster encoding
                    rate_control_mode: "QVBR",
                    qvbr_settings: {
                      qvbr_quality_level: 6  # Reduced from 7 for faster encoding (still good quality)
                    }
                  }
                }
              },
              audio_descriptions: [
                {
                  audio_source_name: "Audio Selector 1",
                  codec_settings: {
                    codec: "AAC",
                    aac_settings: {
                      bitrate: 128000,
                      coding_mode: "CODING_MODE_2_0",
                      sample_rate: 48000
                    }
                  }
                }
              ],
              output_settings: {
                hls_settings: {}
              },
              name_modifier: "_720p"
            }
          ],
          output_group_settings: {
            type: "HLS_GROUP_SETTINGS",
            hls_group_settings: {
              manifest_duration_format: "INTEGER",
              segment_length: 10,
              destination: "s3://#{ENV['S3_OUTPUTS_BUCKET']}/hls/#{program_id}/",
              min_segment_length: 0
            }
          }
        }
      end
      
      def build_thumbnail_output_group(program_id)
        {
          name: "Thumbnails",
          outputs: [
            {
              container_settings: {
                container: "RAW"
              },
              video_description: {
                width: 1280,
                scaling_behavior: "DEFAULT",
                height: 720,
                codec_settings: {
                  codec: "FRAME_CAPTURE",
                  frame_capture_settings: {
                    framerate_numerator: 1,
                    framerate_denominator: 5,
                    max_captures: 3,
                    quality: 80
                  }
                }
              },
              name_modifier: "_thumbnail"
            }
          ],
          output_group_settings: {
            type: "FILE_GROUP_SETTINGS",
            file_group_settings: {
              destination: "s3://#{ENV['S3_OUTPUTS_BUCKET']}/thumbnails/#{program_id}/"
            }
          }
        }
      end
    end
  end
end