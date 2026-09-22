const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const video = path.join(process.env.HOME, '.pub-cache/hosted/pub.dev/video_player-2.14.0/example/assets/Butterfly-209.mp4');
const size = fs.statSync(video).size;
const server = http.createServer((req, res) => {
  if (req.url !== '/video.mp4') { res.writeHead(404); res.end(); return; }
  const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range || '');
  const start = range ? Number(range[1]) : 0;
  const end = range && range[2] ? Math.min(size - 1, Number(range[2])) : size - 1;
  res.writeHead(range ? 206 : 200, {'Content-Type': 'video/mp4', 'Content-Length': end - start + 1,
    'Accept-Ranges': 'bytes', ...(range ? {'Content-Range': `bytes ${start}-${end}/${size}`} : {})});
  fs.createReadStream(video, {start, end}).pipe(res);
});
server.listen(8201, '127.0.0.1', () => console.log('Feed fixture media ready'));
process.on('SIGINT', () => server.close(() => process.exit(0)));
