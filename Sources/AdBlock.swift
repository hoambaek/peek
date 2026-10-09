import Foundation
import WebKit

// 크롬 확장(uBlock 등)은 WKWebView에서 돌지 않는다.
// 대신 Safari 콘텐츠 차단기와 같은 형식(WKContentRuleList)으로 같은 일을 한다.
enum AdBlock {

    static let identifier = "peek-adblock-v4"

    static let rules = #"""
    [
      {
        "trigger": {
          "url-filter": "https?://[^/]*doubleclick\\.net"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*googlesyndication\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*googleadservices\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*adservice\\.google\\."
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*amazon-adsystem\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*scorecardresearch\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*adnxs\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*ads\\.pubmatic\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*imasdk\\.googleapis\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*moatads\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": "https?://[^/]*adsafeprotected\\.com"
        },
        "action": {
          "type": "block"
        }
      },
      {
        "trigger": {
          "url-filter": ".*",
          "if-domain": [
            "*youtube.com"
          ]
        },
        "action": {
          "type": "css-display-none",
          "selector": "#player-ads, #masthead-ad, ytd-display-ad-renderer, ytd-promoted-sparkles-web-renderer, ytd-promoted-video-renderer, ytd-ad-slot-renderer, ytd-in-feed-ad-layout-renderer, ytd-banner-promo-renderer, ytd-statement-banner-renderer, .ytp-ad-overlay-container, .ytp-ad-message-container, .ytd-companion-slot-renderer"
        }
      },
      {
        "trigger": {
          "url-filter": ".*",
          "if-domain": [
            "*twitch.tv"
          ]
        },
        "action": {
          "type": "css-display-none",
          "selector": "[data-a-target='video-ad-label'], [data-a-target='video-ad-countdown'], .video-player__ad-info-container"
        }
      }
    ]
    """#

    // 유튜브 광고의 본체는 네트워크가 아니라 player 응답 안의 adPlacements/playerAds 다.
    // 요청을 막으면 차단 감지에 걸리므로, 막지 않고 응답에서 광고 항목만 지운다.
    // documentStart 에 넣어야 유튜브 인라인 스크립트보다 먼저 후크가 걸린다.
    static let skipScript = #"""
    (function () {
      if (!/(^|\.)youtube\.com$/.test(location.hostname)) return;
      if (window.__peekAds) return;
      window.__peekAds = true;

      var AD_KEYS = ['adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams',
                     'adParams', 'importantForAds', 'adEngagementPanels'];

      function scrub(o) {
        if (!o || typeof o !== 'object') return o;
        for (var i = 0; i < AD_KEYS.length; i++) {
          if (AD_KEYS[i] in o) { try { delete o[AD_KEYS[i]]; } catch (e) {} }
        }
        if (o.playerResponse) scrub(o.playerResponse);
        if (o.player && o.player.args) scrub(o.player.args);
        return o;
      }

      // player 응답처럼 생긴 것만 훑는다. 모든 JSON을 깊이 도는 건 유튜브에서 너무 무겁다.
      function maybe(o) {
        if (o && typeof o === 'object' &&
            (o.streamingData || o.playerResponse || o.adPlacements || o.playerAds)) scrub(o);
        return o;
      }

      var origParse = JSON.parse;
      JSON.parse = function () { return maybe(origParse.apply(this, arguments)); };

      if (window.Response && Response.prototype.json) {
        var origJson = Response.prototype.json;
        Response.prototype.json = function () { return origJson.apply(this, arguments).then(maybe); };
      }

      var ipr;
      try {
        Object.defineProperty(window, 'ytInitialPlayerResponse', {
          configurable: true,
          get: function () { return ipr; },
          set: function (v) { ipr = maybe(v); }
        });
      } catch (e) {}

      // ---- 화면단 보조: 빠져나온 광고를 즉시 넘긴다 ----

      var SKIP = '.ytp-ad-skip-button,.ytp-ad-skip-button-modern,.ytp-skip-ad-button,' +
                 '.ytp-ad-survey-answer-button,.ytp-ad-skip-button-container button';

      function tick() {
        try {
          // 차단 감지 안내창이 떠 있으면 손대지 않는다. 건드리면 재생이 막힌다.
          if (document.querySelector('ytd-enforcement-message-view-model')) return;

          var s = document.querySelector(SKIP);
          if (s) { s.click(); return; }

          var close = document.querySelector('.ytp-ad-overlay-close-button');
          if (close) close.click();

          var p = document.querySelector('#movie_player,.html5-video-player');
          if (p && p.classList.contains('ad-showing')) {
            var v = p.querySelector('video');
            if (v && isFinite(v.duration) && v.duration > 0 && v.currentTime < v.duration - 0.3) {
              v.currentTime = v.duration;
              var pr = v.play();
              if (pr && pr.catch) pr.catch(function () {});
            }
          }
        } catch (e) {}
      }

      function start() {
        tick();
        try {
          new MutationObserver(tick).observe(document.documentElement, {
            childList: true, subtree: true, attributes: true, attributeFilter: ['class']
          });
        } catch (e) {}
        setInterval(tick, 500);
        document.addEventListener('yt-navigate-finish', tick);
      }

      if (document.documentElement) start();
      else document.addEventListener('DOMContentLoaded', start);
    })();
    """#

    static func compile(_ done: @escaping (WKContentRuleList?) -> Void) {
        guard let store = WKContentRuleListStore.default() else { done(nil); return }
        store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: rules) { list, error in
            if let error { NSLog("[peek] adblock compile failed: \(error.localizedDescription)") }
            DispatchQueue.main.async { done(list) }
        }
    }
}
