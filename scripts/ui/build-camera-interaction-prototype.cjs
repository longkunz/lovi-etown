// Throwaway interaction prototype; no product code or upstream requests.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const dir = path.join(root, 'docs/ui/stitch');
let html = fs.readFileSync(path.join(dir, 'camera-interaction-prototype.template.html'), 'utf8');
['5deb576d1dc17d7c5515ad13', '662b7f651afb9c00172dc992', '586e28a0f9fab7001111b0b3'].forEach((id,i) => {
  html = html.replace('__ASSET'+i+'__', 'data:image/jpeg;base64,'+fs.readFileSync(path.join(dir,'assets',id+'.jpg')).toString('base64'));
});
fs.writeFileSync(path.join(dir,'camera-interaction-prototype.html'),html);
console.log('Built docs/ui/stitch/camera-interaction-prototype.html (open directly in browser)');
