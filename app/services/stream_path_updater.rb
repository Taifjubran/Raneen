class StreamPathUpdater
  def self.update_for_program(program)
    return unless program.source_s3_key.present?
    
    filename_base = File.basename(program.source_s3_key, '.*')
    
    expected_path = "/hls/#{program.id}/#{filename_base}.m3u8"
    
    cloudfront_url = "https://#{ENV['CLOUDFRONT_DOMAIN']}#{expected_path}"
    
    begin
      uri = URI(cloudfront_url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Head.new(uri)
        http.request(request)
      end
      
      if response.code == '200'
        Rails.logger.info "Stream found at: #{expected_path}"
        program.update!(
          stream_path: expected_path,
          status: 'ready'
        )
        return true
      else
        Rails.logger.info "Stream not found at: #{expected_path} (HTTP #{response.code})"
        return false
      end
    rescue => e
      Rails.logger.error "Error checking stream: #{e.message}"
      return false
    end
  end
  
  def self.check_processing_programs
    Program.where(status: 'processing').where.not(mediaconvert_job_id: nil).each do |program|
      if update_for_program(program)
        Rails.logger.info "Updated stream path for program #{program.id}"
      end
    end
  end
end