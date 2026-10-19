import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function exportCameras() {
  console.log('Đang kết nối tới API Notis để tải toàn bộ danh sách camera TP.HCM...');

  // Bounding box bao phủ toàn bộ TP.HCM và các vùng giáp ranh
  const url = 'https://api.notis.vn/v4/cameras/bybbox?lat1=11.20&lng1=106.35&lat2=10.35&lng2=107.05';
  
  const response = await fetch(url, {
    method: 'GET',
    headers: {
      accept: 'application/json',
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
    signal: AbortSignal.timeout(15000),
  });

  if (!response.ok) {
    throw new Error(`Tải dữ liệu thất bại, HTTP status: ${response.status}`);
  }

  const rawCameras = await response.json();
  if (!Array.isArray(rawCameras)) {
    throw new Error('Dữ liệu trả về không phải là mảng danh sách camera hợp lệ.');
  }

  console.log(`Đã tải thành công ${rawCameras.length} camera từ máy chủ.`);

  // Chuẩn hóa và sắp xếp theo Quận/Huyện, sau đó theo Tên
  const formattedCameras = rawCameras.map((cam) => {
    const lng = Array.isArray(cam.loc?.coordinates) ? cam.loc.coordinates[0] : null;
    const lat = Array.isArray(cam.loc?.coordinates) ? cam.loc.coordinates[1] : null;

    return {
      mongoId: cam._id,
      code: cam.id || '',
      name: cam.name || '',
      district: cam.dist || 'Chưa phân loại',
      latitude: lat,
      longitude: lng,
      angle: cam.angle ?? null,
      ptz: Boolean(cam.ptz),
      snapshotUrl: `https://api.notis.vn/v4/cameras/${cam._id}/snapshot`,
      streamingUrl: cam.values?.streamingUrl || null,
    };
  });

  formattedCameras.sort((a, b) => {
    const distComp = (a.district || '').localeCompare(b.district || '', 'vi');
    if (distComp !== 0) return distComp;
    return (a.name || '').localeCompare(b.name || '', 'vi');
  });

  // Tạo thư mục data nếu chưa có
  const outDir = path.resolve(__dirname, '..', 'data');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  // 1. Xuất file JSON
  const jsonPath = path.join(outDir, 'cameras_tphcm.json');
  fs.writeFileSync(jsonPath, JSON.stringify(formattedCameras, null, 2), 'utf8');
  console.log(`[XUẤT THÀNH CÔNG] File JSON: ${jsonPath}`);

  // 2. Xuất file CSV (kèm UTF-8 BOM để Excel hiển thị đúng dấu tiếng Việt)
  const csvHeaders = [
    'STT',
    'Mã Camera',
    'Tên Camera (Vị trí)',
    'Quận/Huyện',
    'Vĩ độ (Lat)',
    'Kinh độ (Lng)',
    'Góc quay',
    'PTZ',
    'URL Snapshot',
    'URL Video Stream',
    'MongoDB ID',
  ];

  function escapeCsv(val) {
    if (val === null || val === undefined) return '""';
    const str = String(val).replace(/"/g, '""');
    return `"${str}"`;
  }

  const csvRows = [csvHeaders.map(escapeCsv).join(',')];

  formattedCameras.forEach((cam, idx) => {
    const row = [
      idx + 1,
      escapeCsv(cam.code),
      escapeCsv(cam.name),
      escapeCsv(cam.district),
      cam.latitude !== null ? cam.latitude : '',
      cam.longitude !== null ? cam.longitude : '',
      cam.angle !== null ? cam.angle : '',
      cam.ptz ? 'Có' : 'Không',
      escapeCsv(cam.snapshotUrl),
      escapeCsv(cam.streamingUrl),
      escapeCsv(cam.mongoId),
    ];
    csvRows.push(row.join(','));
  });

  const csvPath = path.join(outDir, 'cameras_tphcm.csv');
  // '\uFEFF' là UTF-8 BOM
  fs.writeFileSync(csvPath, '\uFEFF' + csvRows.join('\r\n'), 'utf8');
  console.log(`[XUẤT THÀNH CÔNG] File CSV:  ${csvPath}`);

  // Thống kê theo Quận/Huyện
  const districtCounts = {};
  let withStreamCount = 0;
  for (const cam of formattedCameras) {
    districtCounts[cam.district] = (districtCounts[cam.district] || 0) + 1;
    if (cam.streamingUrl) withStreamCount++;
  }

  console.log('\n--- THỐNG KÊ CAMERA THEO ĐỊA BÀN ---');
  for (const [dist, count] of Object.entries(districtCounts)) {
    console.log(` - ${dist.padEnd(20)}: ${count} camera`);
  }
  console.log('-----------------------------------');
  console.log(`Tổng số camera: ${formattedCameras.length}`);
  console.log(`Số camera có video stream: ${withStreamCount}`);
}

exportCameras().catch((err) => {
  console.error('[LỖI XUẤT DỮ LIỆU]:', err);
  process.exit(1);
});
