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
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let contentController = WKUserContentController()
        contentController.add(self, name: "audioBridge")
        
        // Injected background playback script across all frames
        let backgroundScriptSource = """
        (function () {
            if (window.__bgPlaybackInstalled) { return; }
            window.__bgPlaybackInstalled = true;

            // Keep document reporting visible
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

            function swallow(event) {
                event.stopImmediatePropagation();
            }
            window.addEventListener('visibilitychange', swallow, true);
            document.addEventListener('visibilitychange', swallow, true);
            window.addEventListener('webkitvisibilitychange', swallow, true);
            document.addEventListener('webkitvisibilitychange', swallow, true);
            window.addEventListener('blur', swallow, true);
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
    
    func attachToRootWindow() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.attachToRootWindow()
                }
                return
            }
            
            if let wv = self.webView, wv.superview != window {
                wv.removeFromSuperview()
                wv.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
                wv.alpha = 0.01
                wv.isUserInteractionEnabled = false
                window.addSubview(wv)
                print("[YouTubeAudioBridge] Attached permanently to root UIWindow!")
            }
        }
    }
    
    private func observeLifecycle() {
        let center = NotificationCenter.default
        
        center.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.keepPlayingInBackground()
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
                _ = try? await self.webView?.evaluateJavaScript("""
                if (typeof player !== 'undefined' && player.playVideo) {
                    if (typeof player.getPlayerState === 'function' && player.getPlayerState() !== 1) {
                        player.playVideo();
                    }
                }
                """)
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
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
            // Anti-Pause on tab switch / minimize: If user didn't ask to pause, resume immediately and don't notify Swift
            if (event.data === 2 && !userWantsPause) {
              if (player && player.playVideo) {
                player.playVideo();
              }
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
            userWantsPause = false;
            if (player && player.playVideo) player.playVideo();
          };

          window.userPause = function() {
            userWantsPause = true;
            if (player && player.pauseVideo) player.pauseVideo();
          };

          window.swapTrack = function(newVid, keepSeconds) {
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
        webView?.evaluateJavaScript("if (typeof window.userPlay !== 'undefined') { window.userPlay(); } else if (typeof player !== 'undefined' && player.playVideo) { player.playVideo(); }", completionHandler: nil)
    }
    
    func pause() {
        webView?.evaluateJavaScript("if (typeof window.userPause !== 'undefined') { window.userPause(); } else if (typeof player !== 'undefined' && player.pauseVideo) { player.pauseVideo(); }", completionHandler: nil)
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
                        AudioPlayerManager.shared.isLoading = false
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
