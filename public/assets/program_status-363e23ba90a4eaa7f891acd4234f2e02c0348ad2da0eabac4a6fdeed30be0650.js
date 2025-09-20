function initializeProgramStatusSubscription(programId) {
  if (!window.App || !window.App.cable) {
    return;
  }

  if (window.programStatusSubscription) {
    window.programStatusSubscription.unsubscribe();
  }

  window.programStatusSubscription = App.cable.subscriptions.create(
    { 
      channel: "ProgramStatusChannel", 
      program_id: programId 
    },
    {
      connected() {},

      disconnected() {},

      received(data) {
        updateProgramStatus(data);
      }
    }
  );
}

function updateProgramStatus(data) {
  const statusElement = document.getElementById('program-status');
  if (statusElement) {
    const newStatus = data.status.charAt(0).toUpperCase() + data.status.slice(1);
    statusElement.textContent = newStatus;
    statusElement.className = `status-badge status-${data.status}`;
  }

  const progressElement = document.getElementById('transcoding-progress');
  if (progressElement && data.transcoding_progress) {
    progressElement.textContent = `${data.transcoding_progress}%`;
  }
  switch(data.status) {
    case 'processing':
      handleProcessingStatus(data);
      break;
    case 'ready':
      handleReadyStatus(data);
      break;
    case 'failed':
      handleFailedStatus(data);
      break;
  }
}

function handleProcessingStatus(data) {
  const processingSection = document.querySelector('.processing-animation');
  if (!processingSection) {
    showProcessingUI();
  }

  if (data.transcoding_progress) {
    const progressText = document.querySelector('.processing-animation p');
    if (progressText) {
      progressText.textContent = `Processing video for streaming... ${data.transcoding_progress}%`;
    }
  }
}

function handleReadyStatus(data) {
  showAlert('Program is ready for streaming!', 'success');
  
  const processingSection = document.querySelector('.upload-section .processing-animation');
  if (processingSection) {
    processingSection.style.display = 'none';
  }

  if (data.stream_path) {
    showPreviewPlayer(data.stream_path);
  }

  enablePublishButton();
}

function handleFailedStatus(data) {
  showAlert('Program processing failed. Please try uploading again.', 'error');
  
  const processingSection = document.querySelector('.upload-section .processing-animation');
  if (processingSection) {
    processingSection.style.display = 'none';
  }

  showUploadForm();
}

function showProcessingUI() {
  const uploadSection = document.querySelector('.upload-section .detail-card');
  if (uploadSection) {
    uploadSection.innerHTML = `
      <h2>Processing Video</h2>
      <div class="alert alert-info">
        Your video is being processed. This may take several minutes depending on the file size.
        The page will automatically update when processing is complete.
      </div>
      
      <div class="processing-animation">
        <div class="spinner"></div>
        <p>Processing video for streaming...</p>
        <div id="transcoding-progress"></div>
      </div>
    `;
  }
}

function showPreviewPlayer(streamPath) {
  const uploadSection = document.querySelector('.upload-section');
  if (uploadSection) {
    uploadSection.innerHTML = `
      <div class="detail-card">
        <h2>Preview</h2>
        <div class="alert alert-success">
          Your program is ready for streaming!
        </div>
        
        <div id="preview-container">
          <div class="video-player">
            <video controls width="100%" id="preview-player">
              Your browser does not support the video tag.
            </video>
          </div>
        </div>
      </div>
    `;

    // Initialize player
    const videoElement = document.getElementById('preview-player');
    if (videoElement && streamPath) {
      const fullStreamUrl = `https://${window.CLOUDFRONT_DOMAIN}${streamPath}`;
      initializePlayer(videoElement, fullStreamUrl);
    }
  }
}

function enablePublishButton() {
  const publishButton = document.querySelector('.publish-form input[type="submit"]');
  if (publishButton) {
    publishButton.disabled = false;
    publishButton.style.display = 'inline-block';
  }
}

function showUploadForm() {
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


window.testActionCable = function(programId) {
  console.log('Testing Action Cable connection...');
  if (!window.App || !window.App.cable) {
    console.error('Action Cable not available');
    return;
  }
  
  console.log('Creating test subscription...');
  const testSub = App.cable.subscriptions.create(
    { channel: "ProgramStatusChannel", program_id: programId },
    {
      connected() { console.log('Test connection successful!'); },
      disconnected() { console.log(' Test disconnected'); },
      received(data) { console.log('Test received:', data); }
    }
  );
  
  return testSub;
};

window.triggerTestBroadcast = function(programId) {
  fetch(`/test/broadcast/${programId}`)
    .then(response => response.json())
    .then(data => console.log('Test broadcast triggered:', data))
    .catch(error => console.error('Test broadcast failed:', error));
};
