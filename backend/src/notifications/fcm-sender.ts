import { createSign } from 'node:crypto';

/**
 * Minimal FCM HTTP v1 sender (T16) — no extra dependencies.
 *
 * Auth: service-account JWT bearer flow against oauth2.googleapis.com,
 * signed RS256 with node:crypto; the access token is cached until shortly
 * before expiry. Sending targets a topic the mobile app subscribed to.
 *
 * When no service account is configured the loader returns null and the
 * caller treats notifications as disabled — the trial runs fine without
 * a Firebase project until Long creates one (decision D8).
 */
export interface FcmServiceAccount {
  projectId: string;
  clientEmail: string;
  privateKey: string;
}

export interface FcmSenderOptions {
  account: FcmServiceAccount;
  fetchFn?: typeof fetch;
  now?: () => number;
}

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

function base64Url(input: string | Buffer): string {
  return Buffer.from(input)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

export function buildServiceAccountJwt(
  account: FcmServiceAccount,
  nowSeconds: number
): string {
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64Url(
    JSON.stringify({
      iss: account.clientEmail,
      scope: MESSAGING_SCOPE,
      aud: TOKEN_URL,
      iat: nowSeconds,
      exp: nowSeconds + 3600,
    })
  );
  const unsigned = `${header}.${payload}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  const signature = signer.sign(account.privateKey);
  return `${unsigned}.${base64Url(signature)}`;
}

export class FcmSender {
  private readonly account: FcmServiceAccount;
  private readonly fetchFn: typeof fetch;
  private readonly now: () => number;
  private cachedToken: { value: string; expiresAt: number } | null = null;

  constructor(options: FcmSenderOptions) {
    this.account = options.account;
    this.fetchFn = options.fetchFn ?? fetch;
    this.now = options.now ?? Date.now;
  }

  async accessToken(): Promise<string> {
    const nowMs = this.now();
    if (this.cachedToken && this.cachedToken.expiresAt > nowMs + 60_000) {
      return this.cachedToken.value;
    }
    const assertion = buildServiceAccountJwt(
      this.account,
      Math.floor(nowMs / 1000)
    );
    const response = await this.fetchFn(TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }).toString(),
    });
    if (!response.ok) {
      throw new Error(`FCM token exchange failed: HTTP ${response.status}`);
    }
    const data = (await response.json()) as {
      access_token: string;
      expires_in?: number;
    };
    const ttlMs = (data.expires_in ?? 3600) * 1000;
    this.cachedToken = { value: data.access_token, expiresAt: nowMs + ttlMs };
    return data.access_token;
  }

  async sendToTopic(
    topic: string,
    title: string,
    body: string,
    data?: Record<string, string>
  ): Promise<void> {
    const token = await this.accessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${this.account.projectId}/messages:send`;
    const response = await this.fetchFn(url, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          topic,
          notification: { title, body },
          ...(data ? { data } : {}),
        },
      }),
    });
    if (!response.ok) {
      throw new Error(`FCM send failed: HTTP ${response.status}`);
    }
  }
}

/**
 * Builds a sender from `FCM_SERVICE_ACCOUNT_JSON` (the raw service-account
 * JSON as a single env value). Returns null when unset or malformed —
 * notifications are simply disabled in that deployment.
 */
export function loadFcmSenderFromEnv(
  env: NodeJS.ProcessEnv
): FcmSender | null {
  const raw = env.FCM_SERVICE_ACCOUNT_JSON;
  if (!raw || !raw.trim()) return null;
  try {
    const parsed = JSON.parse(raw) as {
      project_id?: string;
      client_email?: string;
      private_key?: string;
    };
    if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
      return null;
    }
    return new FcmSender({
      account: {
        projectId: parsed.project_id,
        clientEmail: parsed.client_email,
        privateKey: parsed.private_key,
      },
    });
  } catch {
    return null;
  }
}
