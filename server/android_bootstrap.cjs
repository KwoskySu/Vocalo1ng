// Configure the embedded VM from JavaScript before loading any providers.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
process.chdir(root);
process.env.TMPDIR = path.join(root, 'tmp');
process.env.VOCASHELF_SESSION_DIR = path.join(root, 'accounts');
process.env.VOCASHELF_HOST = '127.0.0.1';
process.env.VOCASHELF_PORT = '5418';
process.env.VOCALO1NG_ANDROID = '1';
fs.mkdirSync(process.env.TMPDIR, {recursive:true});
// Some mobile builds return a compiled-in /tmp, which Android apps cannot use.
require('node:os').tmpdir = () => process.env.TMPDIR;
require('node:module').syncBuiltinESMExports();
const images = JSON.parse(fs.readFileSync(path.join(root, 'native-images.json'), 'utf8'));
process.env.VOCALO1NG_NATIVE_IMAGES_PORT = String(images.port);
process.env.VOCALO1NG_NATIVE_IMAGES_TOKEN = images.token;
import('./index.mjs').catch(error => {
  fs.writeFileSync(path.join(root, 'runtime.log'), String(error.stack || error));
  console.error(error);
  process.exitCode = 1;
});
