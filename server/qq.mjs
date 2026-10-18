import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import {qqMobile} from './qq_mobile.mjs';
export function qqCall(op, params = {}, state = {}) {
  if (process.env.VOCALO1NG_ANDROID === '1') return qqMobile(op, params, state);
  const runtime = process.env.VOCASHELF_QQ_PYTHON || path.resolve('.tools', 'qq-runtime', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
  if (!existsSync(runtime)) throw new Error('QQ 音乐运行环境未安装，请运行 tools/setup-qq.ps1');
  return new Promise((resolve, reject) => {
    const child = spawn(runtime, ['-X', 'utf8', 'server/qq_worker.py'], { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let output = '';
    const timer = setTimeout(() => { child.kill(); reject(new Error('QQ 音乐请求超时，请稍后重试')); }, 38000);
    child.stdout.on('data', chunk => { output += chunk; if (output.length > 2000000) child.kill(); });
    child.stderr.on('data', () => {});
    child.on('error', () => { clearTimeout(timer); reject(new Error('QQ 音乐运行环境不可用')); });
    child.on('close', () => { clearTimeout(timer); try { const data = JSON.parse(output); if (data.authExpired) { delete state.credential; delete state.profile; } if (data._refreshedCredential) { state.credential = data._refreshedCredential; delete data._refreshedCredential; } if (data.error) { const error = new Error(data.error); error.status = data.authExpired ? 401 : 502; reject(error); } else resolve(data); } catch { reject(new Error('QQ 音乐未返回有效结果')); } });
    child.stdin.on('error', () => {});
    child.stdin.end(JSON.stringify({ op, ...params, credential: state.credential }));
  });
}
