import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const root = path.resolve(__dirname, '../..');
const outDir = path.join(root, 'docs/ui/liquid-glass-refresh');
const stitchDir = path.join(root, 'docs/ui/stitch');

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

const asset0 = 'data:image/jpeg;base64,' + fs.readFileSync(path.join(stitchDir, 'assets/586e28a0f9fab7001111b0b3.jpg')).toString('base64');
const asset1 = 'data:image/jpeg;base64,' + fs.readFileSync(path.join(stitchDir, 'assets/662b7f651afb9c00172dc992.jpg')).toString('base64');
const asset2 = 'data:image/jpeg;base64,' + fs.readFileSync(path.join(stitchDir, 'assets/5deb576d1dc17d7c5515ad13.jpg')).toString('base64');

// Map SVG placeholder
const mapSvg = `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="358" height="200" viewBox="0 0 358 200"><rect width="358" height="200" fill="%23dce4e8"/><path d="M0 60 Q 90 90, 180 70 T 358 100" stroke="%23ffffff" stroke-width="14" fill="none"/><path d="M0 60 Q 90 90, 180 70 T 358 100" stroke="%2343a047" stroke-width="4" fill="none"/><path d="M120 0 L 140 200" stroke="%23ffffff" stroke-width="12" fill="none"/><path d="M120 0 L 140 200" stroke="%23e53935" stroke-width="4" fill="none"/><path d="M260 0 L 220 200" stroke="%23ffffff" stroke-width="10" fill="none"/><path d="M260 0 L 220 200" stroke="%23fdd835" stroke-width="4" fill="none"/><circle cx="160" cy="80" r="14" fill="%2300796B" stroke="%23ffffff" stroke-width="3"/><circle cx="160" cy="80" r="5" fill="%23ffffff"/><text x="180" y="85" font-family="system-ui" font-size="11" font-weight="bold" fill="%23172b35">Camera 11B NBK</text><text x="8" y="192" font-family="system-ui" font-size="9" fill="%23555555">Google Maps • Dữ liệu giao thông thử nghiệm</text></svg>`;

const mapSvgDark = `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="358" height="200" viewBox="0 0 358 200"><rect width="358" height="200" fill="%231a2630"/><path d="M0 60 Q 90 90, 180 70 T 358 100" stroke="%232c3e50" stroke-width="14" fill="none"/><path d="M0 60 Q 90 90, 180 70 T 358 100" stroke="%234caf50" stroke-width="4" fill="none"/><path d="M120 0 L 140 200" stroke="%232c3e50" stroke-width="12" fill="none"/><path d="M120 0 L 140 200" stroke="%23ef5350" stroke-width="4" fill="none"/><path d="M260 0 L 220 200" stroke="%232c3e50" stroke-width="10" fill="none"/><path d="M260 0 L 220 200" stroke="%23ffeb3b" stroke-width="4" fill="none"/><circle cx="160" cy="80" r="14" fill="%23004D40" stroke="%234db6ac" stroke-width="3"/><circle cx="160" cy="80" r="5" fill="%234db6ac"/><text x="180" y="85" font-family="system-ui" font-size="11" font-weight="bold" fill="%23ffffff">Camera 11B NBK</text><text x="8" y="192" font-family="system-ui" font-size="9" fill="%23888888">Google Maps • Dữ liệu giao thông thử nghiệm</text></svg>`;

function getHtml({ mode = 'light', scenario = 'catalog', landscape = false, opaque = false }) {
  const isDark = mode === 'dark';
  const bg = isDark ? '#0f171d' : '#f0f4f7';
  const fg = isDark ? '#e6f0f5' : '#14232c';
  const sub = isDark ? '#8ea3af' : '#576c78';
  const cardBg = opaque
    ? (isDark ? '#192630' : '#ffffff')
    : (isDark ? 'rgba(25, 38, 48, 0.85)' : 'rgba(255, 255, 255, 0.92)');
  const glassBg = opaque
    ? (isDark ? '#1e2f3d' : '#ffffff')
    : (isDark ? 'rgba(30, 52, 66, 0.72)' : 'rgba(255, 255, 255, 0.78)');
  const glassBorder = opaque
    ? (isDark ? '#3d5668' : '#bac9d2')
    : (isDark ? 'rgba(162, 220, 232, 0.22)' : 'rgba(255, 255, 255, 0.85)');
  const glassBlur = opaque ? 'none' : 'blur(16px) saturate(180%)';
  const accent = isDark ? '#4db6ac' : '#00796b';
  const starGold = '#f59e0b';
  const width = landscape ? 844 : 390;
  const height = landscape ? 390 : 844;

  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  width: ${width}px;
  height: ${height}px;
  overflow: hidden;
  background: ${bg};
  color: ${fg};
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  position: relative;
  -webkit-font-smoothing: antialiased;
}

/* Glass styles */
.glass-header {
  position: sticky;
  top: 0;
  left: 0;
  right: 0;
  z-index: 10;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border-bottom: 1px solid ${glassBorder};
  padding: 16px 16px 12px;
  box-shadow: 0 4px 20px rgba(0,0,0, ${isDark ? '0.3' : '0.04'});
}
.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}
.header-title {
  font-size: 20px;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 8px;
  color: ${fg};
}
.badge-teal {
  font-size: 11px;
  font-weight: 600;
  background: ${accent}22;
  color: ${accent};
  padding: 3px 8px;
  border-radius: 12px;
  border: 1px solid ${accent}44;
}

/* Search bar & Picker */
.search-container {
  display: flex;
  gap: 8px;
  position: relative;
}
.glass-search {
  flex: 1;
  display: flex;
  align-items: center;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  border-radius: 24px;
  padding: 0 14px;
  height: 48px;
  font-size: 14px;
  color: ${fg};
  box-shadow: inset 0 1px 1px rgba(255,255,255, ${isDark ? '0.05' : '0.6'});
}
.glass-search input {
  background: transparent;
  border: none;
  outline: none;
  color: ${fg};
  font-size: 14px;
  width: 100%;
  margin-left: 8px;
}
.district-button {
  height: 48px;
  padding: 0 16px;
  border-radius: 24px;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  color: ${accent};
  font-weight: 600;
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
}

/* District Dropdown Popover */
.popover-menu {
  position: absolute;
  top: 56px;
  right: 0;
  width: 220px;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  border-radius: 16px;
  box-shadow: 0 12px 32px rgba(0,0,0, ${isDark ? '0.5' : '0.15'});
  padding: 6px;
  z-index: 50;
}
.popover-item {
  padding: 10px 14px;
  font-size: 13px;
  border-radius: 10px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  cursor: pointer;
}
.popover-item.active {
  background: ${accent}26;
  color: ${accent};
  font-weight: 600;
}

/* Controls row */
.controls-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 16px;
}
.segmented-control {
  display: flex;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  border-radius: 24px;
  padding: 3px;
  height: 42px;
  align-items: center;
}
.segment-btn {
  padding: 6px 14px;
  font-size: 13px;
  font-weight: 500;
  border-radius: 20px;
  border: none;
  background: transparent;
  color: ${sub};
  cursor: pointer;
}
.segment-btn.active {
  background: ${accent};
  color: #ffffff;
  font-weight: 600;
  box-shadow: 0 2px 6px rgba(0,0,0,0.15);
}
.star-filter-btn {
  height: 42px;
  padding: 0 14px;
  border-radius: 22px;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  font-size: 13px;
  display: flex;
  align-items: center;
  gap: 6px;
  color: ${fg};
}

/* Scroll Feed */
.feed {
  padding: 4px 16px 80px;
  overflow-y: auto;
  height: calc(${height}px - 140px);
}
.section-header {
  font-size: 16px;
  font-weight: 700;
  margin: 14px 0 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: ${fg};
}
.grid-2col {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin-bottom: 20px;
}
.camera-card {
  background: ${cardBg};
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid ${glassBorder};
  position: relative;
  box-shadow: 0 2px 10px rgba(0,0,0, ${isDark ? '0.2' : '0.04'});
}
.camera-media {
  width: 100%;
  aspect-ratio: 16/10;
  object-fit: cover;
  display: block;
}
.camera-meta {
  padding: 10px 12px;
}
.camera-name {
  font-size: 13px;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: ${fg};
}
.camera-district {
  font-size: 11px;
  color: ${sub};
  margin-top: 2px;
}
.glass-star-fab {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 48px;
  height: 48px;
  border-radius: 24px;
  background: ${opaque ? (isDark ? '#1e2f3d' : '#ffffff') : 'rgba(0, 0, 0, 0.45)'};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${opaque ? (isDark ? '#3d5668' : '#bac9d2') : 'rgba(255, 255, 255, 0.4)'};
  display: flex;
  align-items: center;
  justify-content: center;
  color: ${starGold};
  font-size: 22px;
  cursor: pointer;
}

/* Bottom Sheet Overlay */
.sheet-scrim {
  position: absolute;
  inset: 0;
  background: rgba(0,0,0,0.5);
  backdrop-filter: blur(2px);
  z-index: 100;
}
.sheet-container {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  max-height: 85%;
  background: ${bg};
  border-radius: 24px 24px 0 0;
  overflow: hidden;
  box-shadow: 0 -8px 40px rgba(0,0,0,0.3);
  display: flex;
  flex-direction: column;
}
.sheet-header-glass {
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border-bottom: 1px solid ${glassBorder};
  padding: 10px 16px 14px;
}
.sheet-handle {
  width: 40px;
  height: 5px;
  background: ${sub}66;
  border-radius: 3px;
  margin: 0 auto 10px;
}
.sheet-title-bar {
  display: flex;
  align-items: center;
  gap: 12px;
}
.icon-btn-glass {
  width: 48px;
  height: 48px;
  border-radius: 24px;
  background: ${opaque ? (isDark ? '#263b4c' : '#ffffff') : 'rgba(255, 255, 255, 0.15)'};
  border: 1px solid ${glassBorder};
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  cursor: pointer;
  color: ${fg};
}
.sheet-title-wrap {
  flex: 1;
}
.sheet-title-wrap h3 {
  font-size: 16px;
  font-weight: 700;
  color: ${fg};
}
.sheet-title-wrap p {
  font-size: 12px;
  color: ${sub};
}
.sheet-content {
  padding: 16px;
  overflow-y: auto;
}
.sheet-media-box {
  width: 100%;
  aspect-ratio: 16/9;
  border-radius: 16px;
  overflow: hidden;
  background: #000;
  position: relative;
  margin-bottom: 12px;
}
.sheet-media-box img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.live-badge {
  position: absolute;
  top: 10px;
  left: 10px;
  background: #e53935;
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  padding: 4px 8px;
  border-radius: 8px;
}
.map-card-box {
  border-radius: 16px;
  overflow: hidden;
  border: 1px solid ${glassBorder};
  position: relative;
  margin-top: 10px;
}
.map-card-box img {
  width: 100%;
  height: 180px;
  object-fit: cover;
  display: block;
}
.map-controls-overlay {
  position: absolute;
  top: 8px;
  right: 8px;
  display: flex;
  gap: 6px;
}
.map-btn-glass {
  width: 48px;
  height: 48px;
  border-radius: 24px;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  color: ${fg};
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
}

/* Fullscreen Viewer */
.viewer-dark-container {
  width: 100%;
  height: 100%;
  background: #060a0d;
  position: relative;
  display: flex;
  flex-direction: column;
}
.viewer-top-bar {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  z-index: 20;
  padding: 16px 20px;
  background: ${opaque ? '#101a22' : 'rgba(10, 18, 24, 0.75)'};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border-bottom: 1px solid rgba(255,255,255,0.15);
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.viewer-image-stage {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}
.viewer-image-stage img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  border-radius: 12px;
}
.viewer-bottom-bar {
  position: absolute;
  bottom: 16px;
  left: 50%;
  transform: translateX(-50%);
  background: ${opaque ? '#101a22' : 'rgba(10, 18, 24, 0.8)'};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid rgba(255,255,255,0.18);
  border-radius: 28px;
  padding: 6px 16px;
  color: #fff;
  font-size: 12px;
}

/* Map Fullscreen */
.map-fullscreen-container {
  width: 100%;
  height: 100%;
  position: relative;
}
.map-bg-fill {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.map-fs-top {
  position: absolute;
  top: 16px;
  left: 16px;
  right: 16px;
  height: 56px;
  border-radius: 28px;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  box-shadow: 0 4px 18px rgba(0,0,0,0.15);
}
.map-fs-bottom-bar {
  position: absolute;
  bottom: 24px;
  left: 16px;
  right: 16px;
  height: 56px;
  border-radius: 28px;
  background: ${glassBg};
  backdrop-filter: ${glassBlur};
  -webkit-backdrop-filter: ${glassBlur};
  border: 1px solid ${glassBorder};
  display: flex;
  align-items: center;
  justify-content: space-around;
  padding: 0 10px;
  box-shadow: 0 6px 24px rgba(0,0,0,0.2);
}
.map-action-pill {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  font-weight: 600;
  color: ${fg};
  padding: 8px 12px;
  border-radius: 20px;
}
.map-action-pill.active {
  background: ${accent}26;
  color: ${accent};
}
</style>
</head>
<body>
`;
}

function renderCatalog({ mode = 'light', showDropdown = false, opaque = false }) {
  const isDark = mode === 'dark';
  let body = getHtml({ mode, scenario: 'catalog', opaque });
  body += `
  <div class="glass-header">
    <div class="header-row">
      <div class="header-title">
        <span>◉</span> Camera TP.HCM
        <span class="badge-teal">Liquid Glass</span>
      </div>
      <div class="icon-btn-glass" title="Lưới nhiều camera">⊞</div>
    </div>
    <div class="search-container">
      <div class="glass-search">
        <span>🔍</span>
        <input type="text" placeholder="Tìm tên đường, giao lộ..." value="${showDropdown ? 'Nguyễn Bỉnh Khiêm' : ''}" readonly>
        ${showDropdown ? '<span style="font-size:16px;color:#888;">✕</span>' : ''}
      </div>
      <div class="district-button">
        <span>Trung tâm</span>
        <span>▾</span>
      </div>
      ${showDropdown ? `
      <div class="popover-menu">
        <div class="popover-item active"><span>Tất cả TP.HCM</span><span>✓</span></div>
        <div class="popover-item"><span>Quận 1 (Trung tâm)</span></div>
        <div class="popover-item"><span>Quận 3</span></div>
        <div class="popover-item"><span>TP. Thủ Đức (Linh Trung)</span></div>
        <div class="popover-item"><span>Bình Thạnh</span></div>
      </div>
      ` : ''}
    </div>
  </div>

  <div class="controls-row">
    <div class="segmented-control">
      <button class="segment-btn">Card</button>
      <button class="segment-btn active">Grid</button>
      <button class="segment-btn">List</button>
    </div>
    <div class="star-filter-btn">
      <span style="color:#f59e0b">★</span>
      <span>Chỉ quan tâm (2)</span>
    </div>
  </div>

  <div class="feed">
    <div class="section-header">
      <span>★ Camera Quan tâm</span>
      <span style="font-size:13px;color:${isDark ? '#4db6ac' : '#00796b'}">Thu gọn ⌃</span>
    </div>
    <div class="grid-2col">
      <div class="camera-card">
        <img class="camera-media" src="${asset1}">
        <div class="glass-star-fab">★</div>
        <div class="camera-meta">
          <div class="camera-name">11B Nguyễn Bỉnh Khiêm</div>
          <div class="camera-district">Quận 1 • 12s trước</div>
        </div>
      </div>
      <div class="camera-card">
        <img class="camera-media" src="${asset0}">
        <div class="glass-star-fab">★</div>
        <div class="camera-meta">
          <div class="camera-name">Pasteur – Lê Thánh Tôn</div>
          <div class="camera-district">Quận 1 • 8s trước</div>
        </div>
      </div>
    </div>

    <div class="section-header">
      <span>Tất cả camera (24)</span>
    </div>
    <div class="grid-2col">
      <div class="camera-card">
        <img class="camera-media" src="${asset2}">
        <div class="glass-star-fab" style="color:rgba(255,255,255,0.7)">☆</div>
        <div class="camera-meta">
          <div class="camera-name">QL1 – KCX Linh Trung</div>
          <div class="camera-district">TP. Thủ Đức • 15s trước</div>
        </div>
      </div>
      <div class="camera-card">
        <img class="camera-media" src="${asset1}">
        <div class="glass-star-fab">★</div>
        <div class="camera-meta">
          <div class="camera-name">11B Nguyễn Bỉnh Khiêm</div>
          <div class="camera-district">Quận 1 • 12s trước</div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>`;
  return body;
}

function renderSheet({ mode = 'light', opaque = false }) {
  const isDark = mode === 'dark';
  let body = getHtml({ mode, scenario: 'sheet', opaque });
  const mapUrl = isDark ? mapSvgDark : mapSvg;
  body += `
  <!-- Background feed simulated -->
  <div class="feed" style="opacity: 0.35; filter: blur(2px);">
    <div class="grid-2col" style="margin-top: 40px;">
      <div class="camera-card"><img class="camera-media" src="${asset1}"></div>
      <div class="camera-card"><img class="camera-media" src="${asset0}"></div>
    </div>
  </div>

  <div class="sheet-scrim">
    <div class="sheet-container">
      <div class="sheet-header-glass">
        <div class="sheet-handle"></div>
        <div class="sheet-title-bar">
          <div class="icon-btn-glass">✕</div>
          <div class="sheet-title-wrap">
            <h3>11B Nguyễn Bỉnh Khiêm</h3>
            <p>Quận 1, TP.HCM • Cập nhật 12 giây trước</p>
          </div>
          <div class="icon-btn-glass" style="color:#f59e0b">★</div>
        </div>
      </div>
      <div class="sheet-content">
        <div class="sheet-media-box">
          <img src="${asset1}">
          <div class="live-badge">TRỰC TIẾP (LIVE)</div>
        </div>
        <div style="display:flex; justify-content:space-between; align-items:center; margin: 8px 0 12px;">
          <span style="font-size:13px; font-weight:600;">Bản đồ & Tình trạng kẹt xe</span>
          <span style="font-size:12px; color:${isDark ? '#4db6ac' : '#00796b'}">Chỉ đường →</span>
        </div>
        <div class="map-card-box">
          <img src="${mapUrl}">
          <div class="map-controls-overlay">
            <div class="map-btn-glass" title="Bật/tắt Traffic" style="color:#4caf50">🚦</div>
            <div class="map-btn-glass" title="Về tâm">◎</div>
            <div class="map-btn-glass" title="Toàn màn hình">⛶</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>`;
  return body;
}

function renderViewer({ landscape = false, opaque = false }) {
  let body = getHtml({ mode: 'dark', landscape, opaque });
  body += `
  <div class="viewer-dark-container">
    <div class="viewer-top-bar">
      <div class="icon-btn-glass">✕</div>
      <div style="text-align:center;">
        <h4 style="font-size:15px; font-weight:700; color:#fff;">11B Nguyễn Bỉnh Khiêm</h4>
        <span style="font-size:11px; color:#8ea3af;">Quận 1 • Snapshot HD</span>
      </div>
      <div class="icon-btn-glass" style="color:#f59e0b;">★</div>
    </div>
    <div class="viewer-image-stage">
      <img src="${asset1}">
    </div>
    <div class="viewer-bottom-bar">
      <span>Chụm 2 ngón hoặc nhấp đôi để phóng to 1x–5x</span>
    </div>
  </div>
</body>
</html>`;
  return body;
}

function renderMapFullscreen({ mode = 'light', opaque = false }) {
  const isDark = mode === 'dark';
  let body = getHtml({ mode, opaque });
  const mapUrl = isDark ? mapSvgDark : mapSvg;
  body += `
  <div class="map-fullscreen-container">
    <img class="map-bg-fill" src="${mapUrl}">
    <div class="map-fs-top">
      <div class="icon-btn-glass" style="width:40px;height:40px;">←</div>
      <div style="font-weight:700; font-size:15px;">11B Nguyễn Bỉnh Khiêm</div>
      <div class="icon-btn-glass" style="width:40px;height:40px; color:#f59e0b">★</div>
    </div>
    <div class="map-fs-bottom-bar">
      <div class="map-action-pill active">
        <span>🚦</span> <span>Giao thông ON</span>
      </div>
      <div class="map-action-pill">
        <span>🗺️</span> <span>Vệ tinh</span>
      </div>
      <div class="map-action-pill">
        <span>◎</span> <span>Về tâm</span>
      </div>
      <div class="map-action-pill" style="color:${isDark ? '#4db6ac' : '#00796b'}">
        <span>↗</span> <span>Chỉ đường</span>
      </div>
    </div>
  </div>
</body>
</html>`;
  return body;
}

const configs = [
  { file: 'catalog-grid-light.png', html: renderCatalog({ mode: 'light' }), w: 390, h: 844 },
  { file: 'catalog-grid-dark.png', html: renderCatalog({ mode: 'dark' }), w: 390, h: 844 },
  { file: 'dropdown-open-light.png', html: renderCatalog({ mode: 'light', showDropdown: true }), w: 390, h: 844 },
  { file: 'dropdown-open-dark.png', html: renderCatalog({ mode: 'dark', showDropdown: true }), w: 390, h: 844 },
  { file: 'sheet-snapshot-map-light.png', html: renderSheet({ mode: 'light' }), w: 390, h: 844 },
  { file: 'sheet-snapshot-map-dark.png', html: renderSheet({ mode: 'dark' }), w: 390, h: 844 },
  { file: 'viewer-portrait-dark.png', html: renderViewer({ landscape: false }), w: 390, h: 844 },
  { file: 'viewer-landscape-dark.png', html: renderViewer({ landscape: true }), w: 844, h: 390 },
  { file: 'map-fullscreen-light.png', html: renderMapFullscreen({ mode: 'light' }), w: 390, h: 844 },
  { file: 'map-fullscreen-dark.png', html: renderMapFullscreen({ mode: 'dark' }), w: 390, h: 844 },
  { file: 'opaque-fallback-light.png', html: renderCatalog({ mode: 'light', opaque: true }), w: 390, h: 844 },
  { file: 'opaque-fallback-dark.png', html: renderCatalog({ mode: 'dark', opaque: true }), w: 390, h: 844 },
];

console.log('Generating mockup PNGs...');
for (const item of configs) {
  const tempHtml = path.join(outDir, `_temp_${item.file.replace('.png', '.html')}`);
  const targetPng = path.join(outDir, item.file);
  fs.writeFileSync(tempHtml, item.html, 'utf8');
  execFileSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
    '--headless', `--screenshot=${targetPng}`, `--window-size=${item.w},${item.h}`,
    `file://${tempHtml}`,
  ], { stdio: 'pipe' });
  fs.unlinkSync(tempHtml);
  console.log(`Rendered: ${item.file} (${item.w}x${item.h})`);
}
console.log('All mockups generated successfully!');
