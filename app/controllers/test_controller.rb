class TestController < ApplicationController
  def broadcast_test
    program_id = params[:program_id] || 1
    
    ActionCable.server.broadcast(
      "program_status_#{program_id}",
      {
        id: program_id,
        status: 'ready',
        transcoding_progress: 100,
        stream_path: '/test/stream.m3u8',
        thumbnail_url: '/test/thumb.jpg',
        updated_at: Time.current.iso8601
      }
    )
    
    render json: { message: "Broadcast sent to program_status_#{program_id}" }
  end
end