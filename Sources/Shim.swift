import Foundation

// 창 안에서만 전체화면이 되도록 Fullscreen API를 가로챈다.
// 오버레이(position:fixed)는 transform 걸린 조상 안에 갇히므로,
// 대상의 조상 체인을 100%로 펴고 형제 요소를 숨기는 방식을 쓴다.
enum Shim {
    static let fullscreen = #"""
    (function () {
      if (window.__peekFS) return;
      window.__peekFS = true;

      var CSS = [
        'html.__peek-on,body.__peek-on{width:100%!important;height:100%!important;',
        'margin:0!important;padding:0!important;overflow:hidden!important;background:#000!important;}',
        '.__peek-chain{position:static!important;width:100%!important;height:100%!important;',
        'min-width:0!important;min-height:0!important;max-width:none!important;max-height:none!important;',
        'margin:0!important;padding:0!important;border:0!important;transform:none!important;',
        'overflow:visible!important;float:none!important;display:block!important;}',
        '.__peek-fs{position:relative!important;width:100%!important;height:100%!important;',
        'max-width:none!important;max-height:none!important;margin:0!important;padding:0!important;',
        'left:0!important;top:0!important;transform:none!important;background:#000!important;}',
        '.__peek-fs video{width:100%!important;height:100%!important;left:0!important;top:0!important;',
        'object-fit:contain!important;}',
        '.__peek-fs .html5-video-container,.__peek-fs .video-js,.__peek-fs .html5-video-player,',
        '.__peek-fs #movie_player,.__peek-fs ytd-player,.__peek-fs #player-container,',
        '.__peek-fs #player-container-inner,.__peek-fs #player-theater-container,',
        '.__peek-fs #player-wide-container,.__peek-fs #player{',
        'width:100%!important;height:100%!important;max-width:none!important;max-height:none!important;',
        'min-width:0!important;min-height:0!important;left:0!important;top:0!important;}',
        '.__peek-hide{display:none!important;}'
      ].join('');

      function injectCSS() {
        try {
          if (document.getElementById('__peek-style')) return;
          var s = document.createElement('style');
          s.id = '__peek-style';
          s.textContent = CSS;
          (document.head || document.documentElement).appendChild(s);
        } catch (e) {}
      }

      var current = null;     // 실제로 스타일을 건 요소
      var requested = null;   // 사이트가 요청한 요소 (바깥에 이걸 보고한다)
      var chain = [];
      var hidden = [];

      // 유튜브 등은 전체화면일 때 창이 아니라 screen 크기로 플레이어를 잡는다.
      // 가짜 전체화면 동안에는 screen이 창 크기라고 답하게 한다.
      var realScreen = {
        width: screen.width, height: screen.height,
        availWidth: screen.availWidth, availHeight: screen.availHeight
      };
      ['width', 'height', 'availWidth', 'availHeight'].forEach(function (k) {
        var horizontal = (k === 'width' || k === 'availWidth');
        try {
          Object.defineProperty(screen, k, {
            configurable: true,
            get: function () {
              if (!requested) return realScreen[k];
              return horizontal ? window.innerWidth : window.innerHeight;
            }
          });
        } catch (e) {}
      });

      function fire() {
        ['fullscreenchange', 'webkitfullscreenchange', 'mozfullscreenchange'].forEach(function (t) {
          try { document.dispatchEvent(new Event(t, { bubbles: true })); } catch (e) {}
          if (requested) { try { requested.dispatchEvent(new Event(t, { bubbles: true })); } catch (e) {} }
        });
        // 플레이어가 비동기로 크기를 다시 잡는 경우가 있어 몇 번 더 알린다
        [0, 60, 200, 500].forEach(function (d) {
          setTimeout(function () { try { window.dispatchEvent(new Event('resize')); } catch (e) {} }, d);
        });
      }

      function unwind() {
        hidden.forEach(function (n) { n.classList.remove('__peek-hide'); });
        chain.forEach(function (n) { n.classList.remove('__peek-chain'); });
        hidden = [];
        chain = [];
        if (current) current.classList.remove('__peek-fs');
        document.documentElement.classList.remove('__peek-on');
        if (document.body) document.body.classList.remove('__peek-on');
      }

      // 유튜브는 <html>을 전체화면으로 요청한다. 그대로 두면 플레이어가 커지지 않으므로
      // 실제 플레이어 컨테이너로 바꿔서 채운다.
      function resolveTarget(el) {
        if (el === document.documentElement || el === document.body) {
          var v = largestVideo();
          if (v) return playerRoot(v);
        }
        return el;
      }

      function enter(el) {
        injectCSS();
        requested = el;
        el = resolveTarget(el);
        if (current === el) { fire(); return Promise.resolve(); }
        if (current) unwind();
        current = el;
        el.classList.add('__peek-fs');

        var node = el;
        var guard = 0;
        while (node && node.parentElement && guard < 60) {
          var parent = node.parentElement;
          var kids = parent.children;
          for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (c !== node && !c.classList.contains('__peek-hide')) {
              c.classList.add('__peek-hide');
              hidden.push(c);
            }
          }
          if (parent !== document.body && parent !== document.documentElement) {
            parent.classList.add('__peek-chain');
            chain.push(parent);
          }
          node = parent;
          guard++;
          if (parent === document.documentElement) break;
        }

        document.documentElement.classList.add('__peek-on');
        if (document.body) document.body.classList.add('__peek-on');
        fire();
        return Promise.resolve();
      }

      function exit() {
        unwind();
        current = null;
        requested = null;
        fire();
        return Promise.resolve();
      }

      var P = Element.prototype;
      P.requestFullscreen = function () { return enter(this); };
      P.webkitRequestFullscreen = P.requestFullscreen;
      P.webkitRequestFullScreen = P.requestFullscreen;
      P.mozRequestFullScreen = P.requestFullscreen;
      P.msRequestFullscreen = P.requestFullscreen;

      if (window.HTMLVideoElement) {
        HTMLVideoElement.prototype.webkitEnterFullscreen = function () { return enter(this); };
        HTMLVideoElement.prototype.webkitEnterFullScreen = HTMLVideoElement.prototype.webkitEnterFullscreen;
        HTMLVideoElement.prototype.webkitExitFullscreen = function () { return exit(); };
        HTMLVideoElement.prototype.webkitExitFullScreen = HTMLVideoElement.prototype.webkitExitFullscreen;
      }

      document.exitFullscreen = exit;
      document.webkitExitFullscreen = exit;
      document.webkitCancelFullScreen = exit;
      document.mozCancelFullScreen = exit;

      function def(name, getter) {
        try { Object.defineProperty(document, name, { get: getter, configurable: true }); } catch (e) {}
      }
      def('fullscreenElement', function () { return requested; });
      def('webkitFullscreenElement', function () { return requested; });
      def('webkitCurrentFullScreenElement', function () { return requested; });
      def('mozFullScreenElement', function () { return requested; });
      def('fullscreenEnabled', function () { return true; });
      def('webkitFullscreenEnabled', function () { return true; });
      def('webkitIsFullScreen', function () { return !!requested; });
      def('mozFullScreen', function () { return !!requested; });

      // ---- 툴바 「영상만 채우기」 ----

      var FS_BUTTONS = [
        '.ytp-fullscreen-button',
        'button[aria-label*="전체화면"]', 'button[aria-label*="전체 화면"]',
        'button[aria-label*="Fullscreen"]', 'button[aria-label*="full screen"]',
        'button[title*="전체화면"]', 'button[title*="Fullscreen"]',
        '.bmpui-ui-fullscreentogglebutton', '.vjs-fullscreen-control',
        '[data-uia="control-fullscreen-enter"]', '[data-uia="control-fullscreen-exit"]',
        '.pzp-pc__fullscreen-button', '.player-fullscreen', '.btn_fullscreen'
      ];

      var PLAYER_ROOTS = [
        '#movie_player', '.html5-video-player', '.bmpui-ui-uicontainer', '.video-js',
        '.watch-video', '.webplayer-internal-video-container', '[data-uia="player"]',
        '.pzp-pc', '.player-container', '#player'
      ];

      function largestVideo() {
        var best = null, area = -1;
        document.querySelectorAll('video').forEach(function (v) {
          var r = v.getBoundingClientRect();
          var a = r.width * r.height;
          if (a > area) { area = a; best = v; }
        });
        return best;
      }

      function siteButton() {
        for (var i = 0; i < FS_BUTTONS.length; i++) {
          try {
            var b = document.querySelector(FS_BUTTONS[i]);
            if (b && b.offsetParent !== null) return b;
          } catch (e) {}
        }
        return null;
      }

      function playerRoot(v) {
        for (var i = 0; i < PLAYER_ROOTS.length; i++) {
          try {
            var r = document.querySelector(PLAYER_ROOTS[i]);
            if (r && r.contains(v)) return r;
          } catch (e) {}
        }
        var el = v, p = v.parentElement, vr = v.getBoundingClientRect(), depth = 0;
        while (p && p !== document.body && depth < 8) {
          var pr = p.getBoundingClientRect();
          if (pr.width > vr.width * 1.6 || pr.height > vr.height * 1.6) break;
          el = p; p = p.parentElement; depth++;
        }
        return el;
      }

      window.__peekToggleVideoFS = function () {
        if (requested) { exit(); return 'off'; }
        var v = largestVideo();
        if (!v) {
          var b = siteButton();
          if (b) { b.click(); return 'on-site'; }
          return 'novideo';
        }
        enter(playerRoot(v));
        return 'on';
      };

      window.__peekState = function () {
        return JSON.stringify({
          fs: !!requested,
          tag: current ? (current.tagName + '.' + (current.className || '').toString().slice(0, 60)) : null,
          videos: document.querySelectorAll('video').length,
          chain: chain.length, hidden: hidden.length
        });
      };
    })();
    """#
}
