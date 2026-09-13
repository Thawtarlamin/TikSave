import { execFile } from "node:child_process";
import { existsSync, promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

function resolveYtdlpBinary() {
  if (process.env.YTDLP_BIN) return process.env.YTDLP_BIN;
  const candidates = [
    path.join(process.cwd(), ".venv", "bin", "yt-dlp"),
    path.join(process.cwd(), ".venv", "Scripts", "yt-dlp.exe"),
    path.join(process.cwd(), "node_modules", ".bin", "yt-dlp"),
    "/usr/local/bin/yt-dlp",
    "/usr/bin/yt-dlp",
  ];
  return candidates.find((candidate) => existsSync(candidate)) || "yt-dlp";
}

const YTDLP_BIN = resolveYtdlpBinary();
const DOWNLOAD_TIMEOUT_MS =
  Number(process.env.DOWNLOAD_TIMEOUT_SECONDS || 120) * 1000;
const MAX_DOWNLOAD_BYTES = Number(
  process.env.MAX_DOWNLOAD_BYTES || 250 * 1024 * 1024,
);
const COOKIES_FILE = process.env.YTDLP_COOKIES_FILE;

function ytdlpMaxFilesize(bytes) {
  const megabytes = Math.max(1, Math.floor(bytes / (1024 * 1024)));
  return `${megabytes}M`;
}

function commonArgs(url) {
  const args = [
    "--no-playlist",
    "--no-warnings",
    "--quiet",
    "--socket-timeout",
    "20",
    "--retries",
    "2",
    "--no-part",
    url,
  ];
  if (COOKIES_FILE) args.splice(args.length - 1, 0, "--cookies", COOKIES_FILE);
  return args;
}

function compactInfo(info) {
  return {
    id: info.id ?? null,
    title: info.title ?? null,
    uploader: info.uploader ?? info.uploader_id ?? null,
    duration: info.duration ?? null,
    thumbnail: info.thumbnail ?? null,
    webpage_url: info.webpage_url ?? info.original_url ?? null,
    extractor: info.extractor_key ?? info.extractor ?? null,
    is_live: info.is_live ?? null,
    music_url:chooseAudioUrl(info)
  };
}
function chooseAudioUrl(info) {
  const formats = Array.isArray(info.formats) ? info.formats : [];
  const audioOnly = formats
    .filter((format) => format.url && format.vcodec === "none" && format.acodec && format.acodec !== "none")
    .sort((a, b) => Number(b.abr || 0) - Number(a.abr || 0));
  return audioOnly[0]?.url || null;
}
export async function getVideoInfo(url) {
  const args = ["--dump-single-json", "--skip-download", ...commonArgs(url)];
  const { stdout } = await execFileAsync(YTDLP_BIN, args, {
    timeout: DOWNLOAD_TIMEOUT_MS,
    maxBuffer: 8 * 1024 * 1024,
  });
  return compactInfo(JSON.parse(stdout));
}

export async function downloadVideo(url) {
  const outputDir = await fs.mkdtemp(path.join(os.tmpdir(), "tiktok-api-"));
  const outputTemplate = path.join(outputDir, "%(id)s.%(ext)s");
  const args = [
    "-f",
    "bv*+ba/b",
    "--merge-output-format",
    "mp4",
    "--max-filesize",
    ytdlpMaxFilesize(MAX_DOWNLOAD_BYTES),
    "-o",
    outputTemplate,
    ...commonArgs(url),
  ];
  try {
    const { stdout } = await execFileAsync(YTDLP_BIN, args, {
      timeout: DOWNLOAD_TIMEOUT_MS,
      maxBuffer: 8 * 1024 * 1024,
    });
    const entries = await fs.readdir(outputDir, { withFileTypes: true });
    const files = await Promise.all(
      entries
        .filter(
          (entry) =>
            entry.isFile() &&
            !entry.name.endsWith(".part") &&
            !entry.name.endsWith(".ytdl"),
        )
        .map(async (entry) => {
          const fullPath = path.join(outputDir, entry.name);
          const stat = await fs.stat(fullPath);
          return { path: fullPath, name: entry.name, size: stat.size };
        }),
    );
    if (!files.length)
      throw new Error("Downloader completed without producing a media file");
    const media = files.sort((a, b) => b.size - a.size)[0];
    if (media.size > MAX_DOWNLOAD_BYTES)
      throw new Error("The media file exceeds the configured size limit");
    return { ...media, outputDir, stdout };
  } catch (error) {
    await fs.rm(outputDir, { recursive: true, force: true });
    throw error;
  }
}

export async function cleanupOutput(outputDir) {
  await fs.rm(outputDir, { recursive: true, force: true });
}
