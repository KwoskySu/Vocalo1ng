import {createHash} from 'node:crypto';
import {biliCookieHeader, biliUserAgent} from './bilibili.mjs';

const permutation=[46,47,18,2,53,8,23,32,15,50,10,31,58,3,45,35,27,43,5,49,33,9,42,19,29,28,14,39,12,38,41,13,37,48,7,16,24,55,40,61,26,17,0,1,60,51,30,4,22,25,54,21,56,59,6,63,57,62,11,36,20,34,44,52];
const keys = new WeakMap();
export function signCommentQuery(params, key, now=Date.now()) {
  const values={...params,wts:String(Math.floor(now/1000))};
  const query=Object.keys(values).sort().map(k=>`${encodeURIComponent(k)}=${encodeURIComponent(String(values[k]).replace(/[!'()*]/g,''))}`).join('&');
  return query+'&w_rid='+createHash('md5').update(query+key).digest('hex');
}

export async function pagedBiliComments(info, bvid, order, cursor, cookies, fetcher=fetch) {
  if (cursor.length>2048 || /[\x00-\x1f]/.test(cursor)) throw new Error('评论游标无效');
  const headers={'User-Agent':biliUserAgent,Referer:`https://www.bilibili.com/video/${bvid}`,
    ...(biliCookieHeader(cookies)?{Cookie:biliCookieHeader(cookies)}:{})};
  const json=async path=>{
    const response=await fetcher('https://api.bilibili.com'+path,{headers,signal:AbortSignal.timeout(10000),redirect:'error'});
    if(!response.ok)throw new Error(`B站评论请求失败（HTTP ${response.status}）`);
    return response.json();
  };
  let key=keys.get(fetcher);
  if(!key || key.expires<Date.now()) {
    const nav=await json('/x/web-interface/nav');
    const imageKey=value=>{
      if(typeof value!=='string') throw new Error('评论签名参数暂不可用');
      const url=new URL(value);
      const match=url.pathname.match(/\/([a-f0-9]{32})\./);
      if(url.protocol!=='https:' || !url.hostname.endsWith('.hdslb.com') || !match) throw new Error('评论签名参数暂不可用');
      return match[1];
    };
    const raw=imageKey(nav.data?.wbi_img?.img_url)+imageKey(nav.data?.wbi_img?.sub_url);
    key={value:permutation.map(i=>raw[i]).join('').slice(0,32),expires:Date.now()+300000};
    keys.set(fetcher,key);
  }
  const query=signCommentQuery({oid:String(info.aid),type:'1',mode:order==='hot'?'3':'2',
    pagination_str:JSON.stringify({offset:cursor}),plat:'1',web_location:'1315875'},key.value);
  const result=await json('/x/v2/reply/wbi/main?'+query);
  if(result.code!==0) {
    if(result.code===-403) keys.delete(fetcher);
    if([-352,-412].includes(result.code)) throw new Error(`B站暂时限制评论读取（${result.code}），请稍后刷新`);
    throw new Error(`B站评论暂不可用（${result.code}）`);
  }
  if(!result.data || typeof result.data!=='object') throw new Error('评论数据暂不可用');
  return result.data;
}
