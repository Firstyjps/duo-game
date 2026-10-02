// static server สำหรับเปิด viewer ที่ใหญ่เกินกว่า preview ของ Claude desktop จะเปิดตรง ๆ ได้ (~2 MB ขึ้นไป)
// ใช้: node game/systems/enemy/common/tools/serve_viewers.js → เปิด http://127.0.0.1:8765/boss_minotaur/tools/minotaur_viewer.html
const http = require('http'), fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..', '..');  // game/systems/enemy
http.createServer((q, r) => {
	const p = path.join(root, decodeURIComponent(q.url.split('?')[0]));
	if (!p.startsWith(root)) { r.writeHead(403); return r.end(); }
	fs.readFile(p, (e, d) => {
		if (e) { r.writeHead(404); return r.end('404'); }
		const type = p.endsWith('.html') ? 'text/html; charset=utf-8' : p.endsWith('.png') ? 'image/png' : 'application/octet-stream';
		r.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
		r.end(d);
	});
}).listen(8765, '127.0.0.1', () => console.log('serving game/systems/enemy on http://127.0.0.1:8765'));
