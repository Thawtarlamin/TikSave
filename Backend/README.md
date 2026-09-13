# Authorized TikTok Media API — Node.js

ဤ project သည် **ကိုယ်ပိုင် သို့မဟုတ် တရားဝင်ခွင့်ပြုချက်ရှိသော TikTok content** ကို URL ဖြင့် resolve/download လုပ်ရန် Node.js + Express service ဖြစ်သည်။ `yt-dlp` သည် source stream ကို ရယူပေးနိုင်သော်လည်း ဤ API သည် video pixels ထဲမှ watermark ကို ဖျက်ပေးသည်ဟု အာမမခံပါ။ TikTok ၏ terms၊ copyright နှင့် privacy စည်းမျဉ်းများကို လိုက်နာပြီး အသုံးပြုပါ။

## Endpoints

| Endpoint | ရည်ရွယ်ချက် |
|---|---|
| `GET /health` | Service အသက်ရှင်နေမှု စစ်ရန် |
| `POST /v1/info` | Video metadata ပြန်ရန် |
| `POST /v1/download` | JSON metadata နှင့် temporary `download_url` ပြန်ရန် |
| `GET /v1/files/:token` | JSON ထဲမှ temporary URL ကိုခေါ်ပြီး media file ရယူရန် |

`API_KEY` သတ်မှတ်ထားပါက `/v1/*` endpoint များတွင် `X-API-Key` header ထည့်ရမည်။ API key မသတ်မှတ်ထားလျှင် local development အတွက် authentication မလိုပါ။

## Requirements

Node.js 20 နှင့်အထက်၊ `yt-dlp`၊ နှင့် video/audio stream ပေါင်းစပ်ရန် လိုအပ်ပါက `ffmpeg` ထည့်ထားရမည်။ `yt-dlp` ကို [official repository][2] မှ လေ့လာနိုင်ပြီး Express ကို [official documentation][1] တွင် ကြည့်နိုင်သည်။

Linux/macOS တွင် `yt-dlp` မရှိပါက အောက်ပါအတိုင်း install လုပ်နိုင်သည်။

```bash
python3 -m pip install --user yt-dlp
# Ubuntu/Debian တွင်
sudo apt-get update && sudo apt-get install -y ffmpeg
```

ထို့နောက် terminal အသစ်ဖွင့်ပြီး `yt-dlp --version` ဖြင့် စစ်ပါ။ PATH ထဲမဝင်သေးပါက server စတင်ရာတွင် executable path ကို တိုက်ရိုက်ပေးပါ။

```bash
YTDLP_BIN="$HOME/.local/bin/yt-dlp" npm start
```

Windows တွင် `yt-dlp.exe` path ကို သတ်မှတ်နိုင်သည်။

```powershell
$env:YTDLP_BIN = "C:\\tools\\yt-dlp.exe"
npm start
```

## Install and run

```bash
cd /home/ubuntu/tiktok-downloader-api-node
npm install
npm run check
npm start
```

Server သည် default အားဖြင့် `http://127.0.0.1:8000` တွင် run မည်။ Port ပြောင်းရန် `PORT=9000 npm start` ကို အသုံးပြုပါ။ Development mode အတွက် `npm run dev` ကို အသုံးပြုနိုင်သည်။

## Environment variables

| Variable | Default | အဓိပ္ပာယ် |
|---|---:|---|
| `PORT` | `8000` | HTTP port |
| `API_KEY` | မသတ်မှတ် | Request authentication key |
| `RATE_LIMIT_PER_MINUTE` | `10` | Client IP တစ်ခုလျှင် တစ်မိနစ်အတွင်း request အများဆုံး |
| `DOWNLOAD_TIMEOUT_SECONDS` | `120` | Resolve/download timeout |
| `MAX_DOWNLOAD_BYTES` | `262144000` | Download file size limit; default 250 MB |
| `YTDLP_BIN` | `yt-dlp` | Binary path/name |
| `YTDLP_COOKIES_FILE` | မသတ်မှတ် | ကိုယ်ပိုင် authorized session cookies file လိုအပ်မှသာ အသုံးပြုရန် |

Production တွင် အနည်းဆုံး `API_KEY` သတ်မှတ်ပါ။ Cookies file ကို public repository သို့မဟုတ် container image ထဲ မထည့်ပါနှင့်။

## Request examples

Metadata:

```bash
curl -X POST http://127.0.0.1:8000/v1/info \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: change-me' \
  -d '{"url":"https://www.tiktok.com/@creator/video/1234567890"}'
```

Download request (JSON response):

```bash
curl -X POST http://127.0.0.1:8000/v1/download \
  -H 'Content-Type: application/json' \
  -H 'X-API-Key: change-me' \
  -d '{"url":"https://www.tiktok.com/@creator/video/1234567890"}'
```

Response example:

```json
{
  "ok": true,
  "id": "1234567890",
  "filename": "1234567890.mp4",
  "size": 12345678,
  "download_url": "http://127.0.0.1:8000/v1/files/TOKEN",
  "expires_in": 600,
  "expires_at": "2026-08-26T00:00:00.000Z"
}
```

The API call above returns JSON only. To download the actual file later, call the returned `download_url`:

```bash
curl -L 'http://127.0.0.1:8000/v1/files/TOKEN' -o video.mp4
```

## Tests

```bash
npm run check
npm test
```

Test suite သည် network မသုံးဘဲ health check၊ TikTok URL validation၊ metadata adapter နှင့် streaming response ကို fake adapter ဖြင့် စစ်ဆေးသည်။ Real download ကို စမ်းမည်ဆိုပါက ကိုယ်ပိုင်/ခွင့်ပြုချက်ရှိသော test URL ကိုသာ အသုံးပြုပါ။

## Docker

```bash
docker build -t authorized-tiktok-api-node .
docker run --rm -p 8000:8000 \
  -e API_KEY='replace-with-a-long-random-key' \
  -e RATE_LIMIT_PER_MINUTE=10 \
  authorized-tiktok-api-node
```

## Production notes

`/v1/download` က JSON response ပြန်ပြီး temporary file ကို TTL အတွင်း server တွင်ထားသည်။ Returned `download_url` ကို တစ်ကြိမ် GET လုပ်ပြီးနောက် သို့မဟုတ် TTL ကုန်သွားသောအခါ file ကို ဖျက်သည်။ Traffic တက်လာပါက in-memory rate limit အစား Redis သို့မဟုတ် API gateway rate limiting၊ request queue၊ access logs နှင့် abuse monitoring ထည့်သင့်သည်။ Public service အဖြစ် ထုတ်မည်ဆိုပါက HTTPS၊ authentication နှင့် authorization ထည့်ပြီး content ownership/permission policy ကို ရှင်းလင်းစွာ သတ်မှတ်ပါ။

## References

[1]: https://expressjs.com/ "Express official documentation"
[2]: https://github.com/yt-dlp/yt-dlp "yt-dlp official repository"
