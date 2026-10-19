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

// Interactive controls are opt-in, so OBS captures remain free of handles.
if (new URLSearchParams(location.search).get('interactive') === '1') {
  document.body.classList.add('interactive');
  const button = document.querySelector('#tools');
  let locked = false, drag = null;
  const key = 'vocalo1ng.live.layout.v1';
  try { const old=JSON.parse(localStorage.getItem(key)); if(old) {
    widget.style.width=Math.min(innerWidth,Math.max(220,old.width))+'px';
    widget.style.height=Math.min(innerHeight,Math.max(100,old.height))+'px';
    widget.style.left=Math.max(0,Math.min(innerWidth-100,old.left))+'px';
    widget.style.top=Math.max(0,Math.min(innerHeight-60,old.top))+'px';
  }} catch {}
  const save=()=>{const r=widget.getBoundingClientRect();try{localStorage.setItem(key,JSON.stringify({width:r.width,height:r.height,left:r.left,top:r.top}));}catch{}};
  button.onclick=()=>{locked=!locked;document.body.classList.toggle('locked',locked);button.textContent=locked?'解锁拖动缩放':'锁定位置';};
  widget.addEventListener('pointerdown',e=>{const r=widget.getBoundingClientRect();if(locked||e.button!==0||(e.clientX>r.right-24&&e.clientY>r.bottom-24))return;
    drag={x:e.clientX-r.left,y:e.clientY-r.top};widget.setPointerCapture(e.pointerId);e.preventDefault();});
  widget.addEventListener('pointermove',e=>{if(!drag)return;widget.style.left=Math.max(0,Math.min(innerWidth-widget.offsetWidth,e.clientX-drag.x))+'px';widget.style.top=Math.max(0,Math.min(innerHeight-widget.offsetHeight,e.clientY-drag.y))+'px';});
  const stop=()=>{drag=null;save();};widget.addEventListener('pointerup',stop);widget.addEventListener('pointercancel',stop);
  if(typeof ResizeObserver!=='undefined')new ResizeObserver(save).observe(widget);
  addEventListener('resize',()=>{const r=widget.getBoundingClientRect();widget.style.left=Math.max(0,Math.min(innerWidth-widget.offsetWidth,r.left))+'px';widget.style.top=Math.max(0,Math.min(innerHeight-widget.offsetHeight,r.top))+'px';});
}
