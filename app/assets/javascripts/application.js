// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require rails-ujs
//= require activestorage
//= require upload
//= require_tree .

// Legacy compatibility functions (for existing code that calls these directly)
async function performUpload() {
  // Legacy function - redirect to unified upload
  const fileInput = document.getElementById('file-input');
  if (!fileInput || !fileInput.files[0]) {
    throw new Error('No file selected');
  }
  
  const progressFill = document.getElementById('progress-fill');
  const progressText = document.querySelector('.progress-text');
  
  return await performUnifiedUpload(fileInput.files[0], {
    progressElement: progressFill,
    progressTextElement: progressText
  });
}

// Legacy compatibility
window.performUpload = performUpload;