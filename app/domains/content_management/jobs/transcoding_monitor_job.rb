module ContentManagement
  module Jobs
    class TranscodingMonitorJob < ApplicationJob
  queue_as :default
  
  def perform(program_id)
    program = Program.find(program_id)
    return unless program.mediaconvert_job_id.present?
    return if program.status == 'ready'
    
    require 'aws-sdk-mediaconvert'
    
    begin
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
      
      response = mc_client.get_job(id: program.mediaconvert_job_id)
      job = response.job
      
      Rails.logger.info "MediaConvert job #{program.mediaconvert_job_id} status: #{job.status}"
      
      case job.status
      when 'COMPLETE'
        handle_job_complete(program, job)
      when 'ERROR', 'CANCELED'
        program.update!(status: 'failed')
        broadcast_status_update(program)
        Rails.logger.error "MediaConvert job failed for program #{program.id}"
      when 'PROGRESSING'
        if job.job_percent_complete
          program.update(transcoding_progress: job.job_percent_complete)
          broadcast_status_update(program)
        end
        ContentManagement::Jobs::TranscodingMonitorJob.set(wait: 30.seconds).perform_later(program_id)
      when 'SUBMITTED', 'PENDING'
        ContentManagement::Jobs::TranscodingMonitorJob.set(wait: 10.seconds).perform_later(program_id)
      end
      
    rescue Aws::MediaConvert::Errors::NotFoundException
      Rails.logger.error "MediaConvert job not found for program #{program.id}"
      check_s3_for_output(program)
    rescue => e
      Rails.logger.error "Error checking MediaConvert status: #{e.message}"
      ContentManagement::Jobs::TranscodingMonitorJob.set(wait: 1.minute).perform_later(program_id)
    end
  end
  
  private
  
  def handle_job_complete(program, job)
    filename_base = File.basename(program.source_s3_key, '.*')
    stream_path = "/hls/#{program.id}/#{filename_base}.m3u8"
    
    thumbnail_path = "/thumbnails/#{program.id}/#{filename_base}_thumbnail.0000000.jpg"
    
    preview_path = "/previews/#{program.id}/#{filename_base}_preview.mp4"
    sprite_path = "/sprites/#{program.id}/#{filename_base}_sprite.0000000.jpg"
    
    program.update!(
      status: 'ready',
      stream_path: stream_path,
      thumbnail_url: thumbnail_path,
      preview_video_url: preview_path,
      sprite_sheet_url: sprite_path,
      transcoding_progress: 100
    )
    
    broadcast_status_update(program)
    Rails.logger.info "Program #{program.id} transcoding complete. Stream: #{stream_path}, Thumbnail: #{thumbnail_path}"
  end
  
  def check_s3_for_output(program)
    require 'aws-sdk-s3'
    
    s3 = Aws::S3::Client.new(
      region: ENV['AWS_REGION'],
      access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    )
    
    bucket = ENV['S3_OUTPUTS_BUCKET']
    prefix = "hls/#{program.id}/"
    
    response = s3.list_objects_v2(bucket: bucket, prefix: prefix, max_keys: 5)
    
    if response.contents.any?
      # Files exist, find the playlist
      playlist = response.contents.find { |obj| obj.key.include?('.m3u8') }
      if playlist
        stream_path = "/#{playlist.key}"
        
        # Also check for thumbnail
        filename_base = File.basename(program.source_s3_key, '.*') if program.source_s3_key
        thumbnail_path = "/thumbnails/#{program.id}/#{filename_base}_thumbnail.0000000.jpg" if filename_base
        
        program.update!(
          status: 'ready',
          stream_path: stream_path,
          thumbnail_url: thumbnail_path,
          transcoding_progress: 100
        )
        broadcast_status_update(program)
        Rails.logger.info "Found completed transcode in S3 for program #{program.id}"
      end
    else
      Rails.logger.warn "No output files found for program #{program.id}"
    end
  rescue => e
    Rails.logger.error "Error checking S3: #{e.message}"
  end
  
  def broadcast_status_update(program)
    channel_name = "program_status_#{program.id}"
    data = {
      id: program.id,
      status: program.status,
      transcoding_progress: program.transcoding_progress,
      stream_path: program.stream_path,
      thumbnail_url: program.thumbnail_url,
      updated_at: program.updated_at.iso8601
    }
    
    Rails.logger.info "📡 Broadcasting to #{channel_name}: #{data.inspect}"
    
    ActionCable.server.broadcast(channel_name, data)
    
    Rails.logger.info "✅ Broadcast sent successfully"
  end
    end
  end
end