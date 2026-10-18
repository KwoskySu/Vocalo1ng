import asyncio, base64, json, os, sys, urllib.request, urllib.parse
from pathlib import Path
for key in list(os.environ):
    if key.lower().endswith('_proxy'): os.environ.pop(key)
urllib.request.getproxies = lambda: {}
from qqmusic_api import Client, Credential, CredentialRefreshError, CredentialExpiredError, LoginAuthExpiredError
from qqmusic_api.models.login import QR, QRLoginType
from qqmusic_api.modules.song import SongFileInfo, SongFileType

def track(song):
    s = song.model_dump()
    album = s.get('album', {})
    return {'id': 'qq:' + s['mid'], 'title': s.get('title') or s.get('name', ''), 'artist': ' / '.join(a['name'] for a in s.get('singer', [])), 'album': album.get('name', ''), 'cover': 'https://y.gtimg.cn/music/photo_new/T002R500x500M000' + album.get('mid', '') + '.jpg' if album.get('mid') else '', 'duration': s.get('interval', 0) * 1000, 'alias': s.get('subtitle', '')}
refreshed = None
async def run(data):
    global refreshed
    Path('.session').mkdir(exist_ok=True)
    async with Client(Credential.model_validate(data.get('credential') or {}), device_path='.session/qq-device.json') as client:
        op = data['op']
        if op not in ('qr', 'check') and client.credential.musicid and client.credential.is_expired():
            refreshed = (await client.login.refresh_credential()).model_dump(by_alias=True)
        if op == 'search':
            result = await client.execute(client.search.search_by_type(data['q'], num=30, page=1+int(data.get('offset', 0))//30))
            return {'songs': [track(s) for s in result.song], 'total': result.total_num}
        if op == 'qr':
            qr = await client.login.get_qrcode(QRLoginType.QQ)
            return {'image': 'data:image/png;base64,' + base64.b64encode(qr.data).decode(), 'identifier': qr.identifier}
        if op == 'check':
            result = await client.login.check_qrcode(QR(b'', QRLoginType.QQ, 'image/png', data['identifier']))
            if not result.done: return {'code': result.event.name}
            client.credential = result.credential
            profile = {'uid': str(result.credential.musicid), 'nickname': 'QQ 音乐用户', 'avatar': ''}
            try:
                info = await client.execute(client.user.get_homepage(result.credential.encrypt_uin))
                profile.update(nickname=info.base_info.name, avatar=info.base_info.avatar)
            except Exception: pass
            return {'code': 'DONE', 'credential': result.credential.model_dump(by_alias=True), 'profile': profile}
        if op == 'url':
            mid = data['id']
            info = await client.execute(client.song.get_detail(mid))
            quality = {'standard': SongFileType.MP3_128, 'higher': SongFileType.MP3_320, 'lossless': SongFileType.FLAC}.get(data.get('quality', 'standard'), SongFileType.MP3_128)
            result = await client.execute(client.song.get_song_urls([SongFileInfo(mid, media_mid=info.track.file.media_mid)], quality))
            item = next((x for x in result.data if x.purl and x.result == 0), None)
            if item is None: raise PermissionError('该账号暂无此歌曲播放权限，请登录 QQ 音乐或选择其他歌曲')
            return {'url': 'https://isure.stream.qqmusic.qq.com/' + item.purl.lstrip('/'), 'preview': False}
        if op == 'comments':
            info = await client.execute(client.song.get_detail(data['id']))
            method = client.comment.get_new_comments if data.get('sort') == 'latest' else client.comment.get_hot_comments
            try:
                result = await client.execute(method(info.track.id, page_num=int(data.get('page', 1)), page_size=30, biz_sub_type=2))
                comments = [{'id': c.cmid, 'author': c.nick, 'avatar': c.avatar, 'text': c.content, 'likes': c.praise_num, 'time': c.pub_time * 1000} for c in result.comments]
                return {'comments': comments, 'total': result.total, 'more': bool(result.has_more), 'source': 'https://y.qq.com/n/ryqq/songDetail/' + data['id']}
            except Exception:
                def legacy():
                    url = 'https://c.y.qq.com/base/fcgi-bin/fcg_global_comment_h5.fcg?' + urllib.parse.urlencode({'g_tk':5381,'biztype':1,'topid':info.track.id,'cmd':8,'pagenum':int(data.get('page',1))-1,'pagesize':30,'format':'json'})
                    request = urllib.request.Request(url, headers={'Referer':'https://y.qq.com/','User-Agent':'Mozilla/5.0'})
                    with urllib.request.urlopen(request, timeout=12) as response: return json.load(response)
                result = await asyncio.to_thread(legacy)
                if result.get('code') != 0: raise PermissionError('QQ 音乐暂未开放评论，请登录后重试或在原平台查看')
                section = result.get('hot_comment' if data.get('sort') != 'latest' else 'comment') or {}
                fallback = not section.get('commentlist') and data.get('sort') != 'latest'
                if fallback: section = result.get('comment', {})
                comments = [{'id': str(c.get('commentid','')), 'author': c.get('nick',''), 'avatar': c.get('avatarurl',''), 'text': c.get('rootcommentcontent',''), 'likes': c.get('praisenum',0), 'time': c.get('time',0)*1000} for c in section.get('commentlist',[])]
                return {'comments':comments,'total':section.get('commenttotal',len(comments)),'more':bool(result.get('morecomment')),'notice':'此歌曲暂无可用热评，展示平台返回的最新评论' if fallback else '', 'source':'https://y.qq.com/n/ryqq/songDetail/'+data['id']}
        if op == 'lyrics':
            result = await client.execute(client.lyric.get_lyric(data['id'], trans=True))
            return {'original': result.lyric, 'translated': result.trans}
        raise ValueError('不支持的 QQ 音乐操作')
async def main():
    try:
        result = await asyncio.wait_for(run(json.load(sys.stdin)), timeout=32)
        if refreshed: result['_refreshedCredential'] = refreshed
        print(json.dumps(result, ensure_ascii=True))
    except (CredentialRefreshError, CredentialExpiredError, LoginAuthExpiredError):
        print(json.dumps({'error': 'QQ 音乐登录已失效，请重新扫码', 'authExpired': True}, ensure_ascii=True))
    except Exception as error:
        print(json.dumps({'error': str(error) if isinstance(error, PermissionError) else 'QQ 音乐服务暂时不可用，请稍后重试'}, ensure_ascii=True))
if __name__ == '__main__':
    if sys.platform == 'win32': asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
    asyncio.run(main())
