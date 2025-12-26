module Api
  module Cms
    class UploadsController < ApplicationController
      before_action :authenticate_cms!

      def sign
        Rails.logger.info "Upload sign request: #{request.request_method} #{request.path}"
        Rails.logger.info "Request format: #{request.format}"
        Rails.logger.info "Request params: #{params.to_unsafe_h}"
        
        if request.get?
          return render json: { 
            error: "GET request received instead of POST",
            method: request.request_method,
            path: request.path,
            params: params.to_unsafe_h
          }, status: :method_not_allowed
        end
        filename = params[:filename]
        content_type = params[:content_type] || 'video/mp4'
        size_bytes = params[:size_bytes].to_i

        # Validate input
        if filename.blank?
          return render json: { error: "Filename is required" }, status: :unprocessable_entity
        end

        if size_bytes <= 0
          return render json: { error: "Invalid file size" }, status: :unprocessable_entity
        end

        # Generate unique key with timestamp and UUID
        timestamp = Time.now.strftime('%Y%m%d%H%M%S')
        file_ext = File.extname(filename)
        safe_filename = File.basename(filename, file_ext).gsub(/[^0-9A-Za-z\-_]/, '_')
        key = "uploads/#{timestamp}/#{SecureRandom.uuid}/#{safe_filename}#{file_ext}"
        
        # Use presigned PUT for files smaller than 100MB, multipart for larger files
        if size_bytes > 100_000_000
          presigned = create_multipart_upload(key, content_type, size_bytes)
        else
          presigned = create_simple_upload(key, content_type)
        end

        render json: presigned
      rescue Aws::S3::Errors::ServiceError => e
        Rails.logger.error "S3 Error: #{e.message}"
        render json: { error: "Failed to generate upload URL" }, status: :internal_server_error
      end

      private

      def create_multipart_upload(key, content_type, size_bytes)
        puts "=== Creating Multipart Upload ==="
        puts "File: #{params[:filename]}"
        puts "Size: #{size_bytes} bytes (#{(size_bytes / 1024.0 / 1024.0).round(2)} MB)"
        puts "Key: #{key}"
        puts "Content-Type: #{content_type}"
        puts "Bucket: #{ENV['S3_UPLOADS_BUCKET']}"
        puts "Region: #{ENV['AWS_REGION']}"

        Rails.logger.info "=== Creating Multipart Upload ==="
        Rails.logger.info "File: #{params[:filename]}"
        Rails.logger.info "Size: #{size_bytes} bytes (#{(size_bytes / 1024.0 / 1024.0).round(2)} MB)"
        Rails.logger.info "Key: #{key}"
        Rails.logger.info "Content-Type: #{content_type}"
        Rails.logger.info "Bucket: #{ENV['S3_UPLOADS_BUCKET']}"
        Rails.logger.info "Region: #{ENV['AWS_REGION']}"

        # Use Transfer Acceleration if enabled
        use_accelerate = ENV['S3_USE_ACCELERATE'] == 'true'

        s3 = Aws::S3::Client.new(
          region: ENV['AWS_REGION'],
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
          use_accelerate_endpoint: use_accelerate
        )
        
        presigner = Aws::S3::Presigner.new(client: s3)
        bucket = ENV['S3_UPLOADS_BUCKET']
        
        puts "S3 Client region: #{s3.config.region}"
        puts "Expected region: #{ENV['AWS_REGION']}"
        puts "Bucket: #{bucket}"
        
        # Initiate multipart upload
        response = s3.create_multipart_upload(
          bucket: bucket,
          key: key,
          content_type: content_type,
          metadata: {
            'original-filename' => params[:filename],
            'upload-timestamp' => Time.now.iso8601
          }
        )
        
        upload_id = response.upload_id
        puts "Upload ID created: #{upload_id}"
        Rails.logger.info "Upload ID created: #{upload_id}"
        
        # Calculate optimized part size (16-64MB chunks, max 10,000 parts)
        # Target 32MB parts, but ensure we don't exceed 10,000 parts limit
        target_part_size = 32 * 1024 * 1024  # 32MB
        min_part_size = 16 * 1024 * 1024     # 16MB minimum
        max_part_size = 64 * 1024 * 1024     # 64MB maximum
        
        part_size = [
          [target_part_size, (size_bytes.to_f / 10000).ceil].max,
          max_part_size
        ].min
        
        # Ensure minimum part size
        part_size = [part_size, min_part_size].max
        
        parts_count = (size_bytes.to_f / part_size).ceil
        
        puts "Part configuration:"
        puts "  Part size: #{part_size} bytes (#{(part_size / 1024.0 / 1024.0).round(2)} MB)"
        puts "  Total parts: #{parts_count}"
        puts "  Last part size: #{size_bytes - (part_size * (parts_count - 1))} bytes"
        
        Rails.logger.info "Part configuration:"
        Rails.logger.info "  Part size: #{part_size} bytes (#{(part_size / 1024.0 / 1024.0).round(2)} MB)"
        Rails.logger.info "  Total parts: #{parts_count}"
        Rails.logger.info "  Last part size: #{size_bytes - (part_size * (parts_count - 1))} bytes"
        
        # Generate presigned URLs for each part
        parts = (1..parts_count).map do |part_number|
          url = presigner.presigned_url(
            :upload_part,
            bucket: bucket,
            key: key,
            upload_id: upload_id,
            part_number: part_number,
            expires_in: 3600 # 1 hour expiry
          )
          
          { 
            part_number: part_number, 
            presigned_url: url,
            size: part_number == parts_count ? size_bytes - (part_size * (parts_count - 1)) : part_size
          }
        end

        # Also generate complete multipart upload URL
        complete_url = presigner.presigned_url(
          :complete_multipart_upload,
          bucket: bucket,
          key: key,
          upload_id: upload_id,
          expires_in: 3600
        )

        {
          upload_type: 'multipart',
          key: key,
          upload_id: upload_id,
          parts: parts,
          part_size: part_size,
          total_parts: parts_count,
          recommended_concurrency: [[parts_count, 10].min, 6].max,  # 6-10 parallel uploads
          require_no_headers_for_parts: true,  # Tell client not to send headers for parts
          complete_url: complete_url,
          abort_url: presigner.presigned_url(
            :abort_multipart_upload,
            bucket: bucket,
            key: key,
            upload_id: upload_id,
            expires_in: 3600
          )
        }
      end

      def create_presigned_post(key, content_type, size_bytes)
        s3 = Aws::S3::Client.new(
          region: ENV['AWS_REGION'],
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        )
        
        bucket = ENV['S3_UPLOADS_BUCKET']
        
        # Generate presigned POST (more reliable for form uploads)
        presigned_post = Aws::S3::PresignedPost.new(
          {
            region: ENV['AWS_REGION'],
            access_key_id: ENV['AWS_ACCESS_KEY_ID'],
            secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
          },
          bucket,
          key: key,
          expires: 3600,
          content_length_range: 1..(size_bytes + 1024) # Allow small variance
        )
        
        # Set required fields
        presigned_post.content_type(content_type)
        presigned_post.metadata['original-filename'] = params[:filename]
        presigned_post.metadata['upload-timestamp'] = Time.now.iso8601
        
        { 
          upload_type: 'post',
          key: key,
          url: presigned_post.url,
          fields: presigned_post.fields
        }
      end

      def create_simple_upload(key, content_type)
        use_accelerate = ENV['S3_USE_ACCELERATE'] == 'true'

        s3 = Aws::S3::Client.new(
          region: ENV['AWS_REGION'],
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
          use_accelerate_endpoint: use_accelerate
        )
        
        presigner = Aws::S3::Presigner.new(client: s3)
        bucket = ENV['S3_UPLOADS_BUCKET']
        
        url = presigner.presigned_url(
          :put_object,
          bucket: bucket,
          key: key,
          content_type: content_type,
          expires_in: 3600 # 1 hour expiry
        )

        { 
          upload_type: 'simple',
          key: key, 
          presigned_url: url 
        }
      end
    end
  end
end