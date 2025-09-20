puts "Creating admin user..."
admin_user = User.create!(
  email: 'admin@raneen.com',
  password: 'password123',
  password_confirmation: 'password123',
  role: 'admin'
)
puts "Admin user created: #{admin_user.email} (password: password123)"

editor_user = User.create!(
  email: 'editor@raneen.com',
  password: 'password123',
  password_confirmation: 'password123',
  role: 'editor'
)
puts "Editor user created: #{editor_user.email} (password: password123)"

puts "Creating sample programs..."

3.times do |i|
  Program.create!(
    title: "Draft Podcast Episode #{i + 1}",
    description: "This is a draft podcast episode that hasn't been published yet.",
    kind: "podcast",
    language: "en",
    category: "Technology",
    tags: ["tech", "innovation", "draft"],
    status: "draft",
    published_at: i.days.from_now
  )
end

5.times do |i|
  Program.create!(
    title: "The Future of AI - Episode #{i + 1}",
    description: "An in-depth exploration of artificial intelligence and its impact on society. This episode covers machine learning, neural networks, and the ethical considerations of AI development.",
    kind: "podcast",
    language: "en",
    category: "Technology",
    tags: ["AI", "technology", "future", "machine learning"],
    status: "ready",
    duration_seconds: rand(1800..3600),
    published_at: i.days.ago,
    stream_path: "/hls/sample-#{i + 1}/master.m3u8",
    poster_url: "/thumbs/sample-#{i + 1}/poster.jpg"
  )
end

3.times do |i|
  Program.create!(
    title: "Hidden Rivers - Part #{i + 1}",
    description: "A documentary series exploring the hidden waterways beneath major cities around the world. Discover the forgotten rivers that shaped our urban landscapes.",
    kind: "documentary",
    language: "en",
    category: "Science",
    tags: ["nature", "cities", "water", "environment"],
    status: "ready",
    duration_seconds: rand(2400..5400),
    published_at: (i * 7).days.ago,
    stream_path: "/hls/doc-#{i + 1}/master.m3u8",
    poster_url: "/thumbs/doc-#{i + 1}/poster.jpg"
  )
end

Program.create!(
  title: "تاريخ الخليج العربي",
  description: "وثائقي عن تاريخ وثقافة منطقة الخليج العربي عبر العصور",
  kind: "documentary",
  language: "ar",
  category: "History",
  tags: ["تاريخ", "ثقافة", "الخليج"],
  status: "ready",
  duration_seconds: 3600,
  published_at: 2.days.ago,
  stream_path: "/hls/arabic-1/master.m3u8",
  poster_url: "/thumbs/arabic-1/poster.jpg"
)

# Create a program with external URL (YouTube)
Program.create!(
  title: "External Content Example",
  description: "This content is hosted externally on YouTube",
  kind: "podcast",
  language: "en",
  category: "Education",
  tags: ["external", "youtube"],
  status: "ready",
  published_at: 1.day.ago,
  external_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
)

puts "Created #{Program.count} programs!"
puts "  - Draft: #{Program.draft.count}"
puts "  - Ready: #{Program.ready.count}"
puts "  - Podcasts: #{Program.podcast.count}"
puts "  - Documentaries: #{Program.documentary.count}"
