{{flutter_js}}
{{flutter_build_config}}

// CanvasKit aus dem eigenen Deployment laden statt vom Google-CDN
// (gstatic) — selbst gehostet, datenschutzfreundlich und offlinefähig.
_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
