'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "cccb166becb781a81b23b5da4ebad840",
"main.dart.js": "cba17ce43ac39a3bbe6beb754c9417e2",
"version.json": "3aa7e7044941ffc8fc9d9a4efd551a53",
"assets/assets/icons/app_logo.svg": "297e3e946813a8929924df4b1af42b33",
"assets/assets/icons/app_icon_foreground.png": "5e2e941548156965f1f75af5df79d312",
"assets/assets/icons/app_icon.svg": "b668dcaeac3e7124b5969b4b51e01ff2",
"assets/assets/models/mobilefacenet.tflite": "7945c78f4484c99560df461df85baa2f",
"assets/assets/data/cities.csv": "3410cb7dfcc239b7904fe4c8d2067b5d",
"assets/assets/fonts/Roboto-Regular.ttf": "3e1af3ef546b9e6ecef9f3ba197bf7d2",
"assets/assets/fonts/Lora-Regular.ttf": "5016349e9de4b2eeac85fa2ed374f7fe",
"assets/assets/fonts/Lora-Italic.ttf": "0670dad11a0ba7369fccb78df6ac4ac5",
"assets/assets/fonts/Lora-Medium.ttf": "2c51d6c8fcac3ab587d74ec725c35c27",
"assets/assets/fonts/Lora-Bold.ttf": "0cf62064521fb6e70f3ca2d6e37acab3",
"assets/assets/fonts/Nunito-Regular.ttf": "c15a3de8622bea5de54f467141bc2521",
"assets/assets/fonts/Nunito-Medium.ttf": "92de69d6e4bac55d23b48b67ade9c225",
"assets/assets/fonts/Nunito-SemiBold.ttf": "33c704d4567fb8a57c7b1acb6fd658c0",
"assets/assets/fonts/Nunito-Bold.ttf": "fcd0055ad3f85db1b8ce73018ba8b7c6",
"assets/assets/fonts/VT323-Regular.ttf": "d55abc3c7d1a4719dea9fa15ccec203f",
"assets/assets/fonts/PressStart2P-Regular.ttf": "ccb1dfce06ad3883f8e3b5ae011aa795",
"assets/assets/fonts/RobotoMono-Regular.ttf": "5000180e7bc4c8d5e0ba7518ca65b759",
"assets/assets/fonts/RobotoMono-Bold.ttf": "138e33963420abccc79b5c66abeaa17d",
"assets/fonts/MaterialIcons-Regular.otf": "59c3f6d8697b708482e07ae0f6d0a245",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/AssetManifest.bin": "c00446f89c06941f40bbc3ba404666b2",
"assets/AssetManifest.bin.json": "30b619c14329d85c0f66f2381d8315a4",
"assets/FontManifest.json": "566446ed6cb2cc0c774ebc7715f413e5",
"assets/NOTICES": "d3b0dcbe5b744c1fc5bc54006dbbdd4e",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "080b0a85b21cd684049f3c1b30aa61d6",
"icons/Icon-512.png": "f0d5ecf30027c578b95875ce89f49adc",
"icons/Icon-maskable-192.png": "080b0a85b21cd684049f3c1b30aa61d6",
"icons/Icon-maskable-512.png": "f0d5ecf30027c578b95875ce89f49adc",
"coi-serviceworker.js": "902c9f8996ee3fc394fc8d22af5ae2eb",
"manifest.json": "5c8e7a30204b8b14e21642d797ce5a6e",
"ffmpeg/ffmpeg.js": "6e53d5d371ee2dbbeffda5e840dc2df1",
"ffmpeg/814.ffmpeg.js": "3a3f8f00770ffdd617a1ec22aab1a933",
"ffmpeg/ffmpeg-core.js": "730776f895f9501adb3358e3c1eb98e2",
"ffmpeg/ffmpeg-core.wasm": "895cb9ab6b2455190b57774348a9dda5",
"index.html": "1c2f724af4fd1b5f7df4ff47da842fe0",
"/": "1c2f724af4fd1b5f7df4ff47da842fe0"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
