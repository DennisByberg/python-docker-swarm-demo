// Handle form submission with spinner and auto-reload
document.getElementById('form').addEventListener('submit', async function (e) {
  e.preventDefault();

  const btn = document.getElementById('btn');

  // Show loading state
  btn.innerHTML = '<div class="spinner"></div>Uploading...';
  btn.disabled = true;

  try {
    // Submit form data
    await fetch('/upload', { method: 'POST', body: new FormData(this) });

    this.reset();
    location.reload();
  } catch (error) {
    alert('Upload failed');
    btn.innerHTML = 'Upload';
    btn.disabled = false;
  }
});
