# Camera Backend A1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for inline execution or superpowers:subagent-driven-development if the user chooses delegation. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Backend riêng thay vai trò catalog của Udrivex, lấy metadata/ảnh public Notis, phục vụ danh sách → tìm/lọc → chi tiết/playback → snapshot/refresh.

**Architecture:** Một NestJS/Fastify application trong `backend/`, PostgreSQL/PostGIS là catalog bền. Provider Notis đồng bộ vào catalog; snapshot fetch theo camera ID, giới hạn tải/coalescing/cache. Fixture chỉ test/demo explicit; Vietmap không là dependency A1.

**Tech Stack:** Node.js 24 LTS, TypeScript 6.0.3 strict, NestJS/Fastify, `pg`, Undici, Zod, OpenAPI, Node built-in test runner, Docker Compose/PostGIS.

**Spec:** [2026-10-14-camera-backend-design.md](../specs/2026-10-14-camera-backend-design.md). Đọc cùng [reverse traceability](../../backend-reverse-traceability.md). Người dùng xác nhận đã xem/đồng ý spec ngày 2026-10-14; plan này chờ review và chọn phương thức thực thi.

## Global Constraints

- Tạo sản phẩm trong `D:/REVERSE_TOOLS/TTGT-Tphcm/backend/`; giữ nguyên APK/evidence/mã dịch ngược. Chưa có Git repository tại workspace; khi bắt đầu thực thi, khởi tạo repository riêng trong `backend/`, không đưa APK vào Git. Nếu đã có repo mới từ người khác thì dùng trạng thái thực tế, không reset/revert.
- Node.js 24 LTS; PostgreSQL 17 + PostGIS; TypeScript strict; source `.ts`, `experimentalDecorators`/`emitDecoratorMetadata`, `module/moduleResolution=Node16`, package type commonjs. Compile tests bằng tsc trước Node test runner để tránh phụ thuộc transpiler decorator metadata.
- App default `CAMERA_PROVIDER_MODE=notis`; `.env.example`/Compose dùng notis; test/demo override fixture rõ ràng. Không Udrivex/app-check hoặc Vietmap key/runtime calls trong A1.
- Province duy nhất `tp_hcm`. List q trim/rỗng=no filter/2–120, district 1–80, limit 1–100/default50, offset 0–10000/default0. Related limit 1–20/default6. Bbox admin `[west,south,east,north]`, finite, range hợp lệ, west<east/south<north.
- Source GET Notis `https://api.notis.vn/v4/`; snapshot ID 24 hex. Không gửi credentials mặc định, không nhận URL từ client, không kết nối `values.ip`, không follow redirect. Secret optional từ env, không copy token app.
- Snapshot ≤2 MiB, tổng cache ≤32 MiB, TTL=3000 ms, timeout=5000 ms, 4 fetch active +32 queued; queue đầy →503 BUSY. Refresh descriptor default12000 ms, cấu hình được; không server polling loop per camera.
- Catalog stale default86400000 ms; fetchedAt catalog khác capturedAt ảnh. CapturedAt unknown=null. Source lỗi không xóa catalog, không đổi sang fixture; upsert giữ UUID và không tự xóa ID vắng.
- A1 supported playback chỉ snapshot; live=false. HLS/EVUP/YouTube source classification không tự mở playback; unsupported →422. Favorites local client dựa domain ID ổn định.
- JSON body ≤64 KiB; auth nội bộ X-Api-Key; admin key riêng. Health public, docs và API bảo vệ. Bind localhost mặc định; Docker API bind0.0.0.0 trong container, host publish127.0.0.1:3000.
- Rate limit120 request/phút theo credential+IP; không trust forwarded headers mặc định. Log route template/status/duration/requestId/provider code; bỏ key/cookie/auth/full URL/query/coords/body.
- Chỉ local implementation/verification; không deploy, mua dịch vụ, live relay/transcode, mobile app, weather/VIP/alerts trong A1. Roadmap của chúng vẫn giữ.

## Review Focus

1. Search tiếng Việt có `đ`, dấu tổ hợp, địa chỉ/district/location null và tên trùng: tìm đúng, không mất camera vì thiếu tọa độ — Task2/4.
2. Import lỗi giữa chừng, hai sync cùng lúc, DB restart: giữ catalog/version/UUID, không công bố version nửa transaction hoặc trả fixture thay dữ liệu thật — Task2/3.
3. Nhiều client cùng camera, một client disconnect, đổi camera nhanh: không hủy fetch của người còn chờ hoặc trả bytes camera A cho B — Task5.
4. Upstream chunked thiếu Content-Length, HTML200, ảnh quá lớn, timeout hoặc redirect: giới hạn bytes/thời gian, mapping lỗi không lộ URL/secret — Task3/5.
5. Cache hết TTL nhưng If-None-Match khớp, budget queue/cache đầy: phải revalidate nguồn sau TTL, cache có giới hạn và status/fetchedAt trung thực — Task5/6.

## Preflight đã đọc, không phải kiểm thử sản phẩm

2026-10-14: Node v24.19.0, npm12.0.2, Docker server29.8.0 hoạt động; chưa cài package, chưa tạo backend/container hay chạy test sản phẩm. Registry npm được đọc để chọn cùng major Nest: core/common/platform-fastify/testing12.1.3; swagger12.0.2; fastify5.12.7; pg8.23.1; undici8.12.1; zod4.6.7; dotenv18.0.7; reflect-metadata0.2.2; rxjs7.8.2; @types/node24.19.2; @types/pg8.23.1. Chọn TypeScript6.0.3 vì swagger peer hiện nhận ^5.5|^6, không chọn latest7.0.2. Pin exact phiên bản và package-lock khi triển khai; kiểm tra metadata peer thực tế nếu registry thay đổi.

Nguồn API kỹ thuật: [Nest testing](https://docs.nestjs.com/fundamentals/testing), [node-postgres parameterized queries](https://node-postgres.com/features/queries), [PostGIS MakePoint](https://postgis.net/docs/ST_MakePoint.html). Số version từ registry, không suy từ app reverse.

## File Structure

Tất cả path dưới tương đối `backend/`:

| Nhóm file | Trách nhiệm |
|---|---|
| `package.json`, `package-lock.json`, `tsconfig.json`, `tsconfig.build.json`, `tsconfig.test.json`, `.gitignore`, `.env.example` | Dependency/compile/scripts/config local; ignore `.env`, dist, logs |
| `src/main.ts`, `src/app.module.ts`, `src/create-app.ts` | Bootstrap và application factory cho API integration |
| `src/config/{config,config.module}.ts` | Config typed, validate env/defaults |
| `src/http/{api-error,api-error.filter,api-key.guard,rate-limit,request-context,openapi}.ts` | HTTP cross-cutting, JSON error và secret-safe logs |
| `src/health/health.controller.ts` | live/ready |
| `src/database/{database.module,pool,migrate}.ts`, `migrations/001_catalog.sql` | DB pool, transactional migrations, schema |
| `src/catalog/{catalog.types,catalog.repository,catalog.service,catalog.controller,catalog.module,normalize,query-schema}.ts` | Domain, SQL query/upsert, list/detail/related/playback DTO |
| `src/providers/{camera-provider,notis.provider,fixture.provider,providers.module}.ts` | Provider port, Notis validate/map/fetch, own fixture |
| `src/sync/{sync.service,sync.controller,sync.module}.ts`, `src/cli/{sync,seed-fixture}.ts` | Shared transactional import + CLI/admin |
| `src/snapshot/{snapshot.service,snapshot.controller,snapshot.module,bounded-cache,fetch-pool,mime}.ts` | bytes/MIME/ETag/TTL/queue/coalescing/cancel |
| `fixtures/{catalog.json,snapshot.png}` | 12 self-created cameras + generated original test image |
| `test/helpers/{app,fake-provider,test-database,clock}.ts` | Isolated app/provider/DB/time controls |
| `test/unit/*.test.ts`, `test/integration/*.test.ts`, `test/smoke/notis-smoke.ts` | Behavioral tests + separate real-source smoke |
| `Dockerfile`, `compose.yml`, `compose.test.yml`, `.dockerignore`, `README.md` | Local deploy/test DB/runbook |

Nội bộ `CameraRecord` chứa providerCameraId/source reference; `CameraDto` chỉ field public và endpoint riêng. SQL chỉ parameterized. `CatalogRepository` là abstract injection token, `PgCatalogRepository` implementation trong cùng file; test fake implements cùng port. `CameraProvider` là abstract class token, concrete Notis/Fixture chọn bằng config. Tránh một `utils.ts` chứa tất cả logic.

## Task 1: API shell, config và authentication/error boundary

**Files:** package/tsconfig/env/gitignore, main/app/create-app, config/http/health; `test/unit/config.test.ts`, `test/integration/http-boundary.test.ts`, helper app/clock.

**Interfaces:**
- `loadConfig(env: NodeJS.ProcessEnv): AppConfig`: default mode notis; validate API/admin keys khác nhau/nonempty, DATABASE_URL và tất cả numeric bounds; secret không vào validation error.
- `createApp(options?: {config?: AppConfig; logger?: LoggerService}): Promise<NestFastifyApplication>`; caller await init + Fastify ready trước inject, close trong finally. Main mới listen; tests không listen port.
- `ApiError(code: string, status: number, retryable: boolean, publicMessage: string)`; exception filter sinh JSON error từ spec, có requestId.
- Clock injectable `now(): number`; request context sinh ID server hoặc nhận ID đúng dạng bounded (≤128 safe chars), không tin dữ liệu log tùy ý.
- Health live không gọi DB/provider; ready được nối DB ở Task2. Tests protected controller chỉ tồn tại trong testing module, không thêm API stub vào product.

- [x] **Step1 — RED:** Tạo config tests và Fastify inject boundary tests. Assertions: missing keys fails without echoing supplied secret; fixture explicit overrides default; live200 anonymous; protected test route401 thiếu/sai key; admin key chỉ admin, reader key không dùng admin; malformed JSON400, oversized JSON413, unknown field400; rate-limit test đặt limit2 để request3→429; log capture không có test secrets/query. Ban đầu thiếu config/app phải fail.
- [x] **Step2 — Run:** `npm run test:compile`, `node --test .test-dist/test/unit/config.test.js .test-dist/test/integration/http-boundary.test.js`; ghi lỗi thiếu implementation, không coi lỗi dependency/test harness là RED hành vi đã chứng minh.
- [x] **Step3 — Implement:** Tạo package/lock, factory/config/guards/filter/rate limiter có bounded cleanup, logger tự ghi fields allowlist. BodyLimit65536, trustProxy=false; auth docs hook chặn cả route Fastify do Swagger thêm sau. Test compiler emit legacy decorator metadata; test fixtures credentials chỉ test.
- [x] **Step4 — GREEN:** Chạy lại test của Task1 và `npm run typecheck`, `npm run build`; cùng requestId trong headers và JSON lỗi, không có upstream calls.
- [x] **Step5 — Checkpoint:** Nếu repo chưa có, `git init` riêng backend, stage exact file Task1, commit local `feat: establish camera API boundary`; không stage parent workspace/APKs, không push.


## Task 2: Durable catalog, migrations, own fixtures và search repository

**Files:** database/migration, catalog types/repository/normalize/module, fixture provider/data/image, cli seed, Compose DB/test helpers; `test/unit/normalize.test.ts`, `test/integration/catalog-repository.test.ts`.

**Interfaces:**
- `normalizeText(value: string): string`: trim/lowercase/NFD/remove diacritics, đ→d; preserve word boundaries.
- `ProviderCamera`: provider, providerCameraId, name, provinceId, nullable address/district/location, sourceKind, sourceRef; no public URL arbitrary.
- `CatalogRepository.list(query: CatalogQuery): Promise<{items: CameraRecord[];total:number;catalog:CatalogState}>`; `find(id:string): Promise<CameraRecord|null>`; `districts(provinceId:string): Promise<DistrictCount[]>`; `related(camera:CameraRecord,limit:number): Promise<CameraRecord[]>`.
- `CatalogRepository.commitImport(input:{provider:string;provinceId:string;bbox:Bbox;cameras:ProviderCamera[];fetchedAt:Date}): Promise<ImportResult>`: upsert + state/version + success import log in one transaction, retain UUID by unique provider/source ID. Failure log separate sanitized enum, no partial publication.
- `CatalogState`: version string (BIGINT serialized string), fetchedAt ISO|null, isStale derived via Clock/config, coverage unknown|partial|verified, syncState never_synced|synced. New fixture state explicitly mode fixture; real empty DB state never_synced.

- [x] **Step1 — RED:** Tests normalize `Đường`, decomposed accents and address null; repository import same camera twice→same ID, no duplicate; same name different source ID→two records; rollback injected failure→old version/items; no-delete absence; filter exact normalized district; search address as well as name; 12 fixtures paginate stable; location null remains listable, not0,0; restart pool retains records; never_synced/stale clock controls.
- [x] **Step2 — Run:** `docker compose -f compose.test.yml up -d --wait db`, `npm run test:compile`, `node --test .test-dist/test/unit/normalize.test.js .test-dist/test/integration/catalog-repository.test.js`; failing assertions before repository implementation. Test helper uses unique schema per run/search_path with public PostGIS, drops only that test schema; refuse production database URL.
- [x] **Step3 — Implement:** Schema migrations table/checksum + migration advisory lock; camera/catalog_state/catalog_imports with stable UUID, unique source key, nullable geography(Point,4326), GiST/search indexes. Store name/address normalized separately; parameterize LIKE and escape `%/_` so search text is literal. Fixture image generated independently; seed explicit mode and idempotent. Add DB SELECT1 readiness and graceful pool.close. No raw Genius catalog/keys/blacklist copied.
- [x] **Step4 — GREEN:** Repository/normalize tests, migrations twice, pool restart test, health ready200 with DB/503 when fake DB unavailable; no provider network from list query. Docker test volume isolated from runtime DB.
- [x] **Step5 — Checkpoint:** Commit `feat: persist camera catalog and search metadata` with only Task2 files and necessary app wiring.


## Task 3: Public Notis adapter + transactional sync/admin/CLI

**Files:** provider port/Notis/providers module, sync module/service/controller, cli sync; `test/unit/notis-provider.test.ts`, `test/integration/catalog-sync.test.ts`.

**Interfaces:**
- `CameraProvider.fetchCatalog(bbox:Bbox, signal?:AbortSignal): Promise<ProviderCamera[]>`; `CameraProvider.fetchSnapshot(sourceRef:string, signal:AbortSignal): Promise<SnapshotBytes>` (contract consumed in Task5).
- `NotisProvider` uses injected Undici `Dispatcher`; default fixed origin `https://api.notis.vn`, path `/v4/cameras/bybbox`, lat1=north/lng1=west/lat2=south/lng2=east; redirects disabled, timeout5000, JSON response bound proposed8 MiB separate from snapshot2 MiB. Schema validator accepts documented optional fields, rejects malformed required ID/name.
- `SyncService.sync({provinceId:'tp_hcm',bbox:Bbox}): Promise<ImportResult>`; CLI `npm run camera:sync -- --bbox=west,south,east,north` and admin POST invoke same service. Dedicated PG session advisory lock fixed namespace17001401, release finally; collision→409 SYNC_IN_PROGRESS (specific extra status for admin concurrency, consistent error envelope).
- Provider treats empty array as successful empty received set, does not delete previous cameras; updates catalog generation/outcome truthfully. `dist` not assigned district automatically; `values.ip` discarded; no Udrivex/AppCheck.

- [x] **Step1 — RED:** Undici MockAgent block real network; assert bbox query order, auth absent by default, 24hex source ID; null/optional fields and malicious liveviewUrl don't redirect origin; 401/403/429/500/timeouts/malformed/nonarray/oversize yield sanitized errors. Sync tests two concurrent calls→one409; failed import retains state/items; CLI bbox invalid rejected without request.
- [x] **Step2 — Run:** `npm run test:compile`, `node --test .test-dist/test/unit/notis-provider.test.js .test-dist/test/integration/catalog-sync.test.js`; DB helper from Task2, no source quota used.
- [x] **Step3 — Implement:** Validate response whole set before commit; derive snapshot reference only from validated source ID, not arbitrary source URL. Administrative auth via ADMIN_API_KEY, not reader key. Import logging on failure outside rolled-back transaction; ensure all code paths release session/dispatcher resources. CLI loads same config/service without starting listener and prints only counts/coverage/error codes.
- [x] **Step4 — GREEN:** Provider/sync tests + `npm run typecheck`/build; retry tests confirm no hidden fixture fallback or token from evidence. Verify source default notis and fixture only explicit.
- [x] **Step5 — Checkpoint:** Commit `feat: synchronize public Notis camera catalog`.


## Task 4: Camera-first APIs, detail, districts, related và playback descriptor

**Files:** catalog controller/service/query-schema, playback DTO and OpenAPI metadata in catalog types; `test/integration/camera-api.test.ts`.

**Interfaces:**
- `CatalogService.list(query): Promise<ApiEnvelope<CameraDto[]>>`; `.detail(id)`, `.districts(provinceId)`, `.related(id,limit)`, `.playback(id)`; consistent repo types from Task2.
- Public DTO excludes internal sourceRef/provider secrets, exposes nullable snapshot/thumbnail endpoints only when capability snapshot=true. Playback A1 `{cameraId,kind:'snapshot',snapshotEndpoint,refreshIntervalMs:12000,capturedAt:null}`; stream-only source→422 PLAYBACK_UNSUPPORTED.
- Routes: GET `/v1/cameras`, `/v1/camera-districts`, `/v1/cameras/{id}`, `/{id}/related`, `/{id}/playback`. UUID route validation prevents SQL/provider invocation on malformed IDs.
- Related known camera district=null→data[] + meta.reason DISTRICT_UNKNOWN; same district/province sorted normalized name/id, exclude own ID. Unknown UUID→404, not empty related pretending known.

- [x] **Step1 — RED:** API tests inject app with repository helper: q name/address case/accent variants; exact district normalized; q empty no filter, length1 rejected; pagination limits and unknown query rejected; unsupported province400; missing camera404; no coordinates still detail/playback; related excludes self and null reason; same-name cameras ID stable. Spy provider proves list/detail/playback do not fetch thumbnails/open sessions.
- [x] **Step2 — Run:** `npm run test:compile`, `node --test .test-dist/test/integration/camera-api.test.js`; assert failure of absent routes/contracts.
- [x] **Step3 — Implement:** Shared input parsers and manual Swagger DTO/schema reflecting same defaults/bounds. `meta.page` includes limit/offset/total local; catalog metadata fetchedAt/stale/version never presented as image time. Districts from real stored non-null labels only; no geocoder/Vietmap calls.
- [x] **Step4 — GREEN:** API tests + auth/regression from prior tasks; inspect DTO response contains no `sourceRef`, values.ip, raw headers, stream credentials. Catalog origin stale available without calling network.
- [x] **Step5 — Checkpoint:** Commit `feat: serve camera list details and playback descriptors`.


## Task 5: Snapshot pipeline, bounded cache/pool và safe cancellation

**Files:** snapshot module/service/controller/cache/pool/mime, provider snapshot implementation, catalog health update method; `test/unit/snapshot.test.ts`, `test/integration/snapshot-api.test.ts`.

**Interfaces:**
- `SnapshotService.get(cameraId:string, input:{signal?:AbortSignal;ifNoneMatch?:string}): Promise<SnapshotResult>`; result `{status:200|304,bytes?:Buffer,mime,etag,fetchedAt:Date,capturedAt:null,dataMode}`.
- `BoundedCache` enforces byte budget33554432 and TTL3000, LRU eviction; oversize cache item not retained; `FetchPool` 4active/32queued, abort queued waiter cleanly and release slot in finally. Inject Clock for deterministic tests, no real sleeps.
- In-flight key=domain camera ID; subscriber refcount per key. Disconnect one decrements only its subscription; abort provider when all subscribers gone. Different IDs never share buffers. No background refresh timer once requests finish.
- Notis fetch snapshot constructed `/v4/cameras/{24hex}/snapshot`, reject cross-origin redirect; read incrementally ≤2097152 before caching, even without Content-Length. Magic JPEG/PNG/WebP; provider HTML200 rejected. Endpoint headers MIME/ETag/Cache-Control private,no-cache/Last? fetched time header `X-Image-Fetched-At` ISO + `X-Data-Mode`, not fictional captured timestamp.
- DB health update only after actual upstream fetch success/failure with checkedAt; cache hit is not a new provider check. Health update failure is sanitized best-effort and cannot turn a valid fetched image into a fake upstream error.

- [x] **Step1 — RED:** Tests assert 10 concurrent same-ID calls→one provider fetch; A/B contents different; cancel one of two→remaining succeeds; cancel all→aborts and frees queue. Fake clock TTL2999 hits cache,3001 fetches; old If-None-Match after expiry must fetch before304; changed bytes200 new ETag. Enforce cache32MiB, fetch4/queue32→extra503. Chunked oversize/HTML200/invalid magic/timeout/auth errors map properly without bytes/secrets leak.
- [x] **Step2 — Run:** `npm run test:compile`, `node --test .test-dist/test/unit/snapshot.test.js .test-dist/test/integration/snapshot-api.test.js`; verify new meaningful assertions fail before implementation.
- [x] **Step3 — Implement:** Buffer only bounded image bytes for reusable cache; SHA256 ETag. Parse If-None-Match according to HTTP weak comparison/list/wildcard syntax for GET, test both wildcard/list and malformed validator (treat invalid as no match); do not bypass source refresh after TTL. Bind cancellation to aborted request/closed unfinished response, not ordinary completed incoming GET body. Release HTTP body/dispatcher resources and remove in-flight/cache references. No stale-success response on source failure.
- [x] **Step4 — GREEN:** Unit/API tests, fake time/budget/cancellation tests; assert Content-Type based magic when upstream omitted, successful304 has no body and existing fetchedAt, unsupported422, unknown404. Validate health checkedAt does not move on cache hit.
- [x] **Step5 — Checkpoint:** Commit `feat: deliver bounded cached camera snapshots`.

## Task 6: OpenAPI/runbook/Compose và full real-source acceptance

**Files:** http OpenAPI, README/Dockerfile/Compose/dockerignore, scripts in package, `test/integration/end-to-end.test.ts`, `test/integration/openapi.test.ts`, `test/smoke/notis-smoke.ts`; `docs/verification.md` inside backend (generated sanitized report at execution).

**Interfaces:**
- Package scripts: `typecheck`, `build`, `test:compile`, `test:unit`, `test:api`, `test:db`, `db:migrate`, `seed:fixture`, `camera:sync`, `smoke:notis`, `start`, `dev`. Exact test file execution uses Node test runner on compiled `.test-dist` files; aggregate runner enumerates matching files through Node fs/child_process (portable Windows/Linux), not shell-specific glob expansion.
- `npm run smoke:notis -- --bbox=106.695,10.770,106.705,10.780`: bounded observed test viewport, **not whole TP.HCM**. Connect backend local using env secrets, admin sync→list→pick snapshot-capable ID→detail/playback→snapshot twice→assert MIME/ETag/fetchedAt. Prints time/coverage/count/camera UUID/status/byte count/hash only; no keys/raw URLs. Do not enforce18/89/90/900 counts, source data changes.
- Compose runtime DB/volume separate test DB; API host127.0.0.1, internal HOST0.0.0.0; image Node24 and PostGIS17 version tagged then digest recorded. Secrets from local ignored env, placeholder `.env.example` only; no embedded production defaults. Graceful SIGTERM closes listener/pool/dispatcher/aborts active source requests.

- [x] **Step1 — RED:** End-to-end fake source test: admin sync→public list search/filter→related/detail/playback→snapshot refresh afterfakeTTL; backend restart→same catalog IDs; failed nextsync→old generation/real mode not fixture. OpenAPI paths/default/security/422/429 match routes and no deferred map/Vietmap controllers; docs/assets are auth protected. Log capture contains no fake tokens/search/coords/source payload.
- [x] **Step2 — Run:** `npm run test:compile`, `node --test .test-dist/test/integration/end-to-end.test.js .test-dist/test/integration/openapi.test.js`; isolate schema, block unexpected network.
- [x] **Step3 — Implement:** README migrate→sync Notis→list/detail/playback/snapshot curl/PowerShell examples using env not pasted keys; explicit fixture demo instructions; catalog completeness caveat as metadata explanation, no Udrivex runtime. Backup runbook pg_dump/restore to isolated DB with secret-safe invocation; document one-VPS limitation and later public auth. Create smoke CLI and default scripts; no service purchase/deploy.
- [x] **Step4 — GREEN/full verification:** Run `npm ci`, `npm run typecheck`, `npm run build`, `npm run test:unit`, `npm run test:api`, `npm run test:db`. Bring local runtime Compose up and run migrations, bounded `smoke:notis`; verify image signature/hash and headers; restart API and confirm same camera ID. Record exact commands/exit/results/environment in backend docs/verification.md. Source failure reported separately from code checks; do not claim real-source acceptance if smoke failed. Shut down only owned test containers; runtime service left running only if user needs to try, state local URL and stop command.
- [x] **Step5 — Checkpoint/review:** Commit `feat: complete camera backend local acceptance`. Review whole diff against spec/global constraints, no unrelated asset modifications, no .env/log/rawsource committed. Update plan checkboxes and stage with evidence; don't mark optional/source-blocked checks passed.


## Plan self-review

- Spec §§1–3: Tasks1/4/5/6 implement camera-first API/auth; no Vietmap prerequisite. §§4–5: Tasks2/3 persist IDs/schema/freshness/source choice and actual Notis import. §7: Tasks1/3/5 handle input/quota/timeout/cancel/cache/logs. §8: mapped to task tests and Task6 real-source smoke. §6/A2 remain roadmap, no stubs claimed complete.
- Review Focus1→Task2/4;2→Task2/3;3→Task5;4→Task3/5;5→Task5/6. Constants match spec, except additive explicit admin409 error and JSON catalog-response bound8MiB documented in Task3 to make import behavior concrete.
- Interfaces have single definitions above; cross-task references use CatalogRepository/CameraProvider/Clock. Database transactional work never relies on separate pool sessions for BEGIN/COMMIT; sync lock and release use a dedicated session.
- No prerequisite requires camera app source/token, key Vietmap, all900 cameras or LIVE success. Fixture tests cannot substitute real Notis smoke.
- Pending execution method: recommend **Native/inline** because six tasks share tightly coupled repository/provider/snapshot contracts, all changes are local and acceptance has deterministic tests. Subagent-driven alternative available if user prefers independent per-task review; no agents spawned during planning.

## Execution handoff

Plan chờ người dùng review và chọn Native/inline hoặc Subagent-driven. Sau xác nhận, đọc skill thực thi tương ứng và tạo repo riêng backend; nếu repository đã tồn tại thì áp dụng isolation theo workflow, không tự reset hoặc đưa APK vào repo. Spec đã được xác nhận, không hỏi lại lựa chọn nguồn Notis/Vietmap hoặc phạm vi camera-first.
