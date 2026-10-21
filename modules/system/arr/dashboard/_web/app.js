// Update Live Clock
function updateClock() {
  const now = new Date();
  const clockEl = document.getElementById('clock');
  if (clockEl) {
    clockEl.textContent = now.toTimeString().split(' ')[0];
  }
}
setInterval(updateClock, 1000);
updateClock();

// Smart link resolution: strictly resolve all links to subdomains
const currentHost = window.location.hostname;
const currentPort = window.location.port;
const protocol = window.location.protocol;
const portSuffix = (currentPort && currentPort !== "80" && currentPort !== "443") ? (":" + currentPort) : "";

// Update primary action buttons and title links
document.querySelectorAll('[data-subdomain]').forEach(el => {
  const sub = el.getAttribute('data-subdomain');
  if (currentHost === 'localhost' || currentHost === '127.0.0.1') {
    el.href = protocol + '//' + sub + '.localhost' + portSuffix;
  } else {
    el.href = protocol + '//' + sub + '.' + currentHost + portSuffix;
  }
});

// Update subdomain pill badges
document.querySelectorAll('[data-subdomain-pill]').forEach(el => {
  const sub = el.getAttribute('data-subdomain-pill');
  if (currentHost === 'localhost' || currentHost === '127.0.0.1') {
    el.textContent = sub + '.localhost';
    el.href = protocol + '//' + sub + '.localhost' + portSuffix;
  } else {
    el.textContent = sub + '.' + currentHost;
    el.href = protocol + '//' + sub + '.' + currentHost + portSuffix;
  }
});

// Live Health & Network Bandwidth Polling
async function updateStats() {
  try {
    const res = await fetch('/api/stats');
    if (!res.ok) return;
    const data = await res.json();

    // 1. Update Network Speed Widget
    if (data.network) {
      const speedEl = document.getElementById('netSpeed');
      if (speedEl) {
        speedEl.innerHTML = '↓ <span style="color: var(--ctp-green);">' + data.network.down + '</span> &bull; ↑ <span style="color: var(--ctp-blue);">' + data.network.up + '</span>';
      }
    }

    // 2. Update Service Health Badges
    if (data.services) {
      for (const [svc, status] of Object.entries(data.services)) {
        const badge = document.querySelector('[data-status-for="' + svc + '"]');
        if (!badge) continue;
        const dot = badge.querySelector('.status-dot');
        const label = badge.querySelector('.status-label');

        if (status === 'online') {
          dot.className = 'status-dot status-online';
          label.textContent = 'Online';
          label.style.color = 'var(--ctp-green)';
        } else {
          dot.className = 'status-dot status-offline';
          label.textContent = 'Offline';
          label.style.color = 'var(--ctp-red)';
        }
      }
    }
  } catch (err) {
    // Silently ignore transient network fetch errors
  }
}
setInterval(updateStats, 2000);
updateStats();

// Instant Live Filter
const searchInput = document.getElementById('search');
const cards = document.querySelectorAll('.card');

if (searchInput) {
  searchInput.addEventListener('input', (e) => {
    const q = e.target.value.toLowerCase().trim();
    cards.forEach(card => {
      const text = card.getAttribute('data-search') || '';
      card.style.display = text.includes(q) ? 'flex' : 'none';
    });
  });

  // Keyboard Shortcut '/'
  window.addEventListener('keydown', (e) => {
    if (e.key === '/' && document.activeElement !== searchInput) {
      e.preventDefault();
      searchInput.focus();
    }
  });
}
