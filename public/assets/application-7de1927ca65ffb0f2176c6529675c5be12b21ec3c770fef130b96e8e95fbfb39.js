// Application JavaScript

// HLS.js for video playback
function loadHLSPlayer() {
  if (window.Hls && window.Hls.isSupported()) {
    return true;
  }
  
  const script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/hls.js@1.4.12/dist/hls.min.js';
  document.head.appendChild(script);
  
  return new Promise((resolve) => {
    script.onload = () => resolve(true);
  });
}

// Initialize video player
async function initializePlayer(videoElement, streamUrl) {
  await loadHLSPlayer();
  
  if (window.Hls && window.Hls.isSupported()) {
    const hls = new window.Hls();
    hls.loadSource(streamUrl);
    hls.attachMedia(videoElement);
  } else if (videoElement.canPlayType('application/vnd.apple.mpegurl')) {
    videoElement.src = streamUrl;
  }
}

// Search functionality
function initializeSearch() {
  const searchForm = document.getElementById('search-form');
  if (!searchForm) return;
  
  searchForm.addEventListener('submit', function(e) {
    e.preventDefault();
    performSearch();
  });
}

function performSearch() {
  const formData = new FormData(document.getElementById('search-form'));
  const params = new URLSearchParams(formData);
  
  fetch(`/api/discovery/programs?${params}`)
    .then(response => response.json())
    .then(data => {
      displaySearchResults(data);
    })
    .catch(error => {
      showAlert('Search failed: ' + error.message, 'error');
    });
}

function displaySearchResults(data) {
  const resultsContainer = document.getElementById('search-results');
  if (!resultsContainer) return;
  
  resultsContainer.innerHTML = '';
  
  if (data.items && data.items.length > 0) {
    const grid = document.createElement('div');
    grid.className = 'programs-grid';
    
    data.items.forEach(program => {
      const card = createProgramCard(program);
      grid.appendChild(card);
    });
    
    resultsContainer.appendChild(grid);
    
    if (data.total_pages > 1) {
      const pagination = createPagination(data);
      resultsContainer.appendChild(pagination);
    }
  } else {
    resultsContainer.innerHTML = '<p>No programs found.</p>';
  }
}

function createProgramCard(program) {
  const card = document.createElement('div');
  card.className = 'program-card';
  card.onclick = () => playProgram(program.id);
  
  card.innerHTML = `
    <div class="program-poster" style="background-image: url('${program.poster_url || '/assets/default-poster.jpg'}')"></div>
    <div class="program-info">
      <h3 class="program-title">${program.title}</h3>
      <div class="program-meta">
        <span class="chip ${program.kind}">${program.kind}</span>
        <span class="chip">${program.language}</span>
        ${program.category ? `<span class="chip">${program.category}</span>` : ''}
      </div>
      <p>${program.description.substring(0, 100)}...</p>
      ${program.duration_formatted ? `<p><strong>Duration:</strong> ${program.duration_formatted}</p>` : ''}
    </div>
  `;
  
  return card;
}

function createPagination(data) {
  const pagination = document.createElement('div');
  pagination.className = 'pagination';
  pagination.innerHTML = `
    <p>Page ${data.page} of ${data.total_pages} (${data.total} total programs)</p>
  `;
  return pagination;
}

async function playProgram(programId) {
  try {
    const response = await fetch(`/api/discovery/programs/${programId}`);
    const program = await response.json();
    
    displayPlayer(program);
  } catch (error) {
    console.error('Error loading program:', error);
  }
}

function displayPlayer(program) {
  const playerContainer = document.getElementById('player-container');
  if (!playerContainer) return;
  
  playerContainer.innerHTML = `
    <div class="player-container">
      <h2>${program.title}</h2>
      <div class="video-player">
        <video controls width="100%" id="video-player">
          Your browser does not support the video tag.
        </video>
      </div>
      <div class="program-details">
        <p><strong>Duration:</strong> ${program.duration_formatted || 'Unknown'}</p>
        <p><strong>Language:</strong> ${program.language}</p>
        <p><strong>Category:</strong> ${program.category || 'Uncategorized'}</p>
        <p>${program.description}</p>
        ${program.tags && program.tags.length > 0 ? `
          <div class="program-tags">
            <strong>Tags:</strong>
            ${program.tags.map(tag => `<span class="chip">${tag}</span>`).join(' ')}
          </div>
        ` : ''}
      </div>
    </div>
  `;
  
  // Initialize player with HLS
  if (program.stream_url) {
    const videoElement = document.getElementById('video-player');
    initializePlayer(videoElement, program.stream_url);
  }
  
  // Scroll to player
  playerContainer.scrollIntoView({ behavior: 'smooth' });
}

// Upload functionality
function initializeUpload() {
  const uploadForm = document.getElementById('upload-form');
  if (!uploadForm) return;
  
  const fileInput = document.getElementById('file-input');
  const uploadBtn = document.getElementById('upload-btn');
  const progressContainer = document.getElementById('progress-container');
  const progressBar = document.getElementById('progress-fill');
  
  fileInput.addEventListener('change', function() {
    uploadBtn.disabled = !this.files.length;
  });
  
  uploadForm.addEventListener('submit', function(e) {
    e.preventDefault();
    performUpload();
  });
}

async function performUpload() {
  const fileInput = document.getElementById('file-input');
  const programId = document.getElementById('program-id').value;
  const file = fileInput.files[0];
  
  if (!file) return;
  
  try {
    const signResponse = await fetch('/api/cms/uploads/sign', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      credentials: 'same-origin',
      body: JSON.stringify({
        filename: file.name,
        content_type: file.type,
        size_bytes: file.size
      })
    });
    
    if (!signResponse.ok) {
      const errorData = await signResponse.json();
      throw new Error(`Failed to get upload URLs: ${errorData.error || signResponse.statusText}`);
    }
    
    const signData = await signResponse.json();
    
    await uploadToS3(file, signData);
    
    const ingestResponse = await fetch(`/api/cms/programs/${programId}/ingest_complete`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      credentials: 'same-origin',
      body: JSON.stringify({
        s3_key: signData.key
      })
    });
    
    if (!ingestResponse.ok) {
      const errorData = await ingestResponse.json();
      throw new Error(`Failed to mark ingest complete: ${errorData.error || ingestResponse.statusText}`);
    }
    
    // Step 4: Start polling for status
    startStatusPolling(programId);
    
  } catch (error) {
    showAlert('Upload failed: ' + error.message, 'error');
  }
}

async function uploadToS3(file, signData) {
  const progressContainer = document.getElementById('progress-container');
  const progressFill = document.getElementById('progress-fill');
  
  progressContainer.style.display = 'block';
  
  if (signData.upload_type === 'multipart') {
    await uploadMultipart(file, signData, progressFill);
  } else {
    await uploadSimple(file, signData, progressFill);
  }
}

async function uploadMultipart(file, signData, progressFill) {
  
  const uploadedParts = [];
  const partSize = signData.part_size;
  const startTime = Date.now();
  
  for (let i = 0; i < signData.parts.length; i++) {
    const part = signData.parts[i];
    const start = (part.part_number - 1) * partSize;
    const end = Math.min(start + part.size, file.size);
    const chunk = file.slice(start, end);
    
    const partStartTime = Date.now();
    
    try {
      // DON'T set Content-Type or any headers for multipart parts
      const response = await fetch(part.presigned_url, {
        method: 'PUT',
        body: chunk
      });
      
      const partEndTime = Date.now();
      const partDuration = (partEndTime - partStartTime) / 1000;
      
      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Failed to upload part ${part.part_number}: ${response.status}`);
      }
      
      const etag = response.headers.get('ETag');
      if (!etag) {
        throw new Error(`No ETag received for part ${part.part_number}`);
      }
      
      uploadedParts.push({
        ETag: etag,
        PartNumber: part.part_number
      });
      
      // Update progress
      const progress = ((i + 1) / signData.parts.length) * 100;
      progressFill.style.width = progress + '%';
    } catch (error) {
      throw error;
    }
  }
  

  
  const xmlBody = `<CompleteMultipartUpload>${uploadedParts.map(p => 
    `<Part><PartNumber>${p.PartNumber}</PartNumber><ETag>${p.ETag}</ETag></Part>`
  ).join('')}</CompleteMultipartUpload>`;
  
  try {
    const completeResponse = await fetch(signData.complete_url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/xml'
      },
      body: xmlBody
    });
    
    const responseText = await completeResponse.text();
    
    if (!completeResponse.ok) {
      throw new Error(`Failed to complete multipart upload: ${completeResponse.status}`);
    }
    
  } catch (error) {
    throw error;
  }
}

async function uploadSimple(file, signData, progressFill) {
  const response = await fetch(signData.presigned_url, {
    method: 'PUT',
    headers: {
      'Content-Type': file.type
    },
    body: file
  });
  
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to upload file: ${response.status} ${errorText}`);
  }
  
  progressFill.style.width = '100%';
}

function startStatusPolling(programId) {
  const statusElement = document.getElementById('program-status');
  
  const pollStatus = async () => {
    try {
      const response = await fetch(`/api/discovery/programs/${programId}`);
      const program = await response.json();
      
      statusElement.textContent = `Status: ${program.status}`;
      
      if (program.status === 'ready') {
        showAlert('Program is ready for streaming!', 'success');
        const previewContainer = document.getElementById('preview-container');
        if (previewContainer && program.stream_url) {
          previewContainer.innerHTML = `
            <h3>Preview</h3>
            <video controls width="100%" id="preview-player">
              Your browser does not support the video tag.
            </video>
          `;
          const videoElement = document.getElementById('preview-player');
          initializePlayer(videoElement, program.stream_url);
        }
      } else if (program.status === 'failed') {
        showAlert('Program processing failed. Please try uploading again.', 'error');
      } else if (program.status === 'processing') {
        setTimeout(pollStatus, 10000);
      }
    } catch (error) {
      showAlert('Failed to check program status', 'error');
    }
  };
  
  pollStatus();
}

function showAlert(message, type = 'info') {
  const alertContainer = document.getElementById('alerts') || document.body;
  const alert = document.createElement('div');
  alert.className = `alert alert-${type}`;
  alert.textContent = message;
  
  alertContainer.appendChild(alert);
  
  setTimeout(() => {
    alert.remove();
  }, 5000);
}

// Initialize everything when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  initializeSearch();
  initializeUpload();
});
