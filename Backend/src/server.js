import express from "express";
import { randomUUID } from "node:crypto";
import { createReadStream } from "node:fs";
import { promises as fs } from "node:fs";
import path from "node:path";
import { z } from "zod";

import { cleanupOutput, downloadVideo, getVideoInfo } from "./downloader.js";

const PORT = Number(process.env.PORT || 8000);
const API_KEY = process.env.API_KEY || "";
const RATE_LIMIT_PER_MINUTE = Number(process.env.RATE_LIMIT_PER_MINUTE || 10);
const DOWNLOAD_URL_TTL_SECONDS = Number(
  process.env.DOWNLOAD_URL_TTL_SECONDS || 600,
);
const rateWindows = new Map();
const downloadFiles = new Map();

const requestSchema = z.object({
  url: z
    .string()
    .url()
    .superRefine((value, context) => {
      let parsed;
      try {
        parsed = new URL(value);
      } catch {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Invalid URL",
        });
        return;
      }
      const host = parsed.hostname.toLowerCase().replace(/\.$/, "");
      const allowedHosts = new Set([
        "tiktok.com",
        "www.tiktok.com",
        "m.tiktok.com",
        "vm.tiktok.com",
        "vt.tiktok.com",
      ]);
      if (!allowedHosts.has(host)) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Only TikTok URLs are accepted",
        });
      }
      if (parsed.username || parsed.password) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Credentials in URLs are not accepted",
        });
      }
    }),
});

function requireApiKey(req, res, next) {
  if (API_KEY && req.get("X-API-Key") !== API_KEY) {
    return res.status(401).json({ detail: "Invalid or missing X-API-Key" });
  }
  return next();
}

function rateLimit(req, res, next) {
  const key = req.ip || req.socket.remoteAddress || "unknown";
  const now = Date.now();
  const window = (rateWindows.get(key) || []).filter(
    (timestamp) => now - timestamp < 60_000,
  );
  if (window.length >= RATE_LIMIT_PER_MINUTE) {
    res.set("Retry-After", "60");
    return res
      .status(429)
      .json({ detail: "Rate limit exceeded; try again later" });
  }
  window.push(now);
  rateWindows.set(key, window);
  return next();
}

function parsePayload(req, res, next) {
  const parsed = requestSchema.safeParse(req.body);
  if (!parsed.success) {
    return res.status(422).json({
      detail: parsed.error.issues.map((issue) => issue.message).join("; "),
    });
  }
  req.videoPayload = parsed.data;
  return next();
}

function asErrorDetail(error) {
  if (error?.code === "ETIMEDOUT" || error?.killed) {
    return { status: 504, detail: "Source request timed out" };
  }
  if (error?.code === "ENOENT") {
    return {
      status: 503,
      detail:
        "yt-dlp is not installed or not available. Install yt-dlp, or set YTDLP_BIN to its executable path.",
    };
  }
  return {
    status: 422,
    detail: `Unable to process URL: ${error?.message || "unknown error"}`,
  };
}

function mediaTypeFor(extension) {
  return (
    {
      ".mp4": "video/mp4",
      ".webm": "video/webm",
      ".mov": "video/quicktime",
      ".mkv": "video/x-matroska",
    }[extension] || "application/octet-stream"
  );
}

function safeFilename(name) {
  return String(name).replace(/[^A-Za-z0-9_.-]/g, "_");
}

export function createApp(dependencies = {}) {
  const resolveInfo = dependencies.getVideoInfo || getVideoInfo;
  const resolveDownload = dependencies.downloadVideo || downloadVideo;
  const removeOutput = dependencies.cleanupOutput || cleanupOutput;
  const app = express();

  app.disable("x-powered-by");
  app.set("trust proxy", false);
  app.use(express.json({ limit: "16kb" }));

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      service: "authorized-tiktok-media-api-node",
      watermark_note:
        "The API returns source media when available; it does not remove a watermark from video pixels.",
    });
  });

  app.post(
    "/v1/info",
    requireApiKey,
    rateLimit,
    parsePayload,
    async (req, res) => {
      try {
        const url = req.videoPayload.url;
        const match = url.match(
          /https?:\/\/(?:www\.)?tiktok\.com\/@[^\/\s]+\/video\/\d+/,
        );
        const result = await resolveInfo(match[0]);
        return res.json(result);
      } catch (error) {
        const failure = asErrorDetail(error);
        return res.status(failure.status).json({ detail: failure.detail });
      }
    },
  );

  app.post(
    "/v1/download",
    requireApiKey,
    rateLimit,
    parsePayload,
    async (req, res) => {
      let media;
      try {
        const url = req.videoPayload.url;
        const match = url.match(
          /https?:\/\/(?:www\.)?tiktok\.com\/@[^\/\s]+\/video\/\d+/,
        );
        media = await resolveDownload(match[0]);
        console.log(media);
        const token = randomUUID();
        const extension = path.extname(media.name).toLowerCase() || ".mp4";
        const filename = safeFilename(media.name);
        const expiresAt = Date.now() + DOWNLOAD_URL_TTL_SECONDS * 1000;
        const record = {
          ...media,
          extension,
          filename,
          expiresAt,
          cleaned: false,
        };
        downloadFiles.set(token, record);

        const cleanupExpired = async () => {
          const current = downloadFiles.get(token);
          if (current === record) downloadFiles.delete(token);
          if (!record.cleaned) {
            record.cleaned = true;
            await removeOutput(record.outputDir);
          }
        };
        const timer = setTimeout(
          cleanupExpired,
          DOWNLOAD_URL_TTL_SECONDS * 1000,
        );
        timer.unref?.();

        const baseUrl =
          process.env.PUBLIC_BASE_URL || `${req.protocol}://${req.get("host")}`;
        return res.status(202).json({
          ok: true,
          id: path.parse(media.name).name,
          filename,
          size: media.size,
          download_url: `${baseUrl.replace(/\/$/, "")}/v1/files/${token}`,
          expires_in: DOWNLOAD_URL_TTL_SECONDS,
          expires_at: new Date(expiresAt).toISOString(),
          info:media.info
        });
      } catch (error) {
        if (media?.outputDir) await removeOutput(media.outputDir);
        const failure = asErrorDetail(error);
        return res.status(failure.status).json({ detail: failure.detail });
      }
    },
  );

  app.get("/v1/files/:token", async (req, res) => {
    const record = downloadFiles.get(req.params.token);
    if (!record || record.expiresAt <= Date.now()) {
      if (record && !record.cleaned) {
        record.cleaned = true;
        downloadFiles.delete(req.params.token);
        await removeOutput(record.outputDir);
      }
      return res
        .status(404)
        .json({ detail: "Download URL is invalid or expired" });
    }

    try {
      await fs.access(record.path);
      downloadFiles.delete(req.params.token);
      res.set({
        "Content-Type": mediaTypeFor(record.extension),
        "Content-Length": String(record.size),
        "Content-Disposition": `attachment; filename="${record.filename}"`,
      });
      const stream = createReadStream(record.path);
      const cleanup = async () => {
        if (record.cleaned) return;
        record.cleaned = true;
        await removeOutput(record.outputDir);
      };
      stream.on("error", cleanup);
      res.on("close", cleanup);
      res.on("finish", cleanup);
      return stream.pipe(res);
    } catch (error) {
      if (!record.cleaned) {
        record.cleaned = true;
        downloadFiles.delete(req.params.token);
        await removeOutput(record.outputDir);
      }
      return res
        .status(404)
        .json({ detail: `Download file is unavailable: ${error.message}` });
    }
  });

  app.use((error, _req, res, _next) => {
    if (error?.type === "entity.too.large") {
      return res.status(413).json({ detail: "Request body is too large" });
    }
    return res.status(500).json({ detail: "Internal server error" });
  });

  return app;
}

if (process.env.NODE_ENV !== "test") {
  const app = createApp();
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Authorized TikTok API listening on http://0.0.0.0:${PORT}`);
  });
}
