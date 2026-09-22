const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const file = path.join(process.env.HOME, '.pub-cache/hosted/pub.dev/video_player-2.14.0/example/assets/Butterfly-209.mp4');
const size = fs.statSync(file).size;
const server = http.createServer((req, res) => {
  if (!['/api/mobile/files/education/catalog/kihon/1/video', '/api/mobile/files/education/works/1'].includes(req.url)) {
    res.writeHead(404); res.end(); return;
  }
  if (req.headers.authorization !== 'Bearer education-native-test') {
    res.writeHead(401); res.end(); return;
  }
  const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range || '');
  const start = range ? Number(range[1]) : 0;
  const end = range && range[2] ? Math.min(size - 1, Number(range[2])) : size - 1;
  if (start > end) { res.writeHead(416); res.end(); return; }
  console.log('Authorized education media', range ? 'range' : 'full');
  res.writeHead(range ? 206 : 200, {
    'Content-Type': 'video/mp4', 'Content-Length': end - start + 1,
    'Cache-Control': 'private, no-store', 'Accept-Ranges': 'bytes',
    ...(range ? {'Content-Range': `bytes ${start}-${end}/${size}`} : {}),
  });
  fs.createReadStream(file, {start, end}).pipe(res);
});
server.listen(8202, '127.0.0.1', () => console.log('Education fixture media ready'));
process.on('SIGINT', () => server.close(() => process.exit(0)));
