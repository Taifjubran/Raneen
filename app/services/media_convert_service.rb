require 'aws-sdk-mediaconvert'
require 'aws-sdk-core'

class MediaConvertService
  def initialize
    @uploads_bucket = ENV['S3_UPLOADS_BUCKET']
    @outputs_bucket = ENV['S3_OUTPUTS_BUCKET']
  end

  def create_transcode_job(program_id, source_s3_key)
    Rails.logger.info "Starting MediaConvert job for program #{program_id}"
    
    client = Aws::MediaConvert::Client.new(
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    
    endpoints = client.describe_endpoints
    endpoint_url = endpoints.endpoints.first.url
    
    mc_client = Aws::MediaConvert::Client.new(
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      endpoint: endpoint_url
    )

    job_name = "raneen-program-#{program_id}-#{Time.now.to_i}"
    input_uri = "s3://#{@uploads_bucket}/#{source_s3_key}"
    output_path = "s3://#{@outputs_bucket}/hls/#{program_id}/"
    
    filename_base = File.basename(source_s3_key, '.*')

    job_settings = build_job_settings(job_name, input_uri, output_path, program_id, source_s3_key)
    
    response = mc_client.create_job(job_settings)
    
    Rails.logger.info "MediaConvert job created: #{response.job.id}"
    
    {
      job_id: response.job.id,
      job_arn: response.job.arn,
      status: response.job.status
    }
  rescue => e
    Rails.logger.error "MediaConvert job creation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def build_job_settings(job_name, input_uri, output_path, program_id, source_s3_key)
    {
      role: media_convert_role_arn,
      queue: "Default",
      settings: {
        inputs: [
          {
            audio_selectors: {
              "Audio Selector 1" => {
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
            file_input: input_uri
          }
        ],
        output_groups: [
          {
            name: "Thumbnails",
            output_group_settings: {
              type: "FILE_GROUP_SETTINGS",
              file_group_settings: {
                destination: "s3://#{@outputs_bucket}/thumbnails/#{program_id}/"
              }
            },
            outputs: [
              {
                name_modifier: "_thumbnail",
                container_settings: {
                  container: "RAW"
                },
                video_description: {
                  width: 1280,
                  height: 720,
                  scaling_behavior: "DEFAULT",
                  codec_settings: {
                    codec: "FRAME_CAPTURE",
                    frame_capture_settings: {
                      framerate_numerator: 1,
                      framerate_denominator: 5,
                      max_captures: 3,
                      quality: 80
                    }
                  }
                }
              }
            ]
          },
          {
            name: "Preview Clip",
            output_group_settings: {
              type: "FILE_GROUP_SETTINGS",
              file_group_settings: {
                destination: "s3://#{@outputs_bucket}/previews/#{program_id}/"
              }
            },
            outputs: [
              {
                name_modifier: "_preview",
                container_settings: {
                  container: "MP4"
                },
                video_description: {
                  width: 640,
                  height: 360,
                  scaling_behavior: "DEFAULT",
                  codec_settings: {
                    codec: "H_264",
                    h264_settings: {
                      rate_control_mode: "QVBR",
                      max_bitrate: 1000000,
                      qvbr_settings: {
                        qvbr_quality_level: 7
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
                        bitrate: 96000,
                        coding_mode: "CODING_MODE_2_0",
                        sample_rate: 48000
                      }
                    }
                  }
                ]
              }
            ]
          },
          {
            name: "Thumbnail Sprites",
            output_group_settings: {
              type: "FILE_GROUP_SETTINGS",
              file_group_settings: {
                destination: "s3://#{@outputs_bucket}/sprites/#{program_id}/"
              }
            },
            outputs: [
              {
                name_modifier: "_sprite",
                container_settings: {
                  container: "RAW"
                },
                video_description: {
                  width: 160,
                  height: 90,
                  scaling_behavior: "DEFAULT",
                  codec_settings: {
                    codec: "FRAME_CAPTURE",
                    frame_capture_settings: {
                      framerate_numerator: 1,
                      framerate_denominator: 10,
                      max_captures: 100,
                      quality: 80
                    }
                  }
                }
              }
            ]
          },
          {
            name: "Apple HLS",
            output_group_settings: {
              type: "HLS_GROUP_SETTINGS",
              hls_group_settings: {
                manifest_duration_format: "INTEGER",
                segment_length: 10,
                min_segment_length: 0,
                destination: output_path
              }
            },
            outputs: [
              {
                name_modifier: "_720p",
                output_settings: {
                  hls_settings: {}
                },
                container_settings: {
                  container: "M3U8"
                },
                video_description: {
                  width: 1280,
                  height: 720,
                  scaling_behavior: "DEFAULT",
                  sharpness: 100,
                  codec_settings: {
                    codec: "H_264",
                    h264_settings: {
                      rate_control_mode: "QVBR",
                      max_bitrate: 5000000,
                      qvbr_settings: {
                        qvbr_quality_level: 7
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
                ]
              }
            ]
          }
        ]
      },
      user_metadata: {
        "program_id" => program_id.to_s,
        "source_file" => source_s3_key,
        "webhook_url" => webhook_url
      }
    }
  end

  def media_convert_role_arn
    ENV['MEDIACONVERT_ROLE_ARN'] || "arn:aws:iam::670914051455:role/MediaConvertS3Role"
  end

  def aws_account_id
    sts = Aws::STS::Client.new(
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    sts.get_caller_identity.account
  rescue
    "123456789012" 
  end

  def webhook_url
    "#{ENV['APP_DOMAIN'] || 'http://localhost:3000'}/api/cms/mediaconvert/callback"
  end
end