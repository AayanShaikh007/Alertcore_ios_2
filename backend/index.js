const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const apn = require('apn');

const PORT = Number(process.env.PORT || 8080);
const FIRMWARE_BASE_URL = (process.env.FIRMWARE_BASE_URL || '').replace(/\/$/, '');
const APNS_TEAM_ID = process.env.APNS_TEAM_ID || '';
const APNS_KEY_ID = process.env.APNS_KEY_ID || '';
const APNS_KEY_PATH = process.env.APNS_KEY_PATH || '';
const APNS_TOPIC = process.env.APNS_TOPIC || '';
const APNS_PRODUCTION = String(process.env.APNS_PRODUCTION || 'false').toLowerCase() === 'true';
const ALERT_REPEAT_INTERVAL_MS = Number(process.env.ALERT_REPEAT_INTERVAL_MS || 15000);
const ALERT_BURST_COUNT = Number(process.env.ALERT_BURST_COUNT || 3);
const POLL_INTERVAL_MS = Number(process.env.POLL_INTERVAL_MS || 1000);

const DATA_DIR = path.join(__dirname, 'data');
const DEVICES_FILE = path.join(DATA_DIR, 'devices.json');

let devices = [];
let provider = null;
let lastAlertFingerprint = null;

function log(message, extra) {
  const prefix = '[AlertCore backend]';
  if (extra !== undefined) {
    console.log(prefix, message, extra);
  } else {
    console.log(prefix, message);
  }
}

async function ensureDataDirectory() {
  await fs.mkdir(DATA_DIR, { recursive: true });
}

async function loadDevices() {
  await ensureDataDirectory();
  try {
    const raw = await fs.readFile(DEVICES_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    devices = Array.isArray(parsed.devices) ? parsed.devices : [];
  } catch (error) {
    devices = [];
  }
}

async function saveDevices() {
  await ensureDataDirectory();
  await fs.writeFile(DEVICES_FILE, JSON.stringify({ devices }, null, 2));
}

function createProvider() {
  if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_KEY_PATH || !APNS_TOPIC) {
    log('APNs provider is not configured yet. Set APNS_TEAM_ID, APNS_KEY_ID, APNS_KEY_PATH, and APNS_TOPIC.');
    return null;
  }

  return new apn.Provider({
    token: {
      key: APNS_KEY_PATH,
      keyId: APNS_KEY_ID,
      teamId: APNS_TEAM_ID,
    },
    production: APNS_PRODUCTION,
  });
}

function normalizeToken(token) {
  return String(token || '').replace(/\s+/g, '').toLowerCase();
}

function makeFingerprint(status) {
  return [
    status.alertTransition ? 'alert' : 'no-alert',
    status.manualTransition ? 'manual' : 'no-manual',
    status.objectPresent ? 'present' : 'clear',
    status.distanceCm ?? 'na',
    status.timestampMs ?? 'na',
  ].join(':');
}

function alertMessageForStatus(status) {
  if (status.manualTransition) {
    return 'Manual trigger pressed';
  }

  if (status.objectPresent) {
    return `Object entered threshold at ${status.distanceCm} cm`;
  }

  return 'Object exited threshold range';
}

function alertTitleForBurst(index, count) {
  if (index === 0) {
    return 'AlertCore Alert';
  }

  return `AlertCore Alert (${index + 1}/${count})`;
}

async function sendPushToDevice(deviceToken, title, body) {
  if (!provider || !APNS_TOPIC) {
    return;
  }

  const notification = new apn.Notification();
  notification.topic = APNS_TOPIC;
  notification.pushType = 'alert';
  notification.priority = 10;
  notification.sound = 'AlertCoreTone.wav';
  notification.title = title;
  notification.body = body;
  notification.badge = 1;
  notification.threadId = 'alertcore-alert';
  notification.expiry = Math.floor(Date.now() / 1000) + 3600;

  try {
    const result = await provider.send(notification, deviceToken);
    if (result.failed && result.failed.length > 0) {
      for (const failure of result.failed) {
        log(`APNs failure for device token ${deviceToken.slice(0, 12)}...`, failure); 
      }
    }
  } catch (error) {
    log('APNs send error', error);
  }
}

async function sendBurst(status, burstIndex, burstCount) {
  const body = alertMessageForStatus(status);
  const title = alertTitleForBurst(burstIndex, burstCount);
  const tokens = [...new Set(devices.map((device) => normalizeToken(device.deviceToken)).filter(Boolean))];

  if (tokens.length === 0) {
    log('No registered APNs device tokens yet.');
    return;
  }

  log(`Sending burst ${burstIndex + 1}/${burstCount} to ${tokens.length} device(s)`);
  await Promise.all(tokens.map((token) => sendPushToDevice(token, title, body)));
}

function scheduleAlertBurst(status) {
  const burstCount = Math.max(1, ALERT_BURST_COUNT);
  const fingerprint = makeFingerprint(status);

  if (fingerprint === lastAlertFingerprint) {
    return;
  }

  lastAlertFingerprint = fingerprint;

  for (let burstIndex = 0; burstIndex < burstCount; burstIndex++) {
    const delayMs = burstIndex * ALERT_REPEAT_INTERVAL_MS;
    setTimeout(() => {
      sendBurst(status, burstIndex, burstCount).catch((error) => log('Burst send failed', error));
    }, delayMs);
  }
}

async function fetchJson(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Request failed with HTTP ${response.status}`);
  }
  return await response.json();
}

async function pollFirmware() {
  if (!FIRMWARE_BASE_URL) {
    return;
  }

  try {
    const status = await fetchJson(`${FIRMWARE_BASE_URL}/api/status`);
    if (status.alertTransition || status.manualTransition) {
      scheduleAlertBurst(status);
    }

    if (!status.objectPresent) {
      lastAlertFingerprint = null;
    }
  } catch (error) {
    log('Firmware poll failed', error.message || error);
  }
}

async function handleRegisterDevice(request, response) {
  const body = await readRequestBody(request);
  const deviceToken = normalizeToken(body.deviceToken);

  if (!deviceToken) {
    return sendJson(response, 400, { ok: false, error: 'deviceToken is required' });
  }

  const existingIndex = devices.findIndex((device) => device.deviceToken === deviceToken);
  const record = {
    deviceToken,
    platform: body.platform || 'ios',
    bundleId: body.bundleId || APNS_TOPIC,
    displayName: body.displayName || 'iPhone',
    updatedAt: new Date().toISOString(),
  };

  if (existingIndex >= 0) {
    devices[existingIndex] = record;
  } else {
    devices.push(record);
  }

  await saveDevices();
  log('Registered device token', deviceToken.slice(0, 12) + '...');
  sendJson(response, 200, { ok: true, deviceCount: devices.length });
}

async function handleListDevices(response) {
  sendJson(response, 200, { ok: true, devices });
}

async function handleHealth(response) {
  sendJson(response, 200, {
    ok: true,
    firmwareConfigured: Boolean(FIRMWARE_BASE_URL),
    apnsConfigured: Boolean(provider && APNS_TOPIC),
    deviceCount: devices.length,
  });
}

async function readRequestBody(request) {
  const chunks = [];
  for await (const chunk of request) {
    chunks.push(Buffer.from(chunk));
  }

  if (chunks.length === 0) {
    return {};
  }

  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch (error) {
    return {};
  }
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'Content-Type': 'application/json' });
  response.end(JSON.stringify(payload, null, 2));
}

async function main() {
  await loadDevices();
  provider = createProvider();

  if (FIRMWARE_BASE_URL) {
    setInterval(() => {
      pollFirmware().catch((error) => log('Poll loop error', error));
    }, POLL_INTERVAL_MS);
    log(`Polling firmware at ${FIRMWARE_BASE_URL}/api/status every ${POLL_INTERVAL_MS}ms`);
  } else {
    log('FIRMWARE_BASE_URL is not configured yet.');
  }

  const server = http.createServer(async (request, response) => {
    try {
      if (request.method === 'GET' && request.url === '/api/health') {
        return await handleHealth(response);
      }

      if (request.method === 'GET' && request.url === '/api/devices') {
        return await handleListDevices(response);
      }

      if (request.method === 'POST' && request.url === '/api/devices/register') {
        return await handleRegisterDevice(request, response);
      }

      response.writeHead(404, { 'Content-Type': 'application/json' });
      response.end(JSON.stringify({ ok: false, error: 'Not found' }));
    } catch (error) {
      log('Request handling error', error);
      sendJson(response, 500, { ok: false, error: 'Internal server error' });
    }
  });

  server.listen(PORT, () => {
    log(`Listening on http://0.0.0.0:${PORT}`);
  });
}

main().catch((error) => {
  console.error('[AlertCore backend] fatal', error);
  process.exit(1);
});
