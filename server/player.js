/* Native <select> popups are separate OS surfaces and are not reliably captured
 * by the texture-backed Windows WebView. Keep select as the state model while
 * drawing every interactive part inside the captured document. */
(() => {
  let opened;
  for (const select of document.querySelectorAll('select')) {
    const name = select.getAttribute('aria-label') || select.closest('label')?.firstChild?.textContent.trim() || '选择';
    const button = document.createElement('button');
    button.type = 'button'; button.className = 'choice-trigger';
    button.setAttribute('role', 'combobox'); button.setAttribute('aria-label', name);
    button.setAttribute('aria-haspopup', 'listbox'); button.setAttribute('aria-expanded', 'false');
    const menu = document.createElement('div');
    menu.id = `${select.id}-choices`; menu.className = 'choice-menu'; menu.hidden = true;
    menu.setAttribute('role', 'listbox'); menu.setAttribute('aria-label', `${name}选项`);
    button.setAttribute('aria-controls', menu.id);
    select.hidden = true; select.setAttribute('aria-hidden', 'true'); select.tabIndex = -1;
    select.insertAdjacentElement('afterend', button); document.body.append(menu);
    function close() { menu.hidden = true; button.setAttribute('aria-expanded', 'false'); if (opened === close) opened = undefined; }
    function sync() {
      button.disabled = select.disabled;
      button.textContent = select.selectedOptions[0]?.label || '加载中…';
      if (select.disabled) close();
    }
    function open(direction = 1) {
      if (button.disabled) return;
      opened?.(); opened = close;
      const items = [...select.options].map(option => {
        const item = document.createElement('button');
        item.type = 'button'; item.setAttribute('role', 'option');
        item.setAttribute('aria-selected', String(option.selected)); item.disabled = option.disabled;
        item.textContent = `${option.selected ? '✓  ' : ''}${option.label}`;
        item.addEventListener('click', () => {
          const changed = select.value !== option.value;
          select.value = option.value;
          close(); sync(); button.focus();
          if (changed) {
            select.dispatchEvent(new Event('input', {bubbles: true}));
            select.dispatchEvent(new Event('change', {bubbles: true}));
          }
        });
        return item;
      });
      replaceNodes(menu,items); menu.hidden = false;
      const rect = button.getBoundingClientRect();
      menu.style.minWidth = `${Math.min(Math.max(rect.width, 140), innerWidth - 16)}px`;
      const room = Math.max(rect.top, innerHeight - rect.bottom);
      menu.style.maxHeight = `${Math.max(48, Math.min(280, room - 16))}px`;
      const box = menu.getBoundingClientRect();
      menu.style.left = `${Math.max(8, Math.min(rect.left, innerWidth - box.width - 8))}px`;
      const top = innerHeight - rect.bottom >= box.height + 8 ? rect.bottom + 6 : rect.top - box.height - 6;
      menu.style.top = `${Math.max(8, Math.min(top, innerHeight - box.height - 8))}px`;
      button.setAttribute('aria-expanded', 'true');
      const enabled = items.filter(item => !item.disabled);
      (enabled.find(item => item.getAttribute('aria-selected') === 'true') || (direction > 0 ? enabled[0] : enabled[enabled.length - 1]))?.focus();
    }
    button.addEventListener('click', () => menu.hidden ? open() : close());
    button.addEventListener('keydown', event => {
      if (['ArrowDown', 'ArrowUp'].includes(event.key)) {event.preventDefault(); open(event.key === 'ArrowDown' ? 1 : -1);}
      if (event.key === 'Escape') close();
    });
    menu.addEventListener('keydown', event => {
      if (event.key === 'Escape') {event.preventDefault(); close(); button.focus();}
      if (event.key === 'Tab') close();
      if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) return;
      event.preventDefault();
      const items = [...menu.querySelectorAll('button:not(:disabled)')];
      const index = items.indexOf(document.activeElement);
      items[event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1 : (index + (event.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length]?.focus();
    });
    select.addEventListener('change', sync);
    new MutationObserver(sync).observe(select, {childList: true, subtree: true, attributes: true, attributeFilter: ['disabled', 'selected']});
    document.addEventListener('pointerdown', event => {if (!menu.contains(event.target) && !button.contains(event.target)) close();});
    window.addEventListener('resize', close);
    document.addEventListener('scroll', event => {if (!menu.contains(event.target)) close();}, true);
    sync();
  }
})();

/* Bundled locally: no external navigation, provider cookies, or third-party iframe. */
const token = new URLSearchParams(location.search).get('token');
const video = document.querySelector('video');
const quality = document.querySelector('#quality');
const speed = document.querySelector('#speed');
const status = document.querySelector('#status');
const notice = document.querySelector('#notice');
function replaceNodes(parent, children) {
  while(parent.firstChild)parent.removeChild(parent.firstChild);
  for(const child of children)parent.appendChild(child);
}
async function readJson(url, valid = () => true) {
  for (let attempt = 0; attempt < 2; attempt++) {
    if (!valid()) throw new Error('加载已取消');
    const controller = typeof AbortController === 'function' ? new AbortController() : null;
    const timeout = controller ? setTimeout(()=>controller.abort(),25000) : null;
    try {
      const response = await fetch(url, {cache:'no-store', ...(controller ? {signal:controller.signal} : {})});
      const value = await response.json();
      if (!response.ok) {
        const error = new Error(value.error || '服务暂时不可用');
        error.retryable = response.status >= 500 || [408,429].includes(response.status);
        throw error;
      }
      return value;
    } catch (error) {
      if (error.retryable === false || attempt === 1 || !valid()) throw error;
      await new Promise(resolve=>setTimeout(resolve,600));
    } finally { if(timeout!==null)clearTimeout(timeout); }
  }
}
let recoveryCount=0, recoveryTimer, startupTimer, closed=false, lastFailure='';
let playbackIntent={position:0,paused:false};
function ready(){clearTimeout(startupTimer);}
function recover(generation){
  if(closed || generation!==revision || recoveryTimer)return;
  ready();
  if(recoveryCount>=2){notice.textContent='视频暂未加载成功：'+(lastFailure||'媒体连接超时')+'。可切换 PV 版本或点击重试';return;}
  notice.textContent=`正在自动重试播放（${++recoveryCount}/2）…`;
  recoveryTimer=setTimeout(()=>{recoveryTimer=null;if(generation===revision&&!closed)load(currentQuality,false,true);},700*recoveryCount);
}
function watchStartup(generation){ready();startupTimer=setTimeout(()=>{
  if(generation!==revision||closed)return;
  if(compatibility)recover(generation);else loadCompatible(generation,playbackIntent.position,playbackIntent.paused);
},12000);}
function adoptSource(source){
  if(source.bvid && dmBvid!==source.bvid){dmBvid=source.bvid;dmItems=[];dmRetries=0;}
  if(dmBvid && dmToggle.checked && !dmItems.length)loadDanmaku();
}
let player, revision = 0, currentQuality = 80;
let compatibility = false;
async function loadCompatible(generation, position = 0, paused = false) {
  if (generation !== revision || compatibility) return;
  compatibility = true;
  notice.textContent = '正在切换手机兼容播放…';
  try {
    const source = await readJson(`/api/pv/playback?${new URLSearchParams({token,quality:String(currentQuality),mode:'mp4'})}`,()=>generation===revision&&!closed);
    if(generation!==revision) return;
    adoptSource(source);
    player?.reset(); player = undefined;
    currentQuality = source.quality;
    replaceNodes(quality,source.qualities.map(x=>new Option(x.label,String(x.id),true,true)));
    quality.disabled = false;
    video.src = source.url;
    video.addEventListener('loadedmetadata',()=> {
      if(generation!==revision) return;
      ready();
      if(position>0)video.currentTime=Math.min(position,Math.max(0,video.duration-.2));
      video.playbackRate=Number(speed.value);
      status.textContent='手机兼容 MP4 · '+quality.selectedOptions[0]?.textContent;
      notice.textContent='';
      if(!paused)video.play().catch(()=>notice.textContent='点播放键开始观看');
    },{once:true});
    video.load();
    watchStartup(generation);
  } catch(error) { if(generation===revision){lastFailure=error.message;quality.disabled=false;recover(generation);} }
}
async function load(requested = currentQuality, initial = false, automatic = false) {
  const generation = ++revision;
  ready(); clearTimeout(recoveryTimer); recoveryTimer=null;
  if(!automatic)recoveryCount=0;
  const position = automatic ? playbackIntent.position : initial ? 0 : video.currentTime;
  const paused = automatic ? playbackIntent.paused : initial ? false : video.paused;
  playbackIntent={position,paused};
  compatibility = false;
  quality.disabled = true;
  notice.textContent = initial ? '正在加载 PV…' : '正在切换画质…';
  try {
    const source = await readJson(`/api/pv/playback?${new URLSearchParams({ token, quality: String(requested) })}`,()=>generation===revision&&!closed);
    if (generation !== revision) return;
    adoptSource(source);
    if (!window.MediaSource && !window.ManagedMediaSource) { await loadCompatible(generation,position,paused); return; }
    currentQuality = source.quality;
    replaceNodes(quality,source.qualities.map(level => new Option(level.label, String(level.id), false, level.id === source.quality)));
    player?.reset();
    player = dashjs.MediaPlayer().create();
    player.updateSettings({ debug: { logLevel: 0 }, streaming: { abr: { autoSwitchBitrate: { video: false, audio: false } } } });
    player.on(dashjs.MediaPlayer.events.STREAM_INITIALIZED, () => {
      if (generation !== revision) return;
      ready();
      if (position > 0) player.seek(Math.min(position, Math.max(0, player.duration() - 0.2)));
      player.setPlaybackRate(Number(speed.value));
      video.playbackRate = Number(speed.value);
      quality.disabled = false;
      notice.textContent = '';
      status.textContent = `内置播放器 · ${quality.selectedOptions[0]?.textContent ?? ''}`;
      if (!paused) video.play().catch(() => { notice.textContent = '点视频中的播放键开始观看'; });
    });
    player.on(dashjs.MediaPlayer.events.ERROR, () => {
      if (generation !== revision) return;
      loadCompatible(generation,video.currentTime||position,paused);
    });
    player.initialize(video, source.manifest, false);
    watchStartup(generation);
  } catch (error) {
    if (generation !== revision) return;
    lastFailure=error.message;
    quality.disabled = !quality.options.length;
    await loadCompatible(generation,position,paused);
  }
}
quality.addEventListener('change', () => load(Number(quality.value)));
speed.addEventListener('change', () => { player?.setPlaybackRate(Number(speed.value)); video.playbackRate = Number(speed.value); status.textContent = `内置播放器 · ${speed.value}×`; });
document.querySelector('#retry').addEventListener('click', () => {load(); if(dmToggle.checked)loadDanmaku(true);});
document.querySelector('#compatible').addEventListener('click',()=>{ compatibility=false; loadCompatible(++revision,video.currentTime,video.paused); });
video.addEventListener('playing', () => { ready();lastFailure=''; notice.textContent = ''; });
video.addEventListener('timeupdate',()=>{if(!video.error && video.currentTime>0)playbackIntent.position=video.currentTime;});
video.addEventListener('error',()=>{if(closed)return;lastFailure=({1:'媒体加载已中止',2:'视频网络连接失败',3:'系统无法解码此视频',4:'系统不支持此视频格式'})[video.error?.code]||lastFailure;if(compatibility)recover(revision);else loadCompatible(revision,playbackIntent.position,playbackIntent.paused);});
window.addEventListener('pagehide', () => { closed=true;revision++;ready();clearTimeout(recoveryTimer);clearTimeout(dmRetryTimer);player?.reset(); });


const dmCanvas=document.querySelector('#danmaku'),dmContext=dmCanvas.getContext('2d');
const dmToggle=document.querySelector('#dm-toggle'),dmStatus=document.querySelector('#dm-status');
let dmItems=[],dmBvid='',dmLoading=false,dmRetries=0,dmRetryTimer;
const dmControls=['size','opacity','speed','density','area','mono'];
dmToggle.checked=true;
try {const saved=JSON.parse(localStorage.getItem('vocalo1ng.danmaku')||'{}');dmToggle.checked=saved.enabled??true;for(const name of dmControls){const e=document.querySelector('#dm-'+name);if(saved[name]!==undefined){if(e.type==='checkbox')e.checked=saved[name];else e.value=saved[name];}}}catch{}
function saveDm(){const values={enabled:dmToggle.checked};for(const name of dmControls){const e=document.querySelector('#dm-'+name);values[name]=e.type==='checkbox'?e.checked:e.value;}try{localStorage.setItem('vocalo1ng.danmaku',JSON.stringify(values));}catch{}}
async function loadDanmaku(force=false){
  if(!dmBvid||dmLoading||(!force&&dmItems.length))return;
  clearTimeout(dmRetryTimer);
  if(force)dmRetries=0;
  dmLoading=true;const bvid=dmBvid;dmStatus.textContent='正在加载弹幕…';
  try{
    const data=await readJson('/api/pv/danmaku?'+new URLSearchParams({token,bvid}),()=>!closed&&bvid===dmBvid);
    if(bvid!==dmBvid||closed)return;
    dmItems=(data.items||[]).filter(d=>Number.isFinite(d.time)).sort((a,b)=>a.time-b.time);
    dmStatus.textContent=dmItems.length?dmItems.length+' 条':'此视频暂无弹幕';
  }catch(e){if(!closed && bvid===dmBvid){dmStatus.textContent=e.message;if(dmRetries++<1)dmRetryTimer=setTimeout(()=>{if(!closed&&dmToggle.checked&&bvid===dmBvid)loadDanmaku();},1500);}}
  finally{dmLoading=false;if(!closed&&bvid!==dmBvid&&dmToggle.checked)loadDanmaku();}
}
document.querySelector('#dm-retry').addEventListener('click',()=>loadDanmaku(true));
dmToggle.addEventListener('change',()=>{saveDm();if(dmToggle.checked)loadDanmaku();});for(const name of dmControls)document.querySelector('#dm-'+name).addEventListener('input',saveDm);
function drawDanmaku(){const box=dmCanvas.getBoundingClientRect(),ratio=devicePixelRatio||1;if(dmCanvas.width!==Math.round(box.width*ratio)||dmCanvas.height!==Math.round(box.height*ratio)){dmCanvas.width=Math.round(box.width*ratio);dmCanvas.height=Math.round(box.height*ratio);}dmContext.setTransform(ratio,0,0,ratio,0,0);dmContext.clearRect(0,0,box.width,box.height);
if(dmToggle.checked&&dmItems.length){const size=Number(document.querySelector('#dm-size').value),duration=Number(document.querySelector('#dm-speed').value),density=Number(document.querySelector('#dm-density').value),area=Number(document.querySelector('#dm-area').value),mono=document.querySelector('#dm-mono').checked;dmContext.font='600 '+size+'px sans-serif';dmContext.globalAlpha=Number(document.querySelector('#dm-opacity').value)/100;const lanes=Math.max(1,Math.floor((box.height-40)*area/(size+8)));let n=0;const visibleCount=dmItems.filter(d=>video.currentTime-d.time>=0&&video.currentTime-d.time<=duration).length;const stride=Math.max(1,Math.ceil(visibleCount/(density*4)));
for(let i=0;i<dmItems.length;i++){const d=dmItems[i],age=video.currentTime-d.time;if(age<0)break;if(age>duration||i%stride!==0)continue;if(++n>60)break;const width=dmContext.measureText(d.text).width;const x=box.width-(box.width+width)*age/duration;const y=(i%lanes+1)*(size+6);dmContext.lineWidth=3;dmContext.strokeStyle='#000b';dmContext.strokeText(d.text,x,y);dmContext.fillStyle=mono?'#fff':'#'+(d.color||16777215).toString(16).padStart(6,'0');dmContext.fillText(d.text,x,y);}dmContext.globalAlpha=1;}requestAnimationFrame(drawDanmaku);}
requestAnimationFrame(drawDanmaku);load(80,true);

const full=document.createElement('button'); full.textContent='全屏';full.setAttribute('aria-label','视频与弹幕一起全屏');
document.querySelector('footer').append(full);
full.onclick=()=>{const screen=document.querySelector('.screen');if(document.fullscreenElement)document.exitFullscreen();else screen.requestFullscreen?.().catch(()=>{notice.textContent='当前环境不支持全屏';});};
video.setAttribute('controlsList','nofullscreen');
