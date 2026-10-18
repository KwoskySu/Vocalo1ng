const token = new URLSearchParams(location.search).get('token');
const widget = document.querySelector('#widget');
let cover = '';
const time = n => `${Math.floor(n/60)}:${String(Math.floor(n%60)).padStart(2,'0')}`;
async function update() {
  try {
    const r = await fetch('/api/live/state?'+new URLSearchParams({token}), {cache:'no-store'});
    if (!r.ok) throw new Error();
    const s = await r.json();
    widget.hidden = false;
    widget.style.opacity = s.offline || (s.hide && !s.playing) ? '0' : '1';
    if (s.offline) return;
    widget.className = `mode${s.mode} ${s.playing?'':'paused'}`;
    for (const key of ['title','artist','line','translation','next','previous']) document.getElementById(key).textContent = s[key] || '';
    document.querySelector('#translation').hidden = !s.translationVisible;
    if (cover !== s.cover) {cover = s.cover; document.querySelector('#cover').src = cover ? '/api/image?'+new URLSearchParams({url:cover}) : '';}
    widget.style.setProperty('--size',s.size+'px');widget.style.setProperty('--ink',s.color);widget.style.setProperty('--opacity',s.opacity);widget.style.setProperty('--align',s.align);widget.style.fontFamily=s.font;
    document.querySelector('#progress').style.width = Math.min(100,s.duration?s.position/s.duration*100:0)+'%';
    document.querySelector('#time').textContent = `${time(s.position)} / ${time(s.duration)}`;
  } catch {widget.style.opacity='0';}
  finally {setTimeout(update,400);}
}
update();
