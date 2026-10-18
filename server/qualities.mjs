export async function songQualities(id, session, {call, qqCall}) {
  const qq = String(id).startsWith('qq:');
  if (!(qq ? /^[A-Za-z0-9]{1,30}$/.test(id.slice(3)) : /^\d{1,20}$/.test(id ?? ''))) throw new Error('歌曲编号无效');
  const logged = Boolean(qq ? session.qq?.profile : session.profile && session.uid);
  const levels = [['standard', '标准'], ['higher','高品质 · 320K'], ['lossless','无损 · FLAC']];
  // Resolve each requested format with the actual song and account. Login alone is
  // not evidence of membership, copyright, regional access or an available file.
  const qualities = await Promise.all(levels.map(async ([quality,label]) => {
    if (quality !== 'standard' && !logged) return {id:quality,label,locked:true,reason:'请登录对应音频账号后重新检测'};
    try {
      if (qq) {
        const source = await qqCall('url', {id:id.slice(3),quality}, session.qq);
        if (!source.url) throw new Error('平台未提供此音质');
      } else {
        const {body} = await call('song_url_v1', {id,level:quality === 'higher' ? 'exhigh' : quality,crypto:'eapi'},session);
        const source = body.data?.[0];
        if (!source?.url || quality !== 'standard' && source.freeTrialInfo || quality === 'higher' && Number(source.br) < 320000 || quality === 'lossless' && String(source.type).toLowerCase() !== 'flac') {
          throw new Error(source?.freeTrialInfo ? '平台仅提供试听，请在官方客户端确认会员权限' : '该账号或歌曲未提供此音质');
        }
        if (source.freeTrialInfo) return {id:quality,label:label+' · 试听',locked:false,reason:'平台只提供试听片段'};
      }
      return {id:quality,label,locked:false,reason:'已验证当前歌曲播放地址'};
    } catch(e) {return {id:quality,label,locked:true,reason:e.message || '检测失败，请刷新'};}
  }));
  return {qualities,notice:'按当前歌曲与账号实时检测；平台会员、地区及歌曲授权均可能影响音质。刷新会重新请求权限。'};
}
