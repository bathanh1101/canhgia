# Hướng dẫn chạy local và deploy CanhGia

Guide chi tiết bằng tiếng Việt: chạy từng app trên máy dev, chạy test/E2E, deploy lên cloud và store. Bản tóm tắt tiếng Anh: `docs/deployment-guide.md` (file này chi tiết hơn; hai file phải khớp nhau).

**Mục lục:** [0 Tổng quan](#0-tổng-quan-repo-và-yêu-cầu-máy) · [1 Toolchain](#1-cài-toolchain) · [2 Supabase local](#2-supabase-local) · [3 Edge Functions + mock AT](#3-edge-functions-local-và-mock-accesstrade) · [4 Web](#4-web-nextjs-webadmin) · [5 Extension](#5-chrome-extension) · [6 Mobile](#6-mobile-flutter-trên-thiết-bị-android) · [7 Test và E2E](#7-chạy-test-và-e2e) · [8 Deploy](#8-deploy) · [9 Go-live](#9-checklist-go-live-và-việc-còn-chặn) · [10 Sự cố](#10-sự-cố-thường-gặp)

Quy ước: mọi lệnh chạy từ root repo trừ khi ghi khác. Không bao giờ in hoặc commit `ACCESSTRADE_TOKEN`, keystore, `key.properties`, `env/*.json` (đều đã gitignore).

## 0. Tổng quan repo và yêu cầu máy

| Thành phần | Đường dẫn | Công nghệ |
|---|---|---|
| Backend | `supabase/` (`config.toml`, `migrations/`, `functions/`, `seed.sql`, `tests/`) | Supabase (Postgres 17, GoTrue, Edge Functions Deno) |
| Web + admin | `apps/web` | Next.js 16, React 19 |
| Extension | `apps/extension` | WXT 0.21, MV3, Chrome |
| Mobile | `apps/mobile` | Flutter 3.47.5, package `io.canhgia.app` |
| Workspace | `package.json`, `pnpm-workspace.yaml` (chỉ `apps/web`, `apps/extension`) | pnpm 11.25.0, Node 24 (`.nvmrc`) |

Cổng mặc định của `supabase/config.toml` (bản "chuẩn"):

| Dịch vụ | Cổng | Ghi chú |
|---|---|---|
| API (Kong) | 54321 | `/rest/v1`, `/auth/v1`, `/functions/v1` |
| Postgres | 54322 | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Shadow DB | 54320 | dùng khi `db diff` |
| Studio | 54323 | tắt nếu start với `-x studio` |
| Mailpit (đọc OTP) | 54324 | tên trong config là `[local_smtp]` |
| Analytics | 54327 | |
| Mock AccessTrade | 8787 | tự chạy, xem mục 3 |
| Web | 3000 | `next dev` / `next start` |

Yêu cầu máy: Linux/WSL2/macOS, Docker đang chạy (bắt buộc cho Supabase), RAM >= 8 GB (Gradle được cấu hình `-Xmx8G`), Android phone bật Wireless debugging (mobile), Chrome (extension).

## 1. Cài toolchain

Máy dev hiện tại cài mọi thứ ở user-space (không sudo). Thêm vào `~/.bashrc`:

```bash
export PATH=$HOME/.local/bin:$HOME/.deno/bin:$HOME/flutter/bin:$HOME/jdk/bin:$PATH
export JAVA_HOME=$HOME/jdk ANDROID_HOME=$HOME/android-sdk
```

| Tool | Phiên bản | Ghi chú |
|---|---|---|
| Node | 24 (`.nvmrc`, `engines: >=24 <25`) | `nvm use` |
| pnpm | 11.25.0 (`packageManager`) | `corepack enable` hoặc `npm i -g pnpm@11.25.0`; `allowBuilds` trong `pnpm-workspace.yaml` đã khai báo |
| Supabase CLI | 2.116 | web có sẵn devDependency `supabase`, nhưng dùng CLI global cho stack |
| Docker | bất kỳ bản mới | phải chạy trước `supabase start` |
| Deno | 2.9.7 | `deno` ở `~/.deno/bin` |
| Flutter | 3.47.5 (stable) | CI pin đúng bản này |
| JDK | Temurin 17 | `JAVA_HOME=$HOME/jdk` |
| Android SDK | platform 35 và 36 | Flutter 3.47.5 cần SDK 36 (xem mục 10) |
| `unzip` | | máy này dùng shim python đặt ở `~/.local/bin` (Flutter/Gradle cần `unzip`) |

```bash
pnpm install                       # cài web + extension
flutter doctor -v                  # kiểm tra JDK, Android SDK, licenses
flutter doctor --android-licenses  # nếu doctor báo chưa accept
deno --version && supabase --version && docker info >/dev/null && echo docker-ok
```

## 2. Supabase local

### 2.1 Biến môi trường bắt buộc trước `supabase start`

`config.toml` đọc 3 biến qua `env()`; thiếu là CLI lỗi hoặc auth captcha/Google hỏng:

```bash
export TURNSTILE_SECRET=1x0000000000000000000000000000000AA          # secret TEST của Cloudflare (luôn pass)
export SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID=local                 # placeholder
export SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=local                    # placeholder
```

Có thể đặt trong `supabase/.env` (gitignore) thay vì export. Site key Turnstile test tương ứng: `1x00000000000000000000AA`.

### 2.2 Đường chuẩn (cổng 543xx)

```bash
supabase start -x studio,imgproxy   # bỏ Studio/imgproxy cho nhẹ; bỏ -x studio nếu muốn Studio :54323
supabase db reset                   # chạy toàn bộ migrations + supabase/seed.sql
supabase test db                    # pgTAP: supabase/tests/database/*.test.sql
supabase status -o env              # in API_URL, ANON_KEY, SERVICE_ROLE_KEY, DB_URL, JWT_SECRET ...
supabase stop                       # thêm --no-backup để xoá volume
```

Dữ liệu seed (`supabase/seed.sql`, chỉ chạy local):

| Email | UUID | Vai trò |
|---|---|---|
| `admin@test.canhgia.local` | `11111111-1111-1111-1111-111111111111` | admin (phải enrol TOTP lần đầu) |
| `minh@test.canhgia.local` | `22222222-2222-2222-2222-222222222222` | người dùng |
| `lan@test.canhgia.local` | `33333333-3333-3333-3333-333333333333` | người dùng |

Đăng nhập bằng email OTP; không có mật khẩu. Mã 6 số nằm trong Mailpit (`http://127.0.0.1:54324`; API `GET /api/v1/messages`). Seed cũng tạo 3 Vault secret cục bộ: `cccd_pepper`, `project_url` (`http://kong:8000`), `cron_secret` (`dev-cron-secret`). Khi deploy cloud phải tạo tay (mục 8.1).

Rate limit email: `[auth.rate_limit] email_sent = 2` (2 mail/giờ) — đủ cho dev thủ công, không đủ cho E2E (mục 7). Sửa rồi `supabase stop && supabase start`.

Lấy key (public demo key của CLI, không phải bí mật):

```bash
supabase status -o env | grep -E '^(API_URL|ANON_KEY|SERVICE_ROLE_KEY)='
```

Sinh lại type cho web sau khi đổi schema (mặc định trỏ `127.0.0.1:54322`, đổi bằng `SUPABASE_DB_URL`):

```bash
pnpm --filter web gen:types
```

### 2.3 Workaround: cổng 54322 bị chiếm (scratch workdir, cổng 553xx)

Nếu project khác đang giữ 54322 (máy này bị vậy), `supabase start` ở root fail. Tạo thư mục làm việc riêng với cổng +1000 và tên project khác (tránh trùng tên container `supabase_*_canhgia`):

```bash
WD=/tmp/claude-1000/wd            # đường dẫn tuỳ ý
REPO=$PWD
mkdir -p $WD/supabase
cp    $REPO/supabase/config.toml $WD/supabase/
cp -r $REPO/supabase/functions   $WD/supabase/       # config.toml có [functions.*], cần thư mục này
ln -sfn $REPO/supabase/migrations $WD/supabase/migrations
ln -sfn $REPO/supabase/templates  $WD/supabase/templates   # magic-link.html
ln -sfn $REPO/supabase/tests      $WD/supabase/tests       # cho supabase test db
ln -sf  $REPO/supabase/seed.sql   $WD/supabase/seed.sql
# cổng 54xxx -> 55xxx, project_id riêng, nâng rate limit cho E2E
sed -E -i 's/^(port|shadow_port) = 54([0-9]{3})/\1 = 55\2/; s/^project_id = .*/project_id = "canhgia-e2e"/; s/^email_sent = .*/email_sent = 200/' $WD/supabase/config.toml
cd $WD && supabase start -x studio,imgproxy && supabase db reset
```

Kết quả: API `http://127.0.0.1:55321`, DB `postgresql://postgres:postgres@127.0.0.1:55322/postgres`, Mailpit `http://127.0.0.1:55324`. Mọi lệnh `supabase ...` sau đó chạy trong `$WD`. Khi sửa `supabase/functions` ở repo phải copy lại vào `$WD/supabase/functions` (`cp -r`). Nếu copy `functions` bị lỗi vì chỉ cần config, có thể xoá các block `[functions.*]` trong config thay vì copy thư mục.

Các test E2E/harness mặc định trỏ cổng 553xx (`apps/web/e2e/helpers/db.ts`: `http://127.0.0.1:55321`; `MAILPIT_URL` mặc định `http://127.0.0.1:55324`; extension `WXT_SUPABASE_URL` mặc định `http://127.0.0.1:55321`). Chạy stack đường chuẩn 543xx thì phải override các biến đó (mục 7).

## 3. Edge Functions local và mock AccessTrade

Functions trong `supabase/functions`: `resolve-url`, `create-link`, `admin-at-lookup` (verify_jwt = true); `sync-transactions`, `sync-datafeeds`, `sync-catalog`, `send-push`, `extension-login` (verify_jwt = false, tự kiểm `x-cron-secret` trong code).

### 3.1 Env của functions

`supabase start` chỉ nạp `supabase/functions/.env` (gitignore). Tạo từ mẫu:

```bash
cp supabase/functions/.env.example supabase/functions/.env
# điền: ACCESSTRADE_TOKEN, ACCESSTRADE_BASE_URL, CRON_SECRET, FCM_PROJECT_ID, FCM_SERVICE_ACCOUNT_JSON
```

Token AccessTrade thật cũng nằm ở `.env` root (gitignore, biến `ACCESSTRADE_TOKEN`). Không in ra terminal/log.

| Biến | Local dev | Ghi chú |
|---|---|---|
| `ACCESSTRADE_TOKEN` | token thật hoặc chuỗi bất kỳ khi dùng mock | mock chỉ cần header `authorization: token ...` |
| `ACCESSTRADE_BASE_URL` | `https://api.accesstrade.vn` hoặc URL mock | xem 3.2 |
| `CRON_SECRET` | chuỗi ngẫu nhiên | header `x-cron-secret` phải khớp |
| `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON` | rỗng nếu không thử push | |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | nền tảng tự inject | không đặt tay |

### 3.2 Mock AccessTrade

`supabase/functions/tests/mock-accesstrade.ts` chỉ export `startMock({port})`, không tự chạy khi `deno run` (không có `import.meta.main`). Chạy standalone bằng `deno eval` (đã kiểm chứng), giữ terminal riêng:

```bash
deno eval --allow-net --allow-read \
  'import {startMock} from "./supabase/functions/tests/mock-accesstrade.ts"; startMock({port: 8787}); await new Promise(() => {})'
```

Mock nghe `0.0.0.0:8787`, dữ liệu từ `supabase/functions/tests/fixtures/*.json`, yêu cầu header `authorization: token <bất kỳ>`. Endpoint: `/v1/transactions`, `/v1/datafeeds`, `/v1/offers_informations`, `/v1/campaigns`, `/v1/product_link/create`, và `POST /__control` để nạp dữ liệu (`{conversions, feed, fail, linkFail}`).

Edge runtime chạy trong container Docker nên `localhost` là chính container. Trỏ `ACCESSTRADE_BASE_URL` tới cầu Docker của host:

```
ACCESSTRADE_BASE_URL=http://172.17.0.1:8787
```

(`172.17.0.1` là gateway bridge mặc định; kiểm tra `docker network inspect bridge -f '{{(index .IPAM.Config 0).Gateway}}'`.) Trên Docker Desktop dùng `http://host.docker.internal:8787`.

### 3.3 `functions serve` với env riêng

Dùng khi muốn functions đọc env khác `supabase/functions/.env` (ví dụ trỏ mock). Chạy trong thư mục có `supabase/` (repo root hoặc `$WD`):

```bash
cat > .env.e2e <<'EOF'
ACCESSTRADE_TOKEN=test-token
ACCESSTRADE_BASE_URL=http://172.17.0.1:8787
CRON_SECRET=test-cron-secret
EOF
supabase functions serve --no-verify-jwt --env-file .env.e2e
```

`--no-verify-jwt` bỏ kiểm JWT ở cổng, tiện cho test; endpoint tại `http://127.0.0.1:54321/functions/v1/<tên>` (hoặc 55321). Đổi env phải dừng và chạy lại `functions serve` (không hot-reload env). `.env*` đã gitignore.

Curl mẫu đồng bộ giao dịch (`window` chỉ nhận `recent` hoặc `older`; thiếu/sai `x-cron-secret` trả 403, `window` sai trả 400):

```bash
curl -s -X POST http://127.0.0.1:54321/functions/v1/sync-transactions \
  -H "x-cron-secret: test-cron-secret" -H "content-type: application/json" \
  -d '{"window":"recent"}'
# ví dụ đúng: {"pages":1,"inserted":1,...,"done":true}
```

Nạp giao dịch vào mock trước khi gọi: `POST http://localhost:8787/__control` với `{"conversions":[...]}` (header `authorization` không cần cho `/__control`), hoặc dùng `makeConversions` trong test.

### 3.4 Cron

Cron (`supabase/migrations/20261002000100_cron_jobs.sql`) gọi `private.invoke_edge` dùng Vault `project_url` + `cron_secret`. Local, `seed.sql` đặt `http://kong:8000` và `dev-cron-secret`; muốn cron local chạm được functions thì `CRON_SECRET` trong env functions phải là `dev-cron-secret`, nếu không thì tự gọi curl như trên. Ví dụ job: `tx-recent` mỗi 20 phút, `tx-older` mỗi 6 giờ.

## 4. Web (Next.js web/admin)

### 4.1 Env

```bash
cp apps/web/.env.example apps/web/.env.local     # gitignore (.env*); ĐỪNG chạy nếu đã có .env.local đang dùng, cp sẽ ghi đè
```

| Biến | Local | Ghi chú |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | `http://127.0.0.1:54321` (hoặc 55321) | |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `ANON_KEY` từ `supabase status -o env` | tuyệt đối không dùng service-role |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | `1x00000000000000000000AA` | bắt buộc; thiếu thì nút "Gửi mã qua email" không bật. Nhúng lúc build, đổi phải build lại |
| `WEB_BASE_URL`, `APP_BASE_URL` | `http://localhost:3000` | |
| `NEXT_PUBLIC_{PLAY,APPSTORE,CWS}_URL` | rỗng | nút ẩn khi trống |
| `ANDROID_PACKAGE_NAME`, `ANDROID_SHA256_FINGERPRINTS` | `io.canhgia.app`, rỗng | cho `/.well-known/assetlinks.json` |
| `APPLE_TEAM_ID`, `IOS_BUNDLE_ID` | rỗng, `io.canhgia.app` | cho AASA |
| `NEXT_PUBLIC_SUPPORT_EMAIL` | tuỳ chọn | hiển thị ở trang bảo mật |

### 4.2 Chạy

```bash
pnpm --filter web dev                                # http://localhost:3000, hot reload
pnpm --filter web build && pnpm --filter web start   # bản production local (E2E dùng bản này)
```

Ghi chú: `next dev` (Next 16) có thể tự tạo `apps/web/AGENTS.md` và `apps/web/CLAUDE.md`; đây là file sinh tự động, không phải tài liệu của repo.

Trang: `/` (landing), `/chinh-sach-bao-mat` (privacy), `/admin/login`, `/admin/mfa`, `/admin/overview`, `/admin/{orders,withdrawals,users,complaints,cashback-rules}`, `/auth/callback`, `/.well-known/{assetlinks.json,apple-app-site-association}`.

### 4.3 Đăng nhập admin lần đầu

1. Mở `http://localhost:3000/admin/login`, nhập `admin@test.canhgia.local`, bấm "Gửi mã qua email" (đợi Turnstile test sinh token).
2. Mở Mailpit (`:54324` hoặc `:55324`), copy mã 6 số, nhập ở ô mã, bấm "Đăng nhập".
3. Ở `/admin/mfa` bấm "Thiết lập ứng dụng xác thực": quét QR bằng app TOTP (hoặc copy khoá ở dòng "Hoặc nhập khóa"), nhập mã 6 số, "Xác nhận" -> vào `/admin/overview` (phiên aal2).

Chưa enrol TOTP thì `is_admin()` (đòi aal2) chặn mọi thứ. Sau `supabase db reset` factor TOTP mất: enrol lại.

## 5. Chrome extension

### 5.1 Env

```bash
cp apps/extension/.env.example apps/extension/.env
```

| Biến | Local | Ghi chú |
|---|---|---|
| `WXT_SUPABASE_URL` | `http://127.0.0.1:55321` (mặc định trong `.env.example`; đổi thành 54321 nếu stack chuẩn) | cũng sinh `host_permissions` |
| `WXT_SUPABASE_PUBLISHABLE_KEY` | `ANON_KEY` | |
| `WXT_LANDING_URL` | `http://localhost:3000` | |
| `WXT_EXTENSION_KEY` | tuỳ chọn | public key base64 -> id cố định |

Build production (`build`, `zip`) ném lỗi nếu thiếu `WXT_SUPABASE_URL`, `WXT_SUPABASE_PUBLISHABLE_KEY`, `WXT_LANDING_URL`.

### 5.2 Lệnh

```bash
pnpm --filter ./apps/extension dev      # wxt dev: build watch + mở Chrome có extension
pnpm --filter ./apps/extension build    # -> apps/extension/.output/chrome-mv3
pnpm --filter ./apps/extension zip      # -> apps/extension/.output/*.zip (nộp CWS)
```

Load unpacked: `chrome://extensions` -> bật Developer mode -> "Load unpacked" -> chọn `apps/extension/.output/chrome-mv3`. Bar/label chỉ chèn trên shopee.vn, lazada.vn, tiki.vn, tiktok.com; Agoda/Traveloka/Klook chỉ kích hoạt từ popup.

### 5.3 Id cố định (cần cho redirect Google)

```bash
openssl genrsa -out key.pem 2048                             # giữ offline, không commit
openssl rsa -in key.pem -pubout -outform DER | base64 -w0    # -> WXT_EXTENSION_KEY
```

Đặt vào `.env`, build lại, đọc id ở `chrome://extensions`. Thêm `https://<id>.chromiumapp.org/` vào Supabase Auth redirect URLs (local: thay `EXTENSION_ID` trong `additional_redirect_urls` của `supabase/config.toml`).

### 5.4 Đăng nhập QR-pair

Popup hiển thị QR + mã; người dùng duyệt trên app mobile (đã đăng nhập), extension poll Edge Function `extension-login` (không cần redirect Google). Cần Supabase + functions đang chạy. Test bằng Playwright ở mục 7.4.

## 6. Mobile (Flutter trên thiết bị Android)

### 6.1 Env

```bash
cp apps/mobile/env/example.json apps/mobile/env/dev.json     # env/*.json gitignore (trừ example.json)
```

| Khoá | Local | Ghi chú |
|---|---|---|
| `SUPABASE_URL` | xem 6.3 | mặc định trong code `http://10.0.2.2:55321` |
| `SUPABASE_ANON_KEY` | `ANON_KEY` | thiếu là app báo "Thiếu cấu hình SUPABASE_ANON_KEY" |
| `APP_BASE_URL` | `https://canhgia.vn` (mặc định) | |
| `GOOGLE_WEB_CLIENT_ID`, `GOOGLE_IOS_CLIENT_ID` | rỗng nếu chưa có OAuth client | thiếu web id thì đăng nhập Google tắt |
| `TURNSTILE_SITE_KEY` | rỗng, hoặc `1x00000000000000000000AA` | có site key mà không có test token thì app đòi giải Turnstile |
| `TURNSTILE_TEST_TOKEN` | rỗng | chỉ có hiệu lực ở build debug (dành cho integration test) |
| `FCM_ENABLED` | `false` | |

### 6.2 Kết nối máy Android qua Wi-Fi

Điện thoại: Developer options -> Wireless debugging -> "Pair device with pairing code".

```bash
adb pair <ip>:<cổng-pair>        # nhập mã 6 số hiện trên điện thoại
adb connect <ip>:<cổng-debug>    # cổng ở màn hình chính Wireless debugging
adb devices                      # phải thấy "device"
flutter devices
```

Chưa kiểm chứng trên máy này: WSL2 (NAT) có thể không thấy điện thoại cùng LAN; nếu vậy dùng adb của Windows, hoặc bật networking mirrored trong `.wslconfig`.

### 6.3 `SUPABASE_URL` cho từng loại thiết bị

| Thiết bị | Giá trị | Cách |
|---|---|---|
| Emulator | `http://10.0.2.2:55321` (hoặc `:54321`) | 10.0.2.2 = máy host |
| Điện thoại thật | `adb reverse tcp:54321 tcp:54321` rồi `http://127.0.0.1:54321` | đơn giản nhất, không cần IP LAN |
| Điện thoại thật, không reverse | `http://<IP-LAN-máy-dev>:<cổng>` | Supabase publish cổng trên 0.0.0.0; mở firewall; WSL2 cần port-forward |

Build debug cho phép cleartext HTTP (`usesCleartextTraffic` trong manifest debug/profile); release thì không, prod phải dùng HTTPS.

### 6.4 Chạy và build

```bash
cd apps/mobile
flutter pub get
flutter run -d <device-id> --dart-define-from-file=env/dev.json
flutter build apk --debug   --dart-define-from-file=env/dev.json
flutter build apk --release --dart-define-from-file=env/prod.json         # ký bằng key.properties, không có thì debug key
flutter build appbundle --release --dart-define-from-file=env/prod.json   # AAB cho Play
```

Đầu ra: `build/app/outputs/flutter-apk/app-*.apk`, `build/app/outputs/bundle/release/app-release.aab`. Cài APK: `adb install -r <apk>`.

### 6.5 Ký release

`android/app/build.gradle.kts` đọc `apps/mobile/android/key.properties` (gitignore); có file thì dùng cấu hình `release`, không có thì rơi về debug key (Play sẽ từ chối):

```properties
storeFile=/đường/dẫn/upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Tạo keystore: `keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`. Backup offline. `APP_LINK_HOST` (host của app link, mặc định `canhgia.vn`) đặt trong `apps/mobile/android/gradle.properties`, hoặc `-PAPP_LINK_HOST=<host>`. Tăng `version:` trong `pubspec.yaml` (`x.y.z+build`, hiện `1.0.0+1`) cho mỗi lần upload.

## 7. Chạy test và E2E

### 7.1 Unit/lint/typecheck từng app

```bash
pnpm lint && pnpm typecheck && pnpm test && pnpm build      # cả workspace (web + extension)
pnpm --filter ./apps/web lint                               # cũng typecheck | test | build
pnpm --filter ./apps/extension lint                         # cũng typecheck | test | build
(cd apps/mobile && flutter analyze && flutter test)
(cd supabase/functions && deno test --allow-net --allow-env --allow-read)   # unit Edge Functions (như CI)
supabase test db                                            # pgTAP, cần stack đang chạy
bash supabase/tests/concurrency/withdraw-race.sh            # race rút tiền (CI, cần stack)
```

### 7.2 Thứ tự dựng stack E2E

1. Stack Supabase + `db reset` (mục 2.2 hoặc 2.3; cần `email_sent` cao).
2. Mock AT trên 8787 (mục 3.2).
3. `functions serve --no-verify-jwt --env-file` (mục 3.3), `CRON_SECRET` trong env-file.
4. Web build + start với `.env.local` trỏ đúng stack (mục 4).
5. Chạy test (dưới).

Sau mỗi `db reset` xoá `apps/web/e2e/.auth` (factor TOTP của admin đã mất): `rm -rf apps/web/e2e/.auth`.

### 7.3 Backend integration (Deno) và web Playwright

```bash
CRON_SECRET=test-cron-secret SUPABASE_URL=http://127.0.0.1:55321 \
  deno test --allow-net --allow-env --allow-read --no-check supabase/tests/integration/*.test.ts

pnpm --filter web exec playwright install chromium     # lần đầu
pnpm --filter web build
WEB_BASE_URL=http://localhost:3000 MAILPIT_URL=http://127.0.0.1:55324 \
  pnpm --filter web exec playwright test               # global-setup: 1 lần OTP+TOTP, lưu ở e2e/.auth
```

`playwright.config.ts` tự chạy `pnpm start` nếu chưa có server (`reuseExistingServer` khi không phải CI); workers = 1. Với stack 543xx đặt thêm `NEXT_PUBLIC_SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `MAILPIT_URL` (các helper trong `apps/web/e2e/helpers/` đọc các biến này).

### 7.4 Extension Playwright

```bash
WXT_SUPABASE_URL=http://127.0.0.1:55321 WXT_SUPABASE_PUBLISHABLE_KEY=<ANON_KEY> WXT_LANDING_URL=http://localhost:3000 \
  pnpm --filter ./apps/extension build
xvfb-run -a pnpm --filter ./apps/extension e2e     # Linux không màn hình; máy có GUI bỏ xvfb-run
```

Cần web đang chạy ở `WEB_BASE_URL` (mặc định `http://localhost:3000`) và mock AT đang chạy (bar test kích hoạt).

### 7.5 Mobile integration

`apps/mobile/integration_test/j1_attribution_test.dart`, `j2_confirm_test.dart`, `j3_withdraw_test.dart` chỉ chạy trên thiết bị:

```bash
(cd apps/mobile && flutter test integration_test/j1_attribution_test.dart -d <device-id> --dart-define-from-file=env/dev.json)
```

Trạng thái: chưa từng chạy trên thiết bị thật (báo cáo debugger 260930).

## 8. Deploy

Thứ tự: tài khoản/client -> Supabase -> Vercel -> Android/CWS/iOS -> checklist (mục 9). Chưa có gì được deploy tại thời điểm viết.

### 8.1 Supabase cloud

Tạo project (region ap-southeast-1; dùng Pro trước khi có user thật). Bật extension `pg_cron`, `pg_net`, `vault` nếu migration báo thiếu.

```bash
supabase login
supabase link --project-ref <ref>

# 1) Edge secrets
supabase secrets set ACCESSTRADE_TOKEN=... ACCESSTRADE_BASE_URL=https://api.accesstrade.vn \
  CRON_SECRET=$(openssl rand -hex 32) FCM_PROJECT_ID=... FCM_SERVICE_ACCOUNT_JSON="$(tr -d '\n' < sa.json)"
```

```sql
-- 2) Vault (SQL editor, TRƯỚC db push). cron_secret phải bằng CRON_SECRET ở trên
select vault.create_secret('https://<ref>.supabase.co', 'project_url');
select vault.create_secret('<CRON_SECRET>', 'cron_secret');
select vault.create_secret('<openssl rand -hex 32>', 'cccd_pepper');  -- đừng rotate tuỳ tiện: id_number_hmac phụ thuộc
```

```bash
# 3) functions rồi migrations. KHÔNG dùng --include-seed, KHÔNG dùng `supabase config push`
supabase functions deploy
supabase db push
```

`config push` sẽ ghi đè auth cloud bằng giá trị local (`site_url=http://localhost:3000`). Dữ liệu tham chiếu (merchants, tiers, banks, settings) đến từ migration `20261001002000`, không phải `seed.sql`.

Cấu hình Auth trong dashboard:

| Mục | Giá trị |
|---|---|
| Site URL | origin web |
| Redirect URLs | `<WEB_BASE_URL>`, `<WEB_BASE_URL>/auth/callback`, `https://<EXTENSION_ID>.chromiumapp.org/` (`io.canhgia.app://login-callback` chỉ khi thêm redirect flow) |
| Google provider | Web client id/secret (cùng `GOOGLE_WEB_CLIENT_ID` của mobile); tạo thêm client Android (package `io.canhgia.app`, SHA-1 của Play App Signing và upload key) và iOS |
| Captcha | Cloudflare Turnstile, secret thật (site key ở web + mobile env) |
| MFA | TOTP enrol + verify bật |
| SMTP | custom SMTP (Resend); SMTP mặc định bị giới hạn rất thấp. OTP 6 số, hết hạn 600 s; template "Magic link" = `supabase/templates/magic-link.html`, subject `Mã đăng nhập CanhGia`. Verify domain (SPF/DKIM) trước khi có user thật |
| Rate limit | nâng `email_sent` khỏi mức local |

Admin đầu tiên (SQL; user phải đã đăng nhập ít nhất một lần):

```sql
insert into public.admins(user_id, created_by) select id, id from auth.users where email = '<admin>';
```

Giữ >= 2 admin (mất TOTP: admin khác xoá dòng `auth.mfa_factors`, user enrol lại). Kiểm tra sau deploy: `select count(*) from cron.job` = 13; `sync_state` không có `vault_missing`; `sync_errors` 24 h = 0 hoặc đã xử lý; không còn user `@test.canhgia.local`. Backfill datafeeds tự chạy qua cron `datafeeds-backfill`; kích tay:

```bash
curl -X POST https://<ref>.supabase.co/functions/v1/sync-datafeeds \
  -H "apikey: <anon>" -H "x-cron-secret: <CRON_SECRET>" -d '{"mode":"backfill"}'
```

### 8.2 Web (Vercel)

Import repo, **Root Directory = `apps/web`**, install ở root (pnpm workspace), Node 24. Đặt env (Production):

| Biến | Giá trị |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | URL project + publishable/anon key |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | site key thật |
| `WEB_BASE_URL`, `APP_BASE_URL` | origin public (`https://<x>.vercel.app` khi chưa có domain) |
| `NEXT_PUBLIC_{PLAY,APPSTORE,CWS}_URL` | link store |
| `ANDROID_PACKAGE_NAME` | `io.canhgia.app` |
| `ANDROID_SHA256_FINGERPRINTS` | SHA-256, phân tách dấu phẩy: Play App Signing (+ upload key nếu sideload) |
| `APPLE_TEAM_ID`, `IOS_BUNDLE_ID` | chỉ iOS |
| `NEXT_PUBLIC_SUPPORT_EMAIL` | tuỳ chọn |

Sau khi có fingerprint: redeploy và kiểm `https://<host>/.well-known/assetlinks.json` (trả `[]` khi chưa đặt đủ hai biến) và `/.well-known/apple-app-site-association`. `/chinh-sach-bao-mat` là URL privacy cho Play, App Store, CWS. Đổi domain sau này: thêm domain Vercel + DNS, đổi `WEB_BASE_URL`/`APP_BASE_URL`, `WXT_LANDING_URL`, mobile `APP_BASE_URL` + `APP_LINK_HOST`, Supabase Site URL/redirects, Resend; build lại app/extension (chúng nhúng host).

### 8.3 Chrome Web Store

1. Sinh key một lần (mục 5.3), giữ `key.pem` offline.
2. Build zip với env production:
   ```bash
   WXT_SUPABASE_URL=https://<ref>.supabase.co WXT_SUPABASE_PUBLISHABLE_KEY=<anon> \
   WXT_LANDING_URL=https://<web-origin> WXT_EXTENSION_KEY=<base64> \
     pnpm --filter ./apps/extension zip      # -> apps/extension/.output/*.zip
   ```
3. Dashboard CWS (phí dev $5): upload zip, visibility **Unlisted**, privacy URL `<WEB_BASE_URL>/chinh-sach-bao-mat`. Khai báo: đọc giá và URL sản phẩm trên Shopee/Lazada/Tiki/TikTok, lưu phiên đăng nhập, không lưu lịch sử duyệt. Quyền tối thiểu: `storage`, `identity`, `activeTab` + 4 host.
4. Tăng `version` trong `apps/extension/package.json` mỗi lần upload; điền link listing vào `NEXT_PUBLIC_CWS_URL`.

### 8.4 Google Play (Android)

1. Keystore + `key.properties` (mục 6.5).
2. `cd apps/mobile && flutter build appbundle --release --dart-define-from-file=env/prod.json` (`env/prod.json` từ `example.json`: URL Supabase cloud, `APP_BASE_URL` thật, client id Google, `TURNSTILE_SITE_KEY` thật, `TURNSTILE_TEST_TOKEN` rỗng, `FCM_ENABLED`).
3. Play Console (phí $25): tạo app `io.canhgia.app`, bật Play App Signing, upload AAB lên Internal testing, thêm tester, điền privacy URL và Data safety (email, device id, ảnh KYC, tài khoản ngân hàng; mã hoá khi truyền; xoá theo yêu cầu).
4. Play Console -> App signing: SHA-1 -> Google OAuth client Android; SHA-256 -> `ANDROID_SHA256_FINGERPRINTS` (Vercel) rồi redeploy. SHA-1 sai chỉ làm hỏng đăng nhập Google ở bản Play.
5. Push (FCM): thêm `google-services.json` vào `apps/mobile/android/app/` **và** plugin `com.google.gms.google-services` trong Gradle (chưa được cấu hình; `main.dart` gọi `Firebase.initializeApp()` không options), đặt `FCM_ENABLED=true`, đưa service account vào Edge secret. Không làm thì push tắt im lặng.

### 8.5 iOS (best-effort, cần macOS)

Cần macOS (runner `macos-latest` hoặc máy mượn) và Apple Developer account. Không có workflow iOS vì không kiểm chứng được. Việc còn thiếu: đặt `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_IOS_REVERSED_CLIENT_ID`, `APP_LINK_HOST` trong `ios/Flutter/*.xcconfig`; thêm URL scheme = reversed client id; Associated Domains `applinks:<host>`; APNs key lên Firebase; điền `APPLE_TEAM_ID` + `IOS_BUNDLE_ID` cho AASA. Rồi:

```bash
(cd apps/mobile && flutter build ipa --dart-define-from-file=env/prod.json)
```

Upload qua App Store Connect API key, TestFlight nội bộ. Release công khai có thể cần Sign in with Apple (guideline 4.8, cần xác minh) vì app có Google login.

### 8.6 GitHub Actions

Các workflow deploy đều là `workflow_dispatch`; thiếu secret thì bỏ qua với warning.

| Workflow | Kích hoạt | Secret cần đặt | Kết quả |
|---|---|---|---|
| `ci.yml` | mọi push/PR | không | supabase (start/reset/test db/deno test), web, extension, mobile |
| `e2e.yml` | PR, push `main`, cron 02:00 UTC | không (dùng key demo) | backend-integration, web-e2e, extension-e2e; mobile chỉ nightly |
| `deploy-supabase.yml` | tay; input `set_secrets`, `deploy_functions`, `push_migrations` | `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`; khi `set_secrets`: `ACCESSTRADE_TOKEN`, `CRON_SECRET`, `FCM_SERVICE_ACCOUNT_JSON`, `FCM_PROJECT_ID` | link, secrets, functions deploy, db push (không set Vault) |
| `deploy-web.yml` | tay; input `target` preview/production | `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` (env của app nằm trong Vercel) | `vercel pull/build/deploy --prebuilt` |
| `deploy-extension.yml` | tay | `WXT_SUPABASE_URL`, `WXT_SUPABASE_PUBLISHABLE_KEY`, `WXT_LANDING_URL` (bắt buộc), `WXT_EXTENSION_KEY` (nên có) | artifact `extension-zip` |
| `deploy-android.yml` | tay | `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `MOBILE_ENV_JSON` (nội dung `env/prod.json`) | artifact `android-aab` |

Các job deploy dùng `environment` (`production` cho supabase/extension/android; deploy-web theo `target`): tạo environment tương ứng trong repo settings.

Rollback: Vercel instant rollback; functions `git checkout <sha> && supabase functions deploy`; migration chỉ forward-fix (không down-migrate bảng tiền); dừng sync bằng `select cron.unschedule('<job>')`; gỡ CWS item, dừng rollout Play; rotate token AT nếu từng bị log.

## 9. Checklist go-live và việc còn chặn

Còn chặn (cần người thật):
- [ ] AccessTrade: chưa merchant nào trong 7 merchant được duyệt (chỉ Lazada Malaysia + AccessTrade Referral, xem `docs/accesstrade-capability-matrix.md`). Shopee/TikTok/Agoda/Traveloka/Klook còn cần AT đồng ý bằng văn bản cho phép cashback. Chưa duyệt thì `create-link` trả `merchant_unavailable`/`link_rejected`.
- [ ] Mua thử thật qua link CanhGia (hỏi AT có cho tự mua không), sau 24-72 h kiểm `/v1/transactions` có `utm_content=u<short>c<click>` (không thì `sub1`); cập nhật matrix.
- [ ] Quét VietQR từ `/admin/withdrawals` bằng app VCB và MB, khớp số tiền/tài khoản/nội dung.
- [ ] Admin đầu tiên đã enrol TOTP; >= 2 admin.

Checklist trước khi mở:
- [ ] Vault đủ 3 secret; `cron.job` = 13; `sync_state`/`sync_errors` sạch; không còn user test.
- [ ] Non-admin không vào được `/admin`.
- [ ] `.well-known` có fingerprint; App Link mở `/r/<code>` ở bản Play.
- [ ] Đăng nhập Google + email OTP ở bản Android prod; push nhận được (FCM).
- [ ] Privacy URL truy cập được; store listing đầy đủ.
- [ ] Turnstile key thật; Resend domain verified; rate limit auth đã nâng.
- [ ] Thăm dò trên Edge cloud: header nào chứa IP client (`extension-login` lấy hop đầu của `x-forwarded-for`).
- [ ] Chạy security sweep (phase 11) trên prod bằng tài khoản test rồi xoá.

## 10. Sự cố thường gặp

| Triệu chứng | Nguyên nhân | Xử lý |
|---|---|---|
| `supabase start` lỗi bind 54322 | project khác giữ cổng | dùng scratch workdir cổng 553xx (mục 2.3) |
| Trùng tên container `supabase_*_canhgia` | hai stack cùng `project_id` | đổi `project_id` trong config scratch |
| `functions serve` không đọc env / vẫn gọi AT thật | `supabase start` chỉ nạp `supabase/functions/.env`; env đổi mà chưa restart | chạy lại `functions serve --no-verify-jwt --env-file <file>`, kiểm `CRON_SECRET` khớp |
| `sync-transactions` 403 / 400 | thiếu `x-cron-secret` / `window` khác `recent`,`older` | xem curl mục 3.3 |
| Function không gọi được mock AT (DNS/timeout) | container không thấy `localhost` của host | `ACCESSTRADE_BASE_URL=http://172.17.0.1:8787` (hoặc `host.docker.internal`) |
| Chạy `deno run mock-accesstrade.ts` mà không nghe cổng | file chỉ export `startMock` | dùng `deno eval` ở mục 3.2 |
| `UNAUTHORIZED_LEGACY_JWT` / `PGRST301` | key ký bằng JWT secret của stack khác | lấy lại key bằng `supabase status -o env` của đúng stack |
| Không nhận OTP / `over_email_send_rate_limit` | `email_sent = 2`/giờ | nâng lên 200 trong config, `supabase stop && supabase start` |
| `422 otp_disabled` hoặc 500 "Database error finding user" | user seed thiếu `aud/role/email_confirmed_at/identities` | dùng `seed.sql` hiện tại (đã sửa), `supabase db reset` |
| Nút "Gửi mã qua email" không bật | thiếu `NEXT_PUBLIC_TURNSTILE_SITE_KEY` hoặc chưa build lại | đặt `1x00000000000000000000AA`, build lại |
| Playwright: "admin already has a TOTP factor but e2e/.auth/totp-secret.txt is missing" | DB còn factor, file `.auth` mất | `supabase db reset` và `rm -rf apps/web/e2e/.auth` |
| Playwright web fail đăng nhập sau `db reset` | `.auth` cũ | `rm -rf apps/web/e2e/.auth` |
| Extension prod build ném "production build needs env" | thiếu `WXT_*` | đặt đủ 3 biến bắt buộc |
| Flutter/Gradle báo thiếu SDK 36 | Flutter 3.47.5 compile với API 36 | `sdkmanager "platforms;android-36"` (máy này có 34/35/36) |
| `unzip: command not found` khi build Flutter/Gradle | máy không có unzip, không sudo | shim python `unzip` trong `~/.local/bin` (nằm trong PATH mục 1) |
| App mobile không tới được Supabase local | sai `SUPABASE_URL` | `adb reverse` hoặc `10.0.2.2` (mục 6.3) |
| Build release ký bằng debug key | thiếu `android/key.properties` | tạo file (mục 6.5) |
| Google login chỉ hỏng ở bản Play | SHA-1 của Play App Signing chưa vào OAuth client | mục 8.4 bước 4 |
| App Links không xác minh | `ANDROID_PACKAGE_NAME` sai hoặc thiếu fingerprint | dùng `io.canhgia.app`, điền `ANDROID_SHA256_FINGERPRINTS`, redeploy |
