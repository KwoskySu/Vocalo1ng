// SPDX-License-Identifier: GPL-3.0-or-later
// Protocol adaptation based on qqmusic-api-python 0.8.2, Luren and contributors.
// Upstream: https://github.com/l-1124/QQMusicApi ; see licenses/QQMusicApi-GPL-3.0.txt.
// On-device adapter: no Python executable, remote gateway, or third-party proxy.
// Uses the same QQ QR/OAuth and public music API as the desktop provider.
import {randomUUID} from 'node:crypto';
const agent = 'Mozilla/5.0';
const hash33 = (value, seed = 0) => { for (const c of value) seed = (seed * 33 + c.charCodeAt(0)) >>> 0; return seed & 0x7fffffff; };
function cookies(response) {
  const lines = response.headers.getSetCookie?.() ?? (response.headers.get('set-cookie') ?? '').split(/,(?=\s*[^;,=]+=[^;,]*)/);
  return Object.fromEntries(lines.map(x => x.split(';')[0].trim()).filter(x => x.includes('=')).map(x => [x.slice(0,x.indexOf('=')),x.slice(x.indexOf('=')+1)]));
}
const cookieString = jar => Object.entries(jar).map(([k,v])=>`${k}=${v}`).join('; ');
async function http(url, options = {}) {
  const response = await fetch(url, {...options, headers: {'User-Agent': agent, Referer:'https://y.qq.com/', ...options.headers}, signal: AbortSignal.timeout(18000)});
  if (!response.ok && response.status !== 302) throw new Error(`QQ 音乐请求失败（${response.status}），请刷新重试`);
  return response;
}
async function cgi(module, method, param, credential = {}, extra = {}) {
  const uin = String(credential.str_musicid || credential.musicid || '0');
  const data = {comm:{ct:24,cv:0,format:'json',uin,qq:uin,authst:credential.musickey || '',tmeLoginType:credential.loginType ?? credential.login_type ?? 2, ...extra}, req:{module,method,param}};
  const response = await http('https://u.y.qq.com/cgi-bin/musicu.fcg', {method:'POST',headers:{'Content-Type':'application/json', Cookie:cookieString({uin,qqmusic_uin:uin,qm_keyst:credential.musickey||'',qqmusic_key:credential.musickey||''})},body:JSON.stringify(data)});
  const json = await response.json();
  const part = json.req;
  if (json.code || !part || part.code) throw new Error(`QQ 音乐暂不可用（${part?.code ?? json.code}），请刷新或检查账号权限`);
  return part.data;
}
function track(s) {
  const album = s.album || {};
  return {id:'qq:'+s.mid,title:s.title||s.name,artist:(s.singer||[]).map(x=>x.name).join(' / '),album:album.name||'',cover:album.mid?`https://y.gtimg.cn/music/photo_new/T002R500x500M000${album.mid}.jpg`:'',duration:(s.interval||0)*1000,alias:s.subtitle||''};
}
async function detail(mid, credential) { return (await cgi('music.pf_song_detail_svr','get_song_detail_yqq',{song_mid:mid},credential)).track_info; }
export async function qqMobile(op, params = {}, state = {}) {
  const credential = state.credential || {};
  if (op === 'qr') {
    const query = new URLSearchParams({appid:'716027609',e:'2',l:'M',s:'3',d:'72',v:'4',t:String(Math.random()),daid:'383',pt_3rd_aid:'100497308'});
    const response = await http(`https://ssl.ptlogin2.qq.com/ptqrshow?${query}`, {headers:{Referer:'https://xui.ptlogin2.qq.com/'}});
    const identifier = cookies(response).qrsig;
    if (!identifier) throw new Error('QQ 登录二维码未生成，请刷新');
    return {identifier,image:'data:image/png;base64,'+Buffer.from(await response.arrayBuffer()).toString('base64')};
  }
  if (op === 'check') {
    const query = new URLSearchParams({u1:'https://graph.qq.com/oauth2.0/login_jump',ptqrtoken:String(hash33(params.identifier)),ptredirect:'0',h:'1',t:'1',g:'1',from_ui:'1',ptlang:'2052',action:`0-0-${Date.now()}`,js_ver:'20102616',js_type:'1',pt_uistyle:'40',aid:'716027609',daid:'383',pt_3rd_aid:'100497308',has_onekey:'1'});
    const response = await http(`https://ssl.ptlogin2.qq.com/ptqrlogin?${query}`,{headers:{Cookie:`qrsig=${params.identifier}`,Referer:'https://xui.ptlogin2.qq.com/'}});
    const args = [...(await response.text()).matchAll(/'((?:\\.|[^'])*)'/g)].map(x=>x[1]);
    const code = {'0':'DONE','65':'TIMEOUT','66':'SCAN','67':'CONF','68':'REFUSE'}[args[0]];
    if (!code) throw new Error('QQ 登录状态无法解析，请刷新二维码');
    if (code !== 'DONE') return {code};
    const jump = new URL(args[2]);
    const sig = new URLSearchParams({uin:jump.searchParams.get('uin'),ptsigx:jump.searchParams.get('ptsigx'),pttype:'1',service:'ptqrlogin',nodirect:'0',s_url:'https://graph.qq.com/oauth2.0/login_jump',ptlang:'2052',ptredirect:'100',aid:'716027609',daid:'383',j_later:'0',low_login_hour:'0',regmaster:'0',pt_login_type:'3',pt_aid:'0',pt_aaid:'16',pt_light:'0',pt_3rd_aid:'100497308'});
    const signed = await http(`https://ssl.ptlogin2.graph.qq.com/check_sig?${sig}`,{redirect:'manual',headers:{Referer:'https://xui.ptlogin2.qq.com/'}});
    const jar = cookies(signed);
    if (!jar.p_skey) throw new Error('QQ 授权未完成，请重新扫码');
    const form = new URLSearchParams({response_type:'code',client_id:'100497308',redirect_uri:'https://y.qq.com/portal/wx_redirect.html?login_type=1&surl=https://y.qq.com/',scope:'get_user_info,get_app_friends',state:'state',switch:'',from_ptlogin:'1',src:'1',update_auth:'1',openapi:'1010_1030',g_tk:String(hash33(jar.p_skey,5381)),auth_time:String(Date.now()),ui:randomUUID()});
    const authorized = await http('https://graph.qq.com/oauth2.0/authorize',{method:'POST',redirect:'manual',headers:{Cookie:cookieString(jar),'Content-Type':'application/x-www-form-urlencoded'},body:form});
    const location = authorized.headers.get('location');
    const authCode = location && new URL(location).searchParams.get('code');
    if (!authCode) throw new Error('QQ 音乐尚未授权，请重新确认登录');
    const result = await cgi('QQConnectLogin.LoginServer','QQLogin',{code:authCode},{},{tmeLoginType:2});
    const login = {...result, musicid:result.musicid ?? result.musicId, musickey:result.musickey ?? result.musicKey};
    if (!login.musicid || !login.musickey) throw new Error('QQ 音乐未返回有效登录凭据');
    return {code:'DONE',credential:login,profile:{uid:String(login.musicid),nickname:args[5]||'QQ 音乐用户',avatar:`https://q1.qlogo.cn/g?b=qq&nk=${jump.searchParams.get('uin')}&s=100`}};
  }
  if (op === 'search') {
    const data = await cgi('music.search.SearchCgiService','DoSearchForQQMusicDesktop',{search_type:0,query:params.q,num_per_page:30,page_num:1+Math.floor((params.offset||0)/30)},credential);
    let songs = data.body?.song?.list || data.song?.list || (Array.isArray(data.song) ? data.song : []);
    let total = data.meta?.sum || data.total_num || 0;
    if (!songs.length) {
      const query = new URLSearchParams({w:params.q,format:'json',n:'30',p:String(1+Math.floor((params.offset||0)/30))});
      const legacy = await (await http(`https://c.y.qq.com/soso/fcgi-bin/client_search_cp?${query}`)).json();
      if (legacy.code) throw new Error('QQ 音乐搜索暂不可用，请刷新');
      songs = (legacy.data?.song?.list || []).map(s=>({...s,mid:s.songmid,title:s.songname,album:{mid:s.albummid,name:s.albumname}}));
      total = legacy.data?.song?.totalnum || songs.length;
    }
    return {songs:songs.map(track),total};
  }
  if (op === 'lyrics') {
    const query = new URLSearchParams({songmid:params.id,format:'json',nobase64:'1',g_tk:'5381'});
    const data = await (await http(`https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?${query}`)).json();
    if (data.retcode && data.retcode !== 0) throw new Error('QQ 音乐歌词暂不可用');
    return {original:data.lyric||'',translated:data.trans||''};
  }
  if (op === 'url') {
    const song = await detail(params.id, credential);
    const file = {standard:['M500','.mp3'],higher:['M800','.mp3'],lossless:['F000','.flac']}[params.quality||'standard'];
    const media = song?.file?.media_mid;
    const data = await cgi('vkey.GetVkeyServer','CgiGetVkey',{guid:'10000',uin:String(credential.musicid||'0'),songmid:[params.id],songtype:[0],filename:[`${file[0]}${media||params.id+params.id}${file[1]}`],loginflag:credential.musicid?1:0,platform:'20'},credential);
    const item = data.midurlinfo?.find(x=>x.purl);
    if (!item) throw new Error('该账号暂无此歌曲音质权限，请在 QQ 音乐确认授权');
    return {url:new URL(item.purl,data.sip?.find(x=>x.startsWith('https:'))||'https://isure.stream.qqmusic.qq.com/').href,preview:false};
  }
  if (op === 'comments') {
    const song = await detail(params.id,credential);
    const query = new URLSearchParams({g_tk:'5381',biztype:'1',topid:String(song.id),cmd:'8',pagenum:String((params.page||1)-1),pagesize:'30',format:'json'});
    const data = await (await http(`https://c.y.qq.com/base/fcgi-bin/fcg_global_comment_h5.fcg?${query}`)).json();
    if (data.code) throw new Error('QQ 音乐评论暂不可用');
    const section = (params.sort === 'latest'?data.comment:data.hot_comment) || data.comment || {};
    return {comments:(section.commentlist||[]).map(c=>({id:String(c.commentid),author:c.nick,avatar:c.avatarurl,text:c.rootcommentcontent,likes:c.praisenum||0,time:(c.time||0)*1000})),total:section.commenttotal||0,more:Boolean(data.morecomment),source:`https://y.qq.com/n/ryqq/songDetail/${params.id}`};
  }
  throw new Error('不支持的 QQ 音乐操作');
}
