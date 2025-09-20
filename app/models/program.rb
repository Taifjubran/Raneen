class Program < ApplicationRecord
  enum :kind, { podcast: "podcast", documentary: "documentary" }, enum_type: :program_kind
  enum :status, { draft: "draft", processing: "processing", ready: "ready", failed: "failed" }, enum_type: :program_status

  after_initialize :set_default_status, if: :new_record?
  

  validates :title, presence: true

  scope :published, -> { 
    where(status: "ready")
      .where.not(published_at: nil)
      .where.not(stream_path: [nil, ""])
  }
  
  scope :search, ->(query) {
    return all if query.blank?
    where(
      "title ILIKE ? OR description ILIKE ? OR category ILIKE ? OR array_to_string(tags, ' ') ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    ).order(:title)
  }

  scope :by_kind, ->(kind) { where(kind: kind) if kind.present? }
  scope :by_language, ->(lang) { where(language: lang) if lang.present? }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :published_before, ->(date) { where("published_at < ?", date) if date.present? }
  scope :published_after, ->(date) { where("published_at > ?", date) if date.present? }

  def can_transition_to?(new_status)
    case [status, new_status.to_s]
    when ['draft', 'processing'] then true
    when ['processing', 'ready'] then true
    when ['processing', 'failed'] then true
    when ['failed', 'processing'] then true
    else false
    end
  end
  
  def next_possible_statuses
    case status
    when 'draft' then ['processing']
    when 'processing' then ['ready', 'failed']
    when 'ready' then []
    when 'failed' then ['processing']
    end
  end
  
  def stream_url
    return nil unless ready? && stream_path.present?
    
    if stream_path.start_with?('http')
      stream_path
    else
      "https://#{ENV['CLOUDFRONT_DOMAIN']}#{stream_path}"
    end
  end

  def full_poster_url
    return nil unless poster_url.present?
    "https://#{ENV['CLOUDFRONT_DOMAIN']}#{poster_url}"
  end
  
  def full_thumbnail_url
    return nil unless thumbnail_url.present?
    Streaming::Services::StreamUrlGenerator.generate_thumbnail(self)
  end
  
  def full_preview_video_url
    return nil unless preview_video_url.present?
    
    if preview_video_url.start_with?('http')
      preview_video_url
    else
      "https://#{ENV['CLOUDFRONT_DOMAIN']}#{preview_video_url}"
    end
  end
  
  def full_sprite_sheet_url
    return nil unless sprite_sheet_url.present?
    
    if sprite_sheet_url.start_with?('http')
      sprite_sheet_url
    else
      "https://#{ENV['CLOUDFRONT_DOMAIN']}#{sprite_sheet_url}"
    end
  end

  def duration_formatted
    return nil unless duration_seconds
    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    seconds = duration_seconds % 60
    
    if hours > 0
      format("%d:%02d:%02d", hours, minutes, seconds)
    else
      format("%d:%02d", minutes, seconds)
    end
  end
  
  def duration_human_readable
    return nil unless duration_seconds
    
    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    remaining_seconds = duration_seconds % 60
    
    parts = []
    parts << "#{hours} hour#{'s' if hours != 1}" if hours > 0
    parts << "#{minutes} minute#{'s' if minutes != 1}" if minutes > 0
    parts << "#{remaining_seconds} second#{'s' if remaining_seconds != 1}" if remaining_seconds > 0 && hours == 0
    
    parts.join(', ')
  end
  
  def ready_for_publishing?
    ready? && title.present? && stream_path.present?
  end
  
  def can_be_streamed?
    ready? && stream_path.present?
  end
  
  def full_stream_url
    return nil unless can_be_streamed?
    Streaming::Services::StreamUrlGenerator.generate(self)
  end
  
  def valid_media_format?(filename)
    allowed_formats = %w[.mp4 .mov .avi .mkv .webm]
    extension = File.extname(filename).downcase
    allowed_formats.include?(extension)
  end
  
  def estimated_processing_time
    return nil unless filesize_bytes
    
    gb_size = filesize_bytes / 1.gigabyte.to_f
    (gb_size * 60).to_i
  end
  
  def publish!(user:)
    ::ContentManagement::Services::ProgramPublisher.publish(program: self, user: user)
  end
  
  def start_media_processing!(source_s3_key:)
    ::ContentManagement::Services::MediaProcessor.start_processing(
      program: self, 
      source_s3_key: source_s3_key
    )
  end

  private

  def set_default_status
    self.status ||= 'draft'
  end
  
end