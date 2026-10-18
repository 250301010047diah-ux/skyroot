// Repeatable renderer sample on the connected debug WebView; restores the run.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs/promises';
const adb = (...args) => execFileSync('adb', args, { encoding: 'utf8' }).trim();
const port = adb('forward', 'tcp:0', `localabstract:webview_devtools_remote_${adb('shell', 'pidof', 'com.example.skyroot')}`);
let ws;
try {
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  ws = new WebSocket(targets.find(t => t.url.includes('/game/')).webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  let id = 0;
  const jobs = new Map();
  ws.onmessage = ({ data }) => {
    const msg = JSON.parse(data), job = jobs.get(msg.id);
    if (job) { jobs.delete(msg.id); msg.error ? job.reject(msg.error) : job.resolve(msg.result); }
  };
  const command = (method, params) => new Promise((resolve, reject) => {
    const key = ++id; jobs.set(key, { resolve, reject });
    ws.send(JSON.stringify({ id: key, method, params }));
  });
  const result = await command('Runtime.evaluate', { awaitPromise: true, returnByValue: true, expression: `
    (async () => {
      const {game,run}=__skyroot,s=game.state;
      if(s.phase!=='play')throw Error('Wait for assets to load');
      const original=game.hooks.render, frozen=run.frozen, time=s.t, cam={...s.cam};
      const proto=CanvasRenderingContext2D.prototype, radial=proto.createRadialGradient, linear=proto.createLinearGradient;
      let gradients=0, frames=0, prior=0;
      const costs=[], intervals=[];
      run.frozen=true;
      proto.createRadialGradient=function(...a){gradients++;return radial.apply(this,a)};
      proto.createLinearGradient=function(...a){gradients++;return linear.apply(this,a)};
      try {
        await new Promise(resolve=>{
          game.hooks.render = state => {
            state.t=frames/60;state.cam.x=cam.x+Math.sin(frames/60)*2;
            const now=performance.now();
            original(state);
            if(frames>=30){costs.push(performance.now()-now);intervals.push(now-prior)}
            if(frames===29)gradients=0;
            prior=now;
            if(++frames===210){game.hooks.render=original;resolve()}
          };
        });
        const stats=xs=>{const sorted=[...xs].sort((a,b)=>a-b);return {mean:xs.reduce((a,b)=>a+b,0)/xs.length,p95:sorted[Math.floor(sorted.length*.95)]}};
        return {area:s.areaIndex,canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height],samples:costs.length,renderMs:stats(costs),frameMs:stats(intervals),gradientsPerFrame:gradients/costs.length};
      } finally {game.hooks.render=original;proto.createRadialGradient=radial;proto.createLinearGradient=linear;run.frozen=frozen;s.t=time;s.cam=cam}
    })()` });
  if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
  console.log(JSON.stringify(result.result.value, null, 2));
  await fs.mkdir('artifacts', { recursive: true });
  await fs.writeFile(`artifacts/performance-${process.argv[2] || 'sample'}.json`, JSON.stringify(result.result.value, null, 2));
} finally { ws?.close(); adb('forward', '--remove', `tcp:${port}`); }
