import { describe, it } from 'node:test';
import assert from 'node:assert';
import { generateKeyPairSync } from 'node:crypto';
import {
  detectAvailabilityChange,
  notificationText,
  topicForCamera,
} from '../../src/notifications/availability.js';
import {
  FcmSender,
  buildServiceAccountJwt,
  loadFcmSenderFromEnv,
} from '../../src/notifications/fcm-sender.js';
import { AvailabilityProber } from '../../src/notifications/availability-prober.js';

const cam = (availability: 'unknown' | 'online' | 'offline' | 'degraded') => ({
  id: '9b7e1a2c-0000-4000-8000-000000000001',
  name: 'Mai Chí Thọ - Lương Định Của',
  availability,
});

describe('Availability transitions (T16)', () => {
  it('online -> offline notifies offline on the camera topic', () => {
    const change = detectAvailabilityChange(cam('online'), 'offline');
    assert.equal(change?.kind, 'offline');
    assert.equal(change?.topic, 'cam_9b7e1a2c-0000-4000-8000-000000000001');
    assert.equal(topicForCamera(cam('online').id), change?.topic);
  });

  it('degraded -> offline also notifies', () => {
    assert.equal(detectAvailabilityChange(cam('degraded'), 'offline')?.kind, 'offline');
  });

  it('offline -> online notifies recovered', () => {
    assert.equal(detectAvailabilityChange(cam('offline'), 'online')?.kind, 'recovered');
  });

  it('unknown -> anything stays silent (no baseline)', () => {
    assert.equal(detectAvailabilityChange(cam('unknown'), 'offline'), null);
    assert.equal(detectAvailabilityChange(cam('unknown'), 'online'), null);
  });

  it('no change -> no event', () => {
    assert.equal(detectAvailabilityChange(cam('online'), 'online'), null);
    assert.equal(detectAvailabilityChange(cam('offline'), 'offline'), null);
  });

  it('notification text uses the camera name', () => {
    const change = detectAvailabilityChange(cam('online'), 'offline')!;
    const { title, body } = notificationText(change);
    assert.equal(title, 'Camera ngoại tuyến');
    assert.equal(body, 'Mai Chí Thọ - Lương Định Của');
  });
});

describe('FcmSender (T16)', () => {
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const account = {
    projectId: 'lovi-test',
    clientEmail: 'prober@lovi-test.iam.gserviceaccount.com',
    privateKey: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
  };

  it('builds an RS256 JWT with the messaging scope', () => {
    const jwt = buildServiceAccountJwt(account, 1_760_000_000);
    const [header, payload, signature] = jwt.split('.');
    assert.ok(header && payload && signature);
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString());
    assert.equal(claims.iss, account.clientEmail);
    assert.match(claims.scope, /firebase\.messaging/);
    assert.equal(claims.exp - claims.iat, 3600);
  });

  it('exchanges the JWT once and sends to the topic with the cached token', async () => {
    const calls: { url: string; body: string; auth?: string }[] = [];
    const fetchFn = async (url: string, init?: { body?: unknown; headers?: Record<string, string> }) => {
      calls.push({
        url,
        body: String(init?.body ?? ''),
        auth: init?.headers?.authorization,
      });
      if (url.includes('oauth2.googleapis.com')) {
        return { ok: true, status: 200, json: async () => ({ access_token: 'tok-1', expires_in: 3600 }) };
      }
      return { ok: true, status: 200, json: async () => ({ name: 'messages/1' }) };
    };
    const sender = new FcmSender({
      account,
      fetchFn: fetchFn as unknown as typeof fetch,
      now: () => 1_760_000_000_000,
    });
    await sender.sendToTopic('cam_x', 'T', 'B', { cameraId: 'x' });
    await sender.sendToTopic('cam_y', 'T2', 'B2');

    const tokenCalls = calls.filter((c) => c.url.includes('oauth2'));
    const sendCalls = calls.filter((c) => c.url.includes('fcm.googleapis.com'));
    assert.equal(tokenCalls.length, 1);
    assert.equal(sendCalls.length, 2);
    assert.equal(sendCalls[0].auth, 'Bearer tok-1');
    assert.equal(
      sendCalls[0].url,
      'https://fcm.googleapis.com/v1/projects/lovi-test/messages:send'
    );
    const sent = JSON.parse(sendCalls[0].body);
    assert.equal(sent.message.topic, 'cam_x');
    assert.equal(sent.message.notification.title, 'T');
    assert.equal(sent.message.data.cameraId, 'x');
  });

  it('loader returns null without a service account, a sender with one', () => {
    assert.equal(loadFcmSenderFromEnv({}), null);
    assert.equal(loadFcmSenderFromEnv({ FCM_SERVICE_ACCOUNT_JSON: 'not json' }), null);
    const sender = loadFcmSenderFromEnv({
      FCM_SERVICE_ACCOUNT_JSON: JSON.stringify({
        project_id: 'p',
        client_email: 'a@b.c',
        private_key: 'k',
      }),
    });
    assert.ok(sender instanceof FcmSender);
  });
});

describe('AvailabilityProber (T16)', () => {
  function fakeRecord(id: string, availability: 'online' | 'offline') {
    return {
      id,
      provider: 'notis',
      providerCameraId: id.replaceAll('-', '').slice(0, 24),
      name: `Cam ${id}`,
      nameNormalized: `cam ${id}`,
      provinceId: 'tp_hcm',
      address: null,
      addressNormalized: null,
      district: null,
      districtNormalized: null,
      location: null,
      capabilities: { snapshot: true, live: false },
      availability,
      checkedAt: null,
      updatedAt: new Date(),
      sourceKind: 'snapshot',
      sourceRef: id.replaceAll('-', '').slice(0, 24),
      streamUrl: null,
    };
  }

  it('persists transitions and notifies offline + recovered exactly once', async () => {
    const records = [fakeRecord('cam-a', 'online'), fakeRecord('cam-b', 'offline')];
    const updates: [string, string][] = [];
    const sent: [string, string][] = [];
    const prober = new AvailabilityProber({
      repository: {
        list: async () => ({ items: records, total: 2, catalog: {} as never }),
        updateAvailability: async (id: string, availability: 'online' | 'offline') => {
          updates.push([id, availability]);
        },
      } as never,
      provider: {
        // cam-a now fails (offline), cam-b now answers (online)
        fetchSnapshot: async (sourceRef: string) => {
          if (sourceRef.startsWith('cama')) throw new Error('timeout');
          return { bytes: new Uint8Array([1]), contentType: 'image/jpeg' } as never;
        },
      },
      sender: {
        sendToTopic: async (topic: string, title: string) => {
          sent.push([topic, title]);
        },
      },
      now: () => new Date('2026-10-20T10:00:00Z'),
    });

    const summary = await prober.runOnce();
    assert.equal(summary.checked, 2);
    assert.equal(summary.online, 1);
    assert.equal(summary.offline, 1);
    assert.equal(summary.changes, 2);
    assert.equal(summary.notified, 2);
    assert.deepEqual(updates.sort(), [['cam-a', 'offline'], ['cam-b', 'online']]);
    assert.deepEqual(sent.sort(), [
      ['cam_cam-a', 'Camera ngoại tuyến'],
      ['cam_cam-b', 'Camera đã trở lại'],
    ]);
  });

  it('without a sender it still tracks state and counts changes', async () => {
    const records = [fakeRecord('cam-a', 'online')];
    const prober = new AvailabilityProber({
      repository: {
        list: async () => ({ items: records, total: 1, catalog: {} as never }),
        updateAvailability: async () => {},
      } as never,
      provider: {
        fetchSnapshot: async () => {
          throw new Error('down');
        },
      },
    });
    const summary = await prober.runOnce();
    assert.equal(summary.changes, 1);
    assert.equal(summary.notified, 0);
  });
});
