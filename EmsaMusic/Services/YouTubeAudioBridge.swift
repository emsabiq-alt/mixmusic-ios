import Foundation
import WebKit
import SwiftUI
import UIKit
import AVFoundation

class YouTubeAudioBridge: NSObject, ObservableObject, WKScriptMessageHandler {
    static let shared = YouTubeAudioBridge()
    
    var webView: WKWebView?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    override init() {
        super.init()
        setupWebView()
        observeLifecycle()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "audioBridge")
        
        // Proven multi-layer background audio script (injected into all frames)
        let backgroundScriptSource = """
        (function () {
            if (window.__bgPlaybackInstalled) { return; }
            window.__bgPlaybackInstalled = true;

            var hiddenAt = 0;
            var wasPlaying = false;
            window.isUserPause = false;

            function currentVideo() {
                return document.querySelector('video');
            }

            function define(target, name, value) {
                try {
                    Object.defineProperty(target, name, { get: function () { return value; }, configurable: true });
                } catch (e) {}
            }
            define(Document.prototype, 'hidden', false);
            define(Document.prototype, 'webkitHidden', false);
            define(Document.prototype, 'visibilityState', 'visible');
            define(Document.prototype, 'webkitVisibilityState', 'visible');
            try {
                Document.prototype.hasFocus = function () { return true; };
            } catch (e) {}

            window.__bgCapture = function () {
                var video = currentVideo();
                hiddenAt = Date.now();
                wasPlaying = !window.isUserPause && !!(video && !video.paused && !video.ended);
            };

            window.__bgResume = function () {
                if (window.isUserPause) { return; }
                var video = currentVideo();
                if (video && video.paused && !video.ended) {
                    var p = video.play();
                    if (p && p.catch) { p.catch(function () {}); }
                }
                if (typeof player !== 'undefined' && player.playVideo && player.getPlayerState && player.getPlayerState() !== 1) {
                    player.playVideo();
                }
            };

            window.addEventListener('blur', function (event) {
                event.stopImmediatePropagation();
            }, true);

            function swallow(event) {
                var video = currentVideo();
                hiddenAt = Date.now();
                if (video && !video.paused && !video.ended) { wasPlaying = true; }
                event.stopImmediatePropagation();
            }
            window.addEventListener('visibilitychange', swallow, true);
            document.addEventListener('visibilitychange', swallow, true);
            window.addEventListener('webkitvisibilitychange', swallow, true);
            document.addEventListener('webkitvisibilitychange', swallow, true);
            window.addEventListener('pagehide', function (event) {
                var video = currentVideo();
                hiddenAt = Date.now();
                wasPlaying = !window.isUserPause && !!(video && !video.paused && !video.ended);
            }, true);

            // Instant auto-resume if iOS tries to pause media when user didn't request pause
            document.addEventListener('pause', function (event) {
                if (window.isUserPause) { return; }
                var video = event.target;
                if (!video || video.tagName !== 'VIDEO') { return; }
                var resume = function () {
                    if (!window.isUserPause) {
                        var p = video.play();
                        if (p && p.catch) { p.catch(function () {}); }
                    }
                };
                resume();
            }, true);
        })();
        """
        let userScript = WKUserScript(source: backgroundScriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        config.userContentController = contentController
        
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 180), configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        self.webView = wv
    }
    
    private func observeLifecycle() {
        let center = NotificationCenter.default
        
        center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.webView?.evaluateJavaScript("window.__bgCapture && window.__bgCapture();", completionHandler: nil)
        }
        
        center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.keepPlayingInBackground()
        }
    }
    
    private func keepPlayingInBackground() {
        guard AudioPlayerManager.shared.isPlaying else { return }
        
        try? AVAudioSession.sharedInstance().setActive(true)
        endBackgroundTask()
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "EmsaMusicBackgroundAudio") { [weak self] in
            self?.endBackgroundTask()
        }
        
        Task { [weak self] in
            for _ in 0..<15 {
                guard let self = self, AudioPlayerManager.shared.isPlaying else { break }
                _ = try? await self.webView?.evaluateJavaScript("window.__bgResume && window.__bgResume();")
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    func loadVideo(videoId: String, startTime: TimeInterval = 0) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>body { margin: 0; background: #000; overflow: hidden; }</style>
        </head>
        <body>
        <div id="player"></div>
        <script>
          var tag = document.createElement('script');
          tag.src = "https://www.youtube.com/iframe_api";
          var firstScriptTag = document.getElementsByTagName('script')[0];
          firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

          var player;
          var userWantsPause = false;

          function onYouTubeIframeAPIReady() {
            player = new YT.Player('player', {
              height: '100%',
              width: '100%',
              videoId: '\(videoId)',
              playerVars: {
                'playsinline': 1,
                'autoplay': 1,
                'controls': 0,
                'disablekb': 1,
                'fs': 0,
                'rel': 0,
                'start': Math.floor(\(startTime)),
                'modestbranding': 1,
                'origin': 'https://music.youtube.com'
              },
              events: {
                'onReady': onPlayerReady,
                'onStateChange': onPlayerStateChange,
                'onError': onPlayerError
              }
            });
          }

          function onPlayerReady(event) {
            userWantsPause = false;
            window.isUserPause = false;
            event.target.playVideo();
            window.webkit.messageHandlers.audioBridge.postMessage({
              type: "ready",
              duration: player.getDuration()
            });
            setInterval(function() {
              if (player && player.getCurrentTime) {
                window.webkit.messageHandlers.audioBridge.postMessage({
                  type: "timeUpdate",
                  currentTime: player.getCurrentTime(),
                  duration: player.getDuration()
                });
              }
            }, 250);
          }

          function onPlayerStateChange(event) {
            if (event.data === 2 && !userWantsPause) {
              return;
            }
            window.webkit.messageHandlers.audioBridge.postMessage({
              type: "stateChange",
              state: event.data
            });
          }

          function onPlayerError(event) {
            window.webkit.messageHandlers.audioBridge.postMessage({
              type: "error",
              code: event.data
            });
          }

          window.userPlay = function() {
            window.isUserPause = false;
            userWantsPause = false;
            if (player && player.playVideo) player.playVideo();
          };

          window.userPause = function() {
            window.isUserPause = true;
            userWantsPause = true;
            if (player && player.pauseVideo) player.pauseVideo();
          };

          window.swapTrack = function(newVid, keepSeconds) {
            window.isUserPause = false;
            userWantsPause = false;
            if (player && player.loadVideoById) {
              player.loadVideoById({
                videoId: newVid,
                startSeconds: Math.floor(keepSeconds || 0)
              });
              player.playVideo();
            }
          };
        </script>
        </body>
        </html>
        """
        webView?.loadHTMLString(html, baseURL: URL(string: "https://music.youtube.com"))
    }
    
    func play() {
        webView?.evaluateJavaScript("""
        window.isUserPause = false;
        if (typeof window.userPlay !== 'undefined') { window.userPlay(); }
        else if (typeof player !== 'undefined' && player.playVideo) { player.playVideo(); }
        """, completionHandler: nil)
    }
    
    func pause() {
        webView?.evaluateJavaScript("""
        window.isUserPause = true;
        if (typeof window.userPause !== 'undefined') { window.userPause(); }
        else if (typeof player !== 'undefined' && player.pauseVideo) { player.pauseVideo(); }
        """, completionHandler: nil)
    }
    
    func seek(to seconds: TimeInterval) {
        webView?.evaluateJavaScript("if (typeof player !== 'undefined' && player.seekTo) { player.seekTo(\(seconds), true); }", completionHandler: nil)
    }
    
    func setPlaybackRate(_ rate: Float) {
        webView?.evaluateJavaScript("if (typeof player !== 'undefined' && player.setPlaybackRate) { player.setPlaybackRate(\(rate)); }", completionHandler: nil)
    }
    
    func swapToInstrumental(videoId: String, atTime: TimeInterval) {
        webView?.evaluateJavaScript("if (typeof window.swapTrack !== 'undefined') { window.swapTrack('\(videoId)', \(atTime)); }", completionHandler: nil)
    }
    
    // WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "ready":
                if let dur = dict["duration"] as? Double, dur > 0 {
                    AudioPlayerManager.shared.duration = dur
                }
                AudioPlayerManager.shared.isLoading = false
                AudioPlayerManager.shared.isPlaying = true
            case "timeUpdate":
                if let cur = dict["currentTime"] as? Double {
                    AudioPlayerManager.shared.currentTime = cur
                }
                if let dur = dict["duration"] as? Double, dur > 0 {
                    AudioPlayerManager.shared.duration = dur
                }
                AudioPlayerManager.shared.onTimeUpdated()
            case "stateChange":
                if let state = dict["state"] as? Int {
                    if state == 1 {
                        AudioPlayerManager.shared.isPlaying = true
                        AudioPlayerManager.shared.isLoading = false
                    } else if state == 2 {
                        AudioPlayerManager.shared.isPlaying = false
                    } else if state == 3 {
                        AudioPlayerManager.shared.isLoading = true
                    } else if state == 0 {
                        AudioPlayerManager.shared.handleTrackEnded()
                    }
                }
            case "error":
                print("[YouTubeAudioBridge] Error code:", dict["code"] ?? "")
                AudioPlayerManager.shared.isLoading = false
            default:
                break
            }
        }
    }
}

struct HeadlessAudioBridgeView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        return YouTubeAudioBridge.shared.webView ?? WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
