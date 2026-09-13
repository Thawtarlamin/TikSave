import assert from "node:assert/strict";
import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import request from "supertest";

process.env.NODE_ENV = "test";
const { createApp } = await import("../src/server.js");

const fakeDownload = async () => {
  const outputDir = await fs.mkdtemp(path.join(os.tmpdir(), "node-tiktok-test-"));
  const mediaPath = path.join(outputDir, "abc123.mp4");
  await fs.writeFile(mediaPath, Buffer.from("fake-video"));
  return { path: mediaPath, name: "abc123.mp4", size: 10, outputDir };
};

const testApp = createApp({
  getVideoInfo: async () => ({
    id: "abc123",
    title: "Authorized test video",
    uploader: "test-creator",
    duration: 3,
    thumbnail: null,
    webpage_url: "https://www.tiktok.com/@test/video/abc123",
    extractor: "TikTok",
    is_live: false,
  }),
  downloadVideo: fakeDownload,
  cleanupOutput: async (outputDir) => fs.rm(outputDir, { recursive: true, force: true }),
});

test("GET /health returns ok", async () => {
  const response = await request(testApp).get("/health");
  assert.equal(response.status, 200);
  assert.equal(response.body.status, "ok");
});

test("POST /v1/info rejects non-TikTok URLs", async () => {
  const response = await request(testApp)
    .post("/v1/info")
    .send({ url: "https://example.com/video" });
  assert.equal(response.status, 422);
});

test("POST /v1/info returns metadata through the adapter", async () => {
  const response = await request(testApp)
    .post("/v1/info")
    .send({ url: "https://www.tiktok.com/@test/video/abc123" });
  assert.equal(response.status, 200);
  assert.equal(response.body.id, "abc123");
});

test("POST /v1/download returns JSON instead of a media stream", async () => {
  const response = await request(testApp)
    .post("/v1/download")
    .send({ url: "https://www.tiktok.com/@test/video/abc123" });
  assert.equal(response.status, 202);
  assert.equal(response.headers["content-type"].startsWith("application/json"), true);
  assert.equal(response.body.ok, true);
  assert.match(response.body.download_url, /\/v1\/files\/[0-9a-f-]+$/);
  assert.equal(response.body.filename, "abc123.mp4");
});

test("download_url streams the temporary media file once", async () => {
  const createResponse = await request(testApp)
    .post("/v1/download")
    .send({ url: "https://www.tiktok.com/@test/video/abc123" });
  const downloadPath = new URL(createResponse.body.download_url).pathname;
  const response = await request(testApp).get(downloadPath);
  assert.equal(response.status, 200);
  assert.equal(response.headers["content-type"], "video/mp4");
  assert.equal(response.body.toString(), "fake-video");

  const secondResponse = await request(testApp).get(downloadPath);
  assert.equal(secondResponse.status, 404);
});
