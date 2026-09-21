'use strict';
const fs = require('fs');
const path = require('path');

function required(env, name) {
  if (!env[name]) throw new Error('缺少发行说明参数: ' + name);
  return env[name];
}

function ipv4(ip) {
  if (!/^\d{1,3}(?:\.\d{1,3}){3}$/.test(ip)) throw new Error('管理地址不是 IPv4: ' + ip);
  const parts = ip.split('.').map(Number);
  if (parts.some(n => n > 255)) throw new Error('管理地址无效: ' + ip);
  return parts;
}

function networkFromLan(ip) {
  const parts = ipv4(ip);
  const subnet = parts[0] + '.' + parts[1] + '.' + parts[2] + '.0/24';
  return { address: ip, gateway: ip, subnet };
}

function parseManifest(text) {
  const names = [];
  for (const line of text.split(/\r?\n/)) {
    const name = line.trim().split(/\s+/)[0];
    if (name) names.push(name);
  }
  return names;
}

function collect(names, prefix) {
  return [...new Set(names.filter(name => name.startsWith(prefix)))].sort();
}

function beijingTime(now) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now).map(part => [part.type, part.value]));
  return parts.year + '年' + parts.month + '月' + parts.day + '日 ' + parts.hour + ':' + parts.minute + ':' + parts.second + '（北京时间）';
}

function yesNo(value, yes = '已集成', no = '未集成') {
  return value === 'yes' || value === 'true' ? yes : no;
}

function findManifest(directory) {
  const files = fs.readdirSync(directory).filter(name => name.endsWith('.manifest'));
  if (files.length !== 1) {
    throw new Error('固件 manifest 缺失或数量异常: ' + directory + ' -> ' + files.join(','));
  }
  return path.join(directory, files[0]);
}

function describe(env = process.env, now = new Date()) {
  const directory = required(env, 'TARGET_DIR');
  const profile = required(env, 'PROFILE');
  const lan = required(env, 'CUSTOM_ROUTER_IP');
  const network = networkFromLan(lan);
  const names = parseManifest(fs.readFileSync(findManifest(directory), 'utf8'));
  const apps = collect(names, 'luci-app-');
  const themes = collect(names, 'luci-theme-');
  const body = [
    '编译时间：' + beijingTime(now),
    '',
    '| 项目 | 内容 |',
    '|---|---|',
    '| 网段 | `' + network.subnet + '` |',
    '| 默认管理地址 | `' + network.address + '` |',
    '| 默认网关 | `' + network.gateway + '` |',
    '| 编译配置 | `' + profile + '` |',
    '| ImageBuilder | `' + (env.BUILD_TAG || '未知') + '` |',
    '| LuCI 版本 | `' + (env.LUCI_EDITION || '未知') + '` |',
    '| Docker | ' + yesNo(env.INCLUDE_DOCKER) + ' |',
    '| iStore | ' + yesNo(env.ENABLE_STORE) + ' |',
    '| 在线升级通道 | `' + (env.UPDATE_TAG || '未发布') + '` |',
    '',
    '**已编入固件的 LuCI 插件（' + apps.length + ' 项）**',
    '',
    ...(apps.length ? apps.map(name => '- `' + name + '`') : ['未编入 LuCI 插件。']),
    '',
    '**主题（' + themes.length + ' 项）**',
    '',
    ...(themes.length ? themes.map(name => '- `' + name + '`') : ['未编入 LuCI 主题。']),
    '',
    '用户名 `root`，密码：无。默认定时升级关闭，可在「系统 → AutoUpdate」打开；SSH 可用 `AutoUpdate` 检测、`AutoUpdate -u` 保留配置升级。',
    '',
  ].join('\n');
  return {
    body,
    subnet: network.subnet,
    dailyTitle: profile + ' · ' + network.subnet,
    autoTitle: 'AutoUpdate-' + (env.TARGET_BOARD || 'device') + ' · ' + network.subnet + ' · ' + profile,
  };
}

function selfTest() {
  const dir = fs.mkdtempSync(path.join(require('os').tmpdir(), 'ib-release-'));
  fs.writeFileSync(path.join(dir, 'demo.manifest'), [
    'luci-app-autoreboot - 1',
    'luci-app-firewall - 1',
    'luci-app-nikki - 1',
    'luci-theme-argon - 1',
    'luci-theme-kucat - 1',
    'wget-ssl - 1',
    '',
  ].join('\n'));
  const result = describe({
    TARGET_DIR: dir,
    PROFILE: 'jcg_q30-ubootmod',
    CUSTOM_ROUTER_IP: '192.168.99.1',
    BUILD_TAG: 'mediatek-filogic-openwrt-24.10.6',
    LUCI_EDITION: '24.10',
    INCLUDE_DOCKER: 'no',
    ENABLE_STORE: 'false',
    UPDATE_TAG: 'Update-mediatek-jcg_q30-ubootmod',
    TARGET_BOARD: 'mediatek',
  }, new Date('2026-09-20T13:27:17Z'));
  const checks = [
    result.body.includes('编译时间：2026年09月20日 21:27:17（北京时间）'),
    result.body.includes('| 网段 | `192.168.99.0/24` |'),
    result.body.includes('| 默认管理地址 | `192.168.99.1` |'),
    result.body.includes('| 默认网关 | `192.168.99.1` |'),
    result.body.includes('| 编译配置 | `jcg_q30-ubootmod` |'),
    result.body.includes('| ImageBuilder | `mediatek-filogic-openwrt-24.10.6` |'),
    result.body.includes('**已编入固件的 LuCI 插件（3 项）**'),
    result.body.includes('- `luci-app-nikki`'),
    result.body.includes('**主题（2 项）**'),
    result.body.includes('- `luci-theme-kucat`'),
  ];
  fs.rmSync(dir, { recursive: true, force: true });
  if (checks.some(ok => !ok)) {
    console.error(result.body);
    throw new Error('发行说明自检失败');
  }
  console.log('SELF_TEST_OK');
}

if (require.main === module) {
  if (process.argv.includes('--self-test')) {
    selfTest();
  } else {
    const result = describe();
    const out = path.join(required(process.env, 'GITHUB_WORKSPACE'), 'release-body.md');
    fs.writeFileSync(out, result.body, 'utf8');
    if (process.env.GITHUB_ENV) {
      fs.appendFileSync(process.env.GITHUB_ENV, 'RELEASE_NOTES_TITLE=' + result.dailyTitle + '\n');
      fs.appendFileSync(process.env.GITHUB_ENV, 'AUTOUPDATE_RELEASE_TITLE=' + result.autoTitle + '\n');
    }
    console.log('wrote', out);
    console.log(result.body);
  }
}

module.exports = { describe, parseManifest, networkFromLan };
