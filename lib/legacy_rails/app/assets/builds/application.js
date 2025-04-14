(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __require = /* @__PURE__ */ ((x) => typeof require !== "undefined" ? require : typeof Proxy !== "undefined" ? new Proxy(x, {
    get: (a, b) => (typeof require !== "undefined" ? require : a)[b]
  }) : x)(function(x) {
    if (typeof require !== "undefined")
      return require.apply(this, arguments);
    throw new Error('Dynamic require of "' + x + '" is not supported');
  });
  var __esm = (fn2, res) => function __init() {
    return fn2 && (res = (0, fn2[__getOwnPropNames(fn2)[0]])(fn2 = 0)), res;
  };
  var __commonJS = (cb, mod) => function __require2() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));
  var __publicField = (obj, key, value) => {
    __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
    return value;
  };

  // node_modules/@rails/actioncable/src/adapters.js
  var adapters_default;
  var init_adapters = __esm({
    "node_modules/@rails/actioncable/src/adapters.js"() {
      adapters_default = {
        logger: self.console,
        WebSocket: self.WebSocket
      };
    }
  });

  // node_modules/@rails/actioncable/src/logger.js
  var logger_default;
  var init_logger = __esm({
    "node_modules/@rails/actioncable/src/logger.js"() {
      init_adapters();
      logger_default = {
        log(...messages) {
          if (this.enabled) {
            messages.push(Date.now());
            adapters_default.logger.log("[ActionCable]", ...messages);
          }
        }
      };
    }
  });

  // node_modules/@rails/actioncable/src/connection_monitor.js
  var now, secondsSince, ConnectionMonitor, connection_monitor_default;
  var init_connection_monitor = __esm({
    "node_modules/@rails/actioncable/src/connection_monitor.js"() {
      init_logger();
      now = () => new Date().getTime();
      secondsSince = (time) => (now() - time) / 1e3;
      ConnectionMonitor = class {
        constructor(connection) {
          this.visibilityDidChange = this.visibilityDidChange.bind(this);
          this.connection = connection;
          this.reconnectAttempts = 0;
        }
        start() {
          if (!this.isRunning()) {
            this.startedAt = now();
            delete this.stoppedAt;
            this.startPolling();
            addEventListener("visibilitychange", this.visibilityDidChange);
            logger_default.log(`ConnectionMonitor started. stale threshold = ${this.constructor.staleThreshold} s`);
          }
        }
        stop() {
          if (this.isRunning()) {
            this.stoppedAt = now();
            this.stopPolling();
            removeEventListener("visibilitychange", this.visibilityDidChange);
            logger_default.log("ConnectionMonitor stopped");
          }
        }
        isRunning() {
          return this.startedAt && !this.stoppedAt;
        }
        recordPing() {
          this.pingedAt = now();
        }
        recordConnect() {
          this.reconnectAttempts = 0;
          this.recordPing();
          delete this.disconnectedAt;
          logger_default.log("ConnectionMonitor recorded connect");
        }
        recordDisconnect() {
          this.disconnectedAt = now();
          logger_default.log("ConnectionMonitor recorded disconnect");
        }
        startPolling() {
          this.stopPolling();
          this.poll();
        }
        stopPolling() {
          clearTimeout(this.pollTimeout);
        }
        poll() {
          this.pollTimeout = setTimeout(
            () => {
              this.reconnectIfStale();
              this.poll();
            },
            this.getPollInterval()
          );
        }
        getPollInterval() {
          const { staleThreshold, reconnectionBackoffRate } = this.constructor;
          const backoff = Math.pow(1 + reconnectionBackoffRate, Math.min(this.reconnectAttempts, 10));
          const jitterMax = this.reconnectAttempts === 0 ? 1 : reconnectionBackoffRate;
          const jitter = jitterMax * Math.random();
          return staleThreshold * 1e3 * backoff * (1 + jitter);
        }
        reconnectIfStale() {
          if (this.connectionIsStale()) {
            logger_default.log(`ConnectionMonitor detected stale connection. reconnectAttempts = ${this.reconnectAttempts}, time stale = ${secondsSince(this.refreshedAt)} s, stale threshold = ${this.constructor.staleThreshold} s`);
            this.reconnectAttempts++;
            if (this.disconnectedRecently()) {
              logger_default.log(`ConnectionMonitor skipping reopening recent disconnect. time disconnected = ${secondsSince(this.disconnectedAt)} s`);
            } else {
              logger_default.log("ConnectionMonitor reopening");
              this.connection.reopen();
            }
          }
        }
        get refreshedAt() {
          return this.pingedAt ? this.pingedAt : this.startedAt;
        }
        connectionIsStale() {
          return secondsSince(this.refreshedAt) > this.constructor.staleThreshold;
        }
        disconnectedRecently() {
          return this.disconnectedAt && secondsSince(this.disconnectedAt) < this.constructor.staleThreshold;
        }
        visibilityDidChange() {
          if (document.visibilityState === "visible") {
            setTimeout(
              () => {
                if (this.connectionIsStale() || !this.connection.isOpen()) {
                  logger_default.log(`ConnectionMonitor reopening stale connection on visibilitychange. visibilityState = ${document.visibilityState}`);
                  this.connection.reopen();
                }
              },
              200
            );
          }
        }
      };
      ConnectionMonitor.staleThreshold = 6;
      ConnectionMonitor.reconnectionBackoffRate = 0.15;
      connection_monitor_default = ConnectionMonitor;
    }
  });

  // node_modules/@rails/actioncable/src/internal.js
  var internal_default;
  var init_internal = __esm({
    "node_modules/@rails/actioncable/src/internal.js"() {
      internal_default = {
        "message_types": {
          "welcome": "welcome",
          "disconnect": "disconnect",
          "ping": "ping",
          "confirmation": "confirm_subscription",
          "rejection": "reject_subscription"
        },
        "disconnect_reasons": {
          "unauthorized": "unauthorized",
          "invalid_request": "invalid_request",
          "server_restart": "server_restart"
        },
        "default_mount_path": "/cable",
        "protocols": [
          "actioncable-v1-json",
          "actioncable-unsupported"
        ]
      };
    }
  });

  // node_modules/@rails/actioncable/src/connection.js
  var message_types, protocols, supportedProtocols, indexOf, Connection, connection_default;
  var init_connection = __esm({
    "node_modules/@rails/actioncable/src/connection.js"() {
      init_adapters();
      init_connection_monitor();
      init_internal();
      init_logger();
      ({ message_types, protocols } = internal_default);
      supportedProtocols = protocols.slice(0, protocols.length - 1);
      indexOf = [].indexOf;
      Connection = class {
        constructor(consumer2) {
          this.open = this.open.bind(this);
          this.consumer = consumer2;
          this.subscriptions = this.consumer.subscriptions;
          this.monitor = new connection_monitor_default(this);
          this.disconnected = true;
        }
        send(data) {
          if (this.isOpen()) {
            this.webSocket.send(JSON.stringify(data));
            return true;
          } else {
            return false;
          }
        }
        open() {
          if (this.isActive()) {
            logger_default.log(`Attempted to open WebSocket, but existing socket is ${this.getState()}`);
            return false;
          } else {
            logger_default.log(`Opening WebSocket, current state is ${this.getState()}, subprotocols: ${protocols}`);
            if (this.webSocket) {
              this.uninstallEventHandlers();
            }
            this.webSocket = new adapters_default.WebSocket(this.consumer.url, protocols);
            this.installEventHandlers();
            this.monitor.start();
            return true;
          }
        }
        close({ allowReconnect } = { allowReconnect: true }) {
          if (!allowReconnect) {
            this.monitor.stop();
          }
          if (this.isOpen()) {
            return this.webSocket.close();
          }
        }
        reopen() {
          logger_default.log(`Reopening WebSocket, current state is ${this.getState()}`);
          if (this.isActive()) {
            try {
              return this.close();
            } catch (error2) {
              logger_default.log("Failed to reopen WebSocket", error2);
            } finally {
              logger_default.log(`Reopening WebSocket in ${this.constructor.reopenDelay}ms`);
              setTimeout(this.open, this.constructor.reopenDelay);
            }
          } else {
            return this.open();
          }
        }
        getProtocol() {
          if (this.webSocket) {
            return this.webSocket.protocol;
          }
        }
        isOpen() {
          return this.isState("open");
        }
        isActive() {
          return this.isState("open", "connecting");
        }
        isProtocolSupported() {
          return indexOf.call(supportedProtocols, this.getProtocol()) >= 0;
        }
        isState(...states) {
          return indexOf.call(states, this.getState()) >= 0;
        }
        getState() {
          if (this.webSocket) {
            for (let state in adapters_default.WebSocket) {
              if (adapters_default.WebSocket[state] === this.webSocket.readyState) {
                return state.toLowerCase();
              }
            }
          }
          return null;
        }
        installEventHandlers() {
          for (let eventName in this.events) {
            const handler = this.events[eventName].bind(this);
            this.webSocket[`on${eventName}`] = handler;
          }
        }
        uninstallEventHandlers() {
          for (let eventName in this.events) {
            this.webSocket[`on${eventName}`] = function() {
            };
          }
        }
      };
      Connection.reopenDelay = 500;
      Connection.prototype.events = {
        message(event) {
          if (!this.isProtocolSupported()) {
            return;
          }
          const { identifier, message, reason, reconnect, type } = JSON.parse(event.data);
          switch (type) {
            case message_types.welcome:
              this.monitor.recordConnect();
              return this.subscriptions.reload();
            case message_types.disconnect:
              logger_default.log(`Disconnecting. Reason: ${reason}`);
              return this.close({ allowReconnect: reconnect });
            case message_types.ping:
              return this.monitor.recordPing();
            case message_types.confirmation:
              this.subscriptions.confirmSubscription(identifier);
              return this.subscriptions.notify(identifier, "connected");
            case message_types.rejection:
              return this.subscriptions.reject(identifier);
            default:
              return this.subscriptions.notify(identifier, "received", message);
          }
        },
        open() {
          logger_default.log(`WebSocket onopen event, using '${this.getProtocol()}' subprotocol`);
          this.disconnected = false;
          if (!this.isProtocolSupported()) {
            logger_default.log("Protocol is unsupported. Stopping monitor and disconnecting.");
            return this.close({ allowReconnect: false });
          }
        },
        close(event) {
          logger_default.log("WebSocket onclose event");
          if (this.disconnected) {
            return;
          }
          this.disconnected = true;
          this.monitor.recordDisconnect();
          return this.subscriptions.notifyAll("disconnected", { willAttemptReconnect: this.monitor.isRunning() });
        },
        error() {
          logger_default.log("WebSocket onerror event");
        }
      };
      connection_default = Connection;
    }
  });

  // node_modules/@rails/actioncable/src/subscription.js
  var extend, Subscription;
  var init_subscription = __esm({
    "node_modules/@rails/actioncable/src/subscription.js"() {
      extend = function(object, properties) {
        if (properties != null) {
          for (let key in properties) {
            const value = properties[key];
            object[key] = value;
          }
        }
        return object;
      };
      Subscription = class {
        constructor(consumer2, params = {}, mixin) {
          this.consumer = consumer2;
          this.identifier = JSON.stringify(params);
          extend(this, mixin);
        }
        perform(action, data = {}) {
          data.action = action;
          return this.send(data);
        }
        send(data) {
          return this.consumer.send({ command: "message", identifier: this.identifier, data: JSON.stringify(data) });
        }
        unsubscribe() {
          return this.consumer.subscriptions.remove(this);
        }
      };
    }
  });

  // node_modules/@rails/actioncable/src/subscription_guarantor.js
  var SubscriptionGuarantor, subscription_guarantor_default;
  var init_subscription_guarantor = __esm({
    "node_modules/@rails/actioncable/src/subscription_guarantor.js"() {
      init_logger();
      SubscriptionGuarantor = class {
        constructor(subscriptions) {
          this.subscriptions = subscriptions;
          this.pendingSubscriptions = [];
        }
        guarantee(subscription) {
          if (this.pendingSubscriptions.indexOf(subscription) == -1) {
            logger_default.log(`SubscriptionGuarantor guaranteeing ${subscription.identifier}`);
            this.pendingSubscriptions.push(subscription);
          } else {
            logger_default.log(`SubscriptionGuarantor already guaranteeing ${subscription.identifier}`);
          }
          this.startGuaranteeing();
        }
        forget(subscription) {
          logger_default.log(`SubscriptionGuarantor forgetting ${subscription.identifier}`);
          this.pendingSubscriptions = this.pendingSubscriptions.filter((s) => s !== subscription);
        }
        startGuaranteeing() {
          this.stopGuaranteeing();
          this.retrySubscribing();
        }
        stopGuaranteeing() {
          clearTimeout(this.retryTimeout);
        }
        retrySubscribing() {
          this.retryTimeout = setTimeout(
            () => {
              if (this.subscriptions && typeof this.subscriptions.subscribe === "function") {
                this.pendingSubscriptions.map((subscription) => {
                  logger_default.log(`SubscriptionGuarantor resubscribing ${subscription.identifier}`);
                  this.subscriptions.subscribe(subscription);
                });
              }
            },
            500
          );
        }
      };
      subscription_guarantor_default = SubscriptionGuarantor;
    }
  });

  // node_modules/@rails/actioncable/src/subscriptions.js
  var Subscriptions;
  var init_subscriptions = __esm({
    "node_modules/@rails/actioncable/src/subscriptions.js"() {
      init_subscription();
      init_subscription_guarantor();
      init_logger();
      Subscriptions = class {
        constructor(consumer2) {
          this.consumer = consumer2;
          this.guarantor = new subscription_guarantor_default(this);
          this.subscriptions = [];
        }
        create(channelName, mixin) {
          const channel = channelName;
          const params = typeof channel === "object" ? channel : { channel };
          const subscription = new Subscription(this.consumer, params, mixin);
          return this.add(subscription);
        }
        add(subscription) {
          this.subscriptions.push(subscription);
          this.consumer.ensureActiveConnection();
          this.notify(subscription, "initialized");
          this.subscribe(subscription);
          return subscription;
        }
        remove(subscription) {
          this.forget(subscription);
          if (!this.findAll(subscription.identifier).length) {
            this.sendCommand(subscription, "unsubscribe");
          }
          return subscription;
        }
        reject(identifier) {
          return this.findAll(identifier).map((subscription) => {
            this.forget(subscription);
            this.notify(subscription, "rejected");
            return subscription;
          });
        }
        forget(subscription) {
          this.guarantor.forget(subscription);
          this.subscriptions = this.subscriptions.filter((s) => s !== subscription);
          return subscription;
        }
        findAll(identifier) {
          return this.subscriptions.filter((s) => s.identifier === identifier);
        }
        reload() {
          return this.subscriptions.map((subscription) => this.subscribe(subscription));
        }
        notifyAll(callbackName, ...args) {
          return this.subscriptions.map((subscription) => this.notify(subscription, callbackName, ...args));
        }
        notify(subscription, callbackName, ...args) {
          let subscriptions;
          if (typeof subscription === "string") {
            subscriptions = this.findAll(subscription);
          } else {
            subscriptions = [subscription];
          }
          return subscriptions.map((subscription2) => typeof subscription2[callbackName] === "function" ? subscription2[callbackName](...args) : void 0);
        }
        subscribe(subscription) {
          if (this.sendCommand(subscription, "subscribe")) {
            this.guarantor.guarantee(subscription);
          }
        }
        confirmSubscription(identifier) {
          logger_default.log(`Subscription confirmed ${identifier}`);
          this.findAll(identifier).map((subscription) => this.guarantor.forget(subscription));
        }
        sendCommand(subscription, command) {
          const { identifier } = subscription;
          return this.consumer.send({ command, identifier });
        }
      };
    }
  });

  // node_modules/@rails/actioncable/src/consumer.js
  function createWebSocketURL(url) {
    if (typeof url === "function") {
      url = url();
    }
    if (url && !/^wss?:/i.test(url)) {
      const a = document.createElement("a");
      a.href = url;
      a.href = a.href;
      a.protocol = a.protocol.replace("http", "ws");
      return a.href;
    } else {
      return url;
    }
  }
  var Consumer;
  var init_consumer = __esm({
    "node_modules/@rails/actioncable/src/consumer.js"() {
      init_connection();
      init_subscriptions();
      Consumer = class {
        constructor(url) {
          this._url = url;
          this.subscriptions = new Subscriptions(this);
          this.connection = new connection_default(this);
        }
        get url() {
          return createWebSocketURL(this._url);
        }
        send(data) {
          return this.connection.send(data);
        }
        connect() {
          return this.connection.open();
        }
        disconnect() {
          return this.connection.close({ allowReconnect: false });
        }
        ensureActiveConnection() {
          if (!this.connection.isActive()) {
            return this.connection.open();
          }
        }
      };
    }
  });

  // node_modules/@rails/actioncable/src/index.js
  var src_exports = {};
  __export(src_exports, {
    Connection: () => connection_default,
    ConnectionMonitor: () => connection_monitor_default,
    Consumer: () => Consumer,
    INTERNAL: () => internal_default,
    Subscription: () => Subscription,
    SubscriptionGuarantor: () => subscription_guarantor_default,
    Subscriptions: () => Subscriptions,
    adapters: () => adapters_default,
    createConsumer: () => createConsumer,
    createWebSocketURL: () => createWebSocketURL,
    getConfig: () => getConfig,
    logger: () => logger_default
  });
  function createConsumer(url = getConfig("url") || internal_default.default_mount_path) {
    return new Consumer(url);
  }
  function getConfig(name) {
    const element = document.head.querySelector(`meta[name='action-cable-${name}']`);
    if (element) {
      return element.getAttribute("content");
    }
  }
  var init_src = __esm({
    "node_modules/@rails/actioncable/src/index.js"() {
      init_connection();
      init_connection_monitor();
      init_consumer();
      init_internal();
      init_subscription();
      init_subscriptions();
      init_subscription_guarantor();
      init_adapters();
      init_logger();
    }
  });

  // app/javascript/mobilekit/lib/bootstrap.min.js
  var require_bootstrap_min = __commonJS({
    "app/javascript/mobilekit/lib/bootstrap.min.js"(exports, module) {
      !function(t, e) {
        "object" == typeof exports && "undefined" != typeof module ? module.exports = e() : "function" == typeof define && define.amd ? define(e) : (t = "undefined" != typeof globalThis ? globalThis : t || self).bootstrap = e();
      }(exports, function() {
        "use strict";
        const t = "transitionend", e = (t2) => {
          let e2 = t2.getAttribute("data-bs-target");
          if (!e2 || "#" === e2) {
            let i2 = t2.getAttribute("href");
            if (!i2 || !i2.includes("#") && !i2.startsWith("."))
              return null;
            i2.includes("#") && !i2.startsWith("#") && (i2 = `#${i2.split("#")[1]}`), e2 = i2 && "#" !== i2 ? i2.trim() : null;
          }
          return e2;
        }, i = (t2) => {
          const i2 = e(t2);
          return i2 && document.querySelector(i2) ? i2 : null;
        }, n = (t2) => {
          const i2 = e(t2);
          return i2 ? document.querySelector(i2) : null;
        }, s = (e2) => {
          e2.dispatchEvent(new Event(t));
        }, o = (t2) => !(!t2 || "object" != typeof t2) && (void 0 !== t2.jquery && (t2 = t2[0]), void 0 !== t2.nodeType), r = (t2) => o(t2) ? t2.jquery ? t2[0] : t2 : "string" == typeof t2 && t2.length > 0 ? document.querySelector(t2) : null, a = (t2, e2, i2) => {
          Object.keys(i2).forEach((n2) => {
            const s2 = i2[n2], r2 = e2[n2], a2 = r2 && o(r2) ? "element" : null == (l2 = r2) ? `${l2}` : {}.toString.call(l2).match(/\s([a-z]+)/i)[1].toLowerCase();
            var l2;
            if (!new RegExp(s2).test(a2))
              throw new TypeError(`${t2.toUpperCase()}: Option "${n2}" provided type "${a2}" but expected type "${s2}".`);
          });
        }, l = (t2) => !(!o(t2) || 0 === t2.getClientRects().length) && "visible" === getComputedStyle(t2).getPropertyValue("visibility"), c = (t2) => !t2 || t2.nodeType !== Node.ELEMENT_NODE || !!t2.classList.contains("disabled") || (void 0 !== t2.disabled ? t2.disabled : t2.hasAttribute("disabled") && "false" !== t2.getAttribute("disabled")), h = (t2) => {
          if (!document.documentElement.attachShadow)
            return null;
          if ("function" == typeof t2.getRootNode) {
            const e2 = t2.getRootNode();
            return e2 instanceof ShadowRoot ? e2 : null;
          }
          return t2 instanceof ShadowRoot ? t2 : t2.parentNode ? h(t2.parentNode) : null;
        }, d = () => {
        }, u = (t2) => {
          t2.offsetHeight;
        }, f = () => {
          const { jQuery: t2 } = window;
          return t2 && !document.body.hasAttribute("data-bs-no-jquery") ? t2 : null;
        }, p = [], m = () => "rtl" === document.documentElement.dir, g = (t2) => {
          var e2;
          e2 = () => {
            const e3 = f();
            if (e3) {
              const i2 = t2.NAME, n2 = e3.fn[i2];
              e3.fn[i2] = t2.jQueryInterface, e3.fn[i2].Constructor = t2, e3.fn[i2].noConflict = () => (e3.fn[i2] = n2, t2.jQueryInterface);
            }
          }, "loading" === document.readyState ? (p.length || document.addEventListener("DOMContentLoaded", () => {
            p.forEach((t3) => t3());
          }), p.push(e2)) : e2();
        }, _ = (t2) => {
          "function" == typeof t2 && t2();
        }, b = (e2, i2, n2 = true) => {
          if (!n2)
            return void _(e2);
          const o2 = ((t2) => {
            if (!t2)
              return 0;
            let { transitionDuration: e3, transitionDelay: i3 } = window.getComputedStyle(t2);
            const n3 = Number.parseFloat(e3), s2 = Number.parseFloat(i3);
            return n3 || s2 ? (e3 = e3.split(",")[0], i3 = i3.split(",")[0], 1e3 * (Number.parseFloat(e3) + Number.parseFloat(i3))) : 0;
          })(i2) + 5;
          let r2 = false;
          const a2 = ({ target: n3 }) => {
            n3 === i2 && (r2 = true, i2.removeEventListener(t, a2), _(e2));
          };
          i2.addEventListener(t, a2), setTimeout(() => {
            r2 || s(i2);
          }, o2);
        }, v = (t2, e2, i2, n2) => {
          let s2 = t2.indexOf(e2);
          if (-1 === s2)
            return t2[!i2 && n2 ? t2.length - 1 : 0];
          const o2 = t2.length;
          return s2 += i2 ? 1 : -1, n2 && (s2 = (s2 + o2) % o2), t2[Math.max(0, Math.min(s2, o2 - 1))];
        }, y = /[^.]*(?=\..*)\.|.*/, w = /\..*/, E = /::\d+$/, A = {};
        let T = 1;
        const O = { mouseenter: "mouseover", mouseleave: "mouseout" }, C = /^(mouseenter|mouseleave)/i, k = /* @__PURE__ */ new Set(["click", "dblclick", "mouseup", "mousedown", "contextmenu", "mousewheel", "DOMMouseScroll", "mouseover", "mouseout", "mousemove", "selectstart", "selectend", "keydown", "keypress", "keyup", "orientationchange", "touchstart", "touchmove", "touchend", "touchcancel", "pointerdown", "pointermove", "pointerup", "pointerleave", "pointercancel", "gesturestart", "gesturechange", "gestureend", "focus", "blur", "change", "reset", "select", "submit", "focusin", "focusout", "load", "unload", "beforeunload", "resize", "move", "DOMContentLoaded", "readystatechange", "error", "abort", "scroll"]);
        function L(t2, e2) {
          return e2 && `${e2}::${T++}` || t2.uidEvent || T++;
        }
        function x(t2) {
          const e2 = L(t2);
          return t2.uidEvent = e2, A[e2] = A[e2] || {}, A[e2];
        }
        function D(t2, e2, i2 = null) {
          const n2 = Object.keys(t2);
          for (let s2 = 0, o2 = n2.length; s2 < o2; s2++) {
            const o3 = t2[n2[s2]];
            if (o3.originalHandler === e2 && o3.delegationSelector === i2)
              return o3;
          }
          return null;
        }
        function S(t2, e2, i2) {
          const n2 = "string" == typeof e2, s2 = n2 ? i2 : e2;
          let o2 = P(t2);
          return k.has(o2) || (o2 = t2), [n2, s2, o2];
        }
        function N(t2, e2, i2, n2, s2) {
          if ("string" != typeof e2 || !t2)
            return;
          if (i2 || (i2 = n2, n2 = null), C.test(e2)) {
            const t3 = (t4) => function(e3) {
              if (!e3.relatedTarget || e3.relatedTarget !== e3.delegateTarget && !e3.delegateTarget.contains(e3.relatedTarget))
                return t4.call(this, e3);
            };
            n2 ? n2 = t3(n2) : i2 = t3(i2);
          }
          const [o2, r2, a2] = S(e2, i2, n2), l2 = x(t2), c2 = l2[a2] || (l2[a2] = {}), h2 = D(c2, r2, o2 ? i2 : null);
          if (h2)
            return void (h2.oneOff = h2.oneOff && s2);
          const d2 = L(r2, e2.replace(y, "")), u2 = o2 ? function(t3, e3, i3) {
            return function n3(s3) {
              const o3 = t3.querySelectorAll(e3);
              for (let { target: r3 } = s3; r3 && r3 !== this; r3 = r3.parentNode)
                for (let a3 = o3.length; a3--; )
                  if (o3[a3] === r3)
                    return s3.delegateTarget = r3, n3.oneOff && j.off(t3, s3.type, e3, i3), i3.apply(r3, [s3]);
              return null;
            };
          }(t2, i2, n2) : function(t3, e3) {
            return function i3(n3) {
              return n3.delegateTarget = t3, i3.oneOff && j.off(t3, n3.type, e3), e3.apply(t3, [n3]);
            };
          }(t2, i2);
          u2.delegationSelector = o2 ? i2 : null, u2.originalHandler = r2, u2.oneOff = s2, u2.uidEvent = d2, c2[d2] = u2, t2.addEventListener(a2, u2, o2);
        }
        function I(t2, e2, i2, n2, s2) {
          const o2 = D(e2[i2], n2, s2);
          o2 && (t2.removeEventListener(i2, o2, Boolean(s2)), delete e2[i2][o2.uidEvent]);
        }
        function P(t2) {
          return t2 = t2.replace(w, ""), O[t2] || t2;
        }
        const j = { on(t2, e2, i2, n2) {
          N(t2, e2, i2, n2, false);
        }, one(t2, e2, i2, n2) {
          N(t2, e2, i2, n2, true);
        }, off(t2, e2, i2, n2) {
          if ("string" != typeof e2 || !t2)
            return;
          const [s2, o2, r2] = S(e2, i2, n2), a2 = r2 !== e2, l2 = x(t2), c2 = e2.startsWith(".");
          if (void 0 !== o2) {
            if (!l2 || !l2[r2])
              return;
            return void I(t2, l2, r2, o2, s2 ? i2 : null);
          }
          c2 && Object.keys(l2).forEach((i3) => {
            !function(t3, e3, i4, n3) {
              const s3 = e3[i4] || {};
              Object.keys(s3).forEach((o3) => {
                if (o3.includes(n3)) {
                  const n4 = s3[o3];
                  I(t3, e3, i4, n4.originalHandler, n4.delegationSelector);
                }
              });
            }(t2, l2, i3, e2.slice(1));
          });
          const h2 = l2[r2] || {};
          Object.keys(h2).forEach((i3) => {
            const n3 = i3.replace(E, "");
            if (!a2 || e2.includes(n3)) {
              const e3 = h2[i3];
              I(t2, l2, r2, e3.originalHandler, e3.delegationSelector);
            }
          });
        }, trigger(t2, e2, i2) {
          if ("string" != typeof e2 || !t2)
            return null;
          const n2 = f(), s2 = P(e2), o2 = e2 !== s2, r2 = k.has(s2);
          let a2, l2 = true, c2 = true, h2 = false, d2 = null;
          return o2 && n2 && (a2 = n2.Event(e2, i2), n2(t2).trigger(a2), l2 = !a2.isPropagationStopped(), c2 = !a2.isImmediatePropagationStopped(), h2 = a2.isDefaultPrevented()), r2 ? (d2 = document.createEvent("HTMLEvents"), d2.initEvent(s2, l2, true)) : d2 = new CustomEvent(e2, { bubbles: l2, cancelable: true }), void 0 !== i2 && Object.keys(i2).forEach((t3) => {
            Object.defineProperty(d2, t3, { get: () => i2[t3] });
          }), h2 && d2.preventDefault(), c2 && t2.dispatchEvent(d2), d2.defaultPrevented && void 0 !== a2 && a2.preventDefault(), d2;
        } }, M = /* @__PURE__ */ new Map(), H = { set(t2, e2, i2) {
          M.has(t2) || M.set(t2, /* @__PURE__ */ new Map());
          const n2 = M.get(t2);
          n2.has(e2) || 0 === n2.size ? n2.set(e2, i2) : console.error(`Bootstrap doesn't allow more than one instance per element. Bound instance: ${Array.from(n2.keys())[0]}.`);
        }, get: (t2, e2) => M.has(t2) && M.get(t2).get(e2) || null, remove(t2, e2) {
          if (!M.has(t2))
            return;
          const i2 = M.get(t2);
          i2.delete(e2), 0 === i2.size && M.delete(t2);
        } };
        class B {
          constructor(t2) {
            (t2 = r(t2)) && (this._element = t2, H.set(this._element, this.constructor.DATA_KEY, this));
          }
          dispose() {
            H.remove(this._element, this.constructor.DATA_KEY), j.off(this._element, this.constructor.EVENT_KEY), Object.getOwnPropertyNames(this).forEach((t2) => {
              this[t2] = null;
            });
          }
          _queueCallback(t2, e2, i2 = true) {
            b(t2, e2, i2);
          }
          static getInstance(t2) {
            return H.get(r(t2), this.DATA_KEY);
          }
          static getOrCreateInstance(t2, e2 = {}) {
            return this.getInstance(t2) || new this(t2, "object" == typeof e2 ? e2 : null);
          }
          static get VERSION() {
            return "5.1.3";
          }
          static get NAME() {
            throw new Error('You have to implement the static method "NAME", for each component!');
          }
          static get DATA_KEY() {
            return `bs.${this.NAME}`;
          }
          static get EVENT_KEY() {
            return `.${this.DATA_KEY}`;
          }
        }
        const R = (t2, e2 = "hide") => {
          const i2 = `click.dismiss${t2.EVENT_KEY}`, s2 = t2.NAME;
          j.on(document, i2, `[data-bs-dismiss="${s2}"]`, function(i3) {
            if (["A", "AREA"].includes(this.tagName) && i3.preventDefault(), c(this))
              return;
            const o2 = n(this) || this.closest(`.${s2}`);
            t2.getOrCreateInstance(o2)[e2]();
          });
        };
        class W extends B {
          static get NAME() {
            return "alert";
          }
          close() {
            if (j.trigger(this._element, "close.bs.alert").defaultPrevented)
              return;
            this._element.classList.remove("show");
            const t2 = this._element.classList.contains("fade");
            this._queueCallback(() => this._destroyElement(), this._element, t2);
          }
          _destroyElement() {
            this._element.remove(), j.trigger(this._element, "closed.bs.alert"), this.dispose();
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = W.getOrCreateInstance(this);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2] || t2.startsWith("_") || "constructor" === t2)
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2](this);
              }
            });
          }
        }
        R(W, "close"), g(W);
        const $ = '[data-bs-toggle="button"]';
        class z extends B {
          static get NAME() {
            return "button";
          }
          toggle() {
            this._element.setAttribute("aria-pressed", this._element.classList.toggle("active"));
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = z.getOrCreateInstance(this);
              "toggle" === t2 && e2[t2]();
            });
          }
        }
        function q(t2) {
          return "true" === t2 || "false" !== t2 && (t2 === Number(t2).toString() ? Number(t2) : "" === t2 || "null" === t2 ? null : t2);
        }
        function F(t2) {
          return t2.replace(/[A-Z]/g, (t3) => `-${t3.toLowerCase()}`);
        }
        j.on(document, "click.bs.button.data-api", $, (t2) => {
          t2.preventDefault();
          const e2 = t2.target.closest($);
          z.getOrCreateInstance(e2).toggle();
        }), g(z);
        const U = { setDataAttribute(t2, e2, i2) {
          t2.setAttribute(`data-bs-${F(e2)}`, i2);
        }, removeDataAttribute(t2, e2) {
          t2.removeAttribute(`data-bs-${F(e2)}`);
        }, getDataAttributes(t2) {
          if (!t2)
            return {};
          const e2 = {};
          return Object.keys(t2.dataset).filter((t3) => t3.startsWith("bs")).forEach((i2) => {
            let n2 = i2.replace(/^bs/, "");
            n2 = n2.charAt(0).toLowerCase() + n2.slice(1, n2.length), e2[n2] = q(t2.dataset[i2]);
          }), e2;
        }, getDataAttribute: (t2, e2) => q(t2.getAttribute(`data-bs-${F(e2)}`)), offset(t2) {
          const e2 = t2.getBoundingClientRect();
          return { top: e2.top + window.pageYOffset, left: e2.left + window.pageXOffset };
        }, position: (t2) => ({ top: t2.offsetTop, left: t2.offsetLeft }) }, V = { find: (t2, e2 = document.documentElement) => [].concat(...Element.prototype.querySelectorAll.call(e2, t2)), findOne: (t2, e2 = document.documentElement) => Element.prototype.querySelector.call(e2, t2), children: (t2, e2) => [].concat(...t2.children).filter((t3) => t3.matches(e2)), parents(t2, e2) {
          const i2 = [];
          let n2 = t2.parentNode;
          for (; n2 && n2.nodeType === Node.ELEMENT_NODE && 3 !== n2.nodeType; )
            n2.matches(e2) && i2.push(n2), n2 = n2.parentNode;
          return i2;
        }, prev(t2, e2) {
          let i2 = t2.previousElementSibling;
          for (; i2; ) {
            if (i2.matches(e2))
              return [i2];
            i2 = i2.previousElementSibling;
          }
          return [];
        }, next(t2, e2) {
          let i2 = t2.nextElementSibling;
          for (; i2; ) {
            if (i2.matches(e2))
              return [i2];
            i2 = i2.nextElementSibling;
          }
          return [];
        }, focusableChildren(t2) {
          const e2 = ["a", "button", "input", "textarea", "select", "details", "[tabindex]", '[contenteditable="true"]'].map((t3) => `${t3}:not([tabindex^="-"])`).join(", ");
          return this.find(e2, t2).filter((t3) => !c(t3) && l(t3));
        } }, K = "carousel", X = { interval: 5e3, keyboard: true, slide: false, pause: "hover", wrap: true, touch: true }, Y = { interval: "(number|boolean)", keyboard: "boolean", slide: "(boolean|string)", pause: "(string|boolean)", wrap: "boolean", touch: "boolean" }, Q = "next", G = "prev", Z = "left", J = "right", tt = { ArrowLeft: J, ArrowRight: Z }, et = "slid.bs.carousel", it = "active", nt = ".active.carousel-item";
        class st extends B {
          constructor(t2, e2) {
            super(t2), this._items = null, this._interval = null, this._activeElement = null, this._isPaused = false, this._isSliding = false, this.touchTimeout = null, this.touchStartX = 0, this.touchDeltaX = 0, this._config = this._getConfig(e2), this._indicatorsElement = V.findOne(".carousel-indicators", this._element), this._touchSupported = "ontouchstart" in document.documentElement || navigator.maxTouchPoints > 0, this._pointerEvent = Boolean(window.PointerEvent), this._addEventListeners();
          }
          static get Default() {
            return X;
          }
          static get NAME() {
            return K;
          }
          next() {
            this._slide(Q);
          }
          nextWhenVisible() {
            !document.hidden && l(this._element) && this.next();
          }
          prev() {
            this._slide(G);
          }
          pause(t2) {
            t2 || (this._isPaused = true), V.findOne(".carousel-item-next, .carousel-item-prev", this._element) && (s(this._element), this.cycle(true)), clearInterval(this._interval), this._interval = null;
          }
          cycle(t2) {
            t2 || (this._isPaused = false), this._interval && (clearInterval(this._interval), this._interval = null), this._config && this._config.interval && !this._isPaused && (this._updateInterval(), this._interval = setInterval((document.visibilityState ? this.nextWhenVisible : this.next).bind(this), this._config.interval));
          }
          to(t2) {
            this._activeElement = V.findOne(nt, this._element);
            const e2 = this._getItemIndex(this._activeElement);
            if (t2 > this._items.length - 1 || t2 < 0)
              return;
            if (this._isSliding)
              return void j.one(this._element, et, () => this.to(t2));
            if (e2 === t2)
              return this.pause(), void this.cycle();
            const i2 = t2 > e2 ? Q : G;
            this._slide(i2, this._items[t2]);
          }
          _getConfig(t2) {
            return t2 = { ...X, ...U.getDataAttributes(this._element), ..."object" == typeof t2 ? t2 : {} }, a(K, t2, Y), t2;
          }
          _handleSwipe() {
            const t2 = Math.abs(this.touchDeltaX);
            if (t2 <= 40)
              return;
            const e2 = t2 / this.touchDeltaX;
            this.touchDeltaX = 0, e2 && this._slide(e2 > 0 ? J : Z);
          }
          _addEventListeners() {
            this._config.keyboard && j.on(this._element, "keydown.bs.carousel", (t2) => this._keydown(t2)), "hover" === this._config.pause && (j.on(this._element, "mouseenter.bs.carousel", (t2) => this.pause(t2)), j.on(this._element, "mouseleave.bs.carousel", (t2) => this.cycle(t2))), this._config.touch && this._touchSupported && this._addTouchEventListeners();
          }
          _addTouchEventListeners() {
            const t2 = (t3) => this._pointerEvent && ("pen" === t3.pointerType || "touch" === t3.pointerType), e2 = (e3) => {
              t2(e3) ? this.touchStartX = e3.clientX : this._pointerEvent || (this.touchStartX = e3.touches[0].clientX);
            }, i2 = (t3) => {
              this.touchDeltaX = t3.touches && t3.touches.length > 1 ? 0 : t3.touches[0].clientX - this.touchStartX;
            }, n2 = (e3) => {
              t2(e3) && (this.touchDeltaX = e3.clientX - this.touchStartX), this._handleSwipe(), "hover" === this._config.pause && (this.pause(), this.touchTimeout && clearTimeout(this.touchTimeout), this.touchTimeout = setTimeout((t3) => this.cycle(t3), 500 + this._config.interval));
            };
            V.find(".carousel-item img", this._element).forEach((t3) => {
              j.on(t3, "dragstart.bs.carousel", (t4) => t4.preventDefault());
            }), this._pointerEvent ? (j.on(this._element, "pointerdown.bs.carousel", (t3) => e2(t3)), j.on(this._element, "pointerup.bs.carousel", (t3) => n2(t3)), this._element.classList.add("pointer-event")) : (j.on(this._element, "touchstart.bs.carousel", (t3) => e2(t3)), j.on(this._element, "touchmove.bs.carousel", (t3) => i2(t3)), j.on(this._element, "touchend.bs.carousel", (t3) => n2(t3)));
          }
          _keydown(t2) {
            if (/input|textarea/i.test(t2.target.tagName))
              return;
            const e2 = tt[t2.key];
            e2 && (t2.preventDefault(), this._slide(e2));
          }
          _getItemIndex(t2) {
            return this._items = t2 && t2.parentNode ? V.find(".carousel-item", t2.parentNode) : [], this._items.indexOf(t2);
          }
          _getItemByOrder(t2, e2) {
            const i2 = t2 === Q;
            return v(this._items, e2, i2, this._config.wrap);
          }
          _triggerSlideEvent(t2, e2) {
            const i2 = this._getItemIndex(t2), n2 = this._getItemIndex(V.findOne(nt, this._element));
            return j.trigger(this._element, "slide.bs.carousel", { relatedTarget: t2, direction: e2, from: n2, to: i2 });
          }
          _setActiveIndicatorElement(t2) {
            if (this._indicatorsElement) {
              const e2 = V.findOne(".active", this._indicatorsElement);
              e2.classList.remove(it), e2.removeAttribute("aria-current");
              const i2 = V.find("[data-bs-target]", this._indicatorsElement);
              for (let e3 = 0; e3 < i2.length; e3++)
                if (Number.parseInt(i2[e3].getAttribute("data-bs-slide-to"), 10) === this._getItemIndex(t2)) {
                  i2[e3].classList.add(it), i2[e3].setAttribute("aria-current", "true");
                  break;
                }
            }
          }
          _updateInterval() {
            const t2 = this._activeElement || V.findOne(nt, this._element);
            if (!t2)
              return;
            const e2 = Number.parseInt(t2.getAttribute("data-bs-interval"), 10);
            e2 ? (this._config.defaultInterval = this._config.defaultInterval || this._config.interval, this._config.interval = e2) : this._config.interval = this._config.defaultInterval || this._config.interval;
          }
          _slide(t2, e2) {
            const i2 = this._directionToOrder(t2), n2 = V.findOne(nt, this._element), s2 = this._getItemIndex(n2), o2 = e2 || this._getItemByOrder(i2, n2), r2 = this._getItemIndex(o2), a2 = Boolean(this._interval), l2 = i2 === Q, c2 = l2 ? "carousel-item-start" : "carousel-item-end", h2 = l2 ? "carousel-item-next" : "carousel-item-prev", d2 = this._orderToDirection(i2);
            if (o2 && o2.classList.contains(it))
              return void (this._isSliding = false);
            if (this._isSliding)
              return;
            if (this._triggerSlideEvent(o2, d2).defaultPrevented)
              return;
            if (!n2 || !o2)
              return;
            this._isSliding = true, a2 && this.pause(), this._setActiveIndicatorElement(o2), this._activeElement = o2;
            const f2 = () => {
              j.trigger(this._element, et, { relatedTarget: o2, direction: d2, from: s2, to: r2 });
            };
            if (this._element.classList.contains("slide")) {
              o2.classList.add(h2), u(o2), n2.classList.add(c2), o2.classList.add(c2);
              const t3 = () => {
                o2.classList.remove(c2, h2), o2.classList.add(it), n2.classList.remove(it, h2, c2), this._isSliding = false, setTimeout(f2, 0);
              };
              this._queueCallback(t3, n2, true);
            } else
              n2.classList.remove(it), o2.classList.add(it), this._isSliding = false, f2();
            a2 && this.cycle();
          }
          _directionToOrder(t2) {
            return [J, Z].includes(t2) ? m() ? t2 === Z ? G : Q : t2 === Z ? Q : G : t2;
          }
          _orderToDirection(t2) {
            return [Q, G].includes(t2) ? m() ? t2 === G ? Z : J : t2 === G ? J : Z : t2;
          }
          static carouselInterface(t2, e2) {
            const i2 = st.getOrCreateInstance(t2, e2);
            let { _config: n2 } = i2;
            "object" == typeof e2 && (n2 = { ...n2, ...e2 });
            const s2 = "string" == typeof e2 ? e2 : n2.slide;
            if ("number" == typeof e2)
              i2.to(e2);
            else if ("string" == typeof s2) {
              if (void 0 === i2[s2])
                throw new TypeError(`No method named "${s2}"`);
              i2[s2]();
            } else
              n2.interval && n2.ride && (i2.pause(), i2.cycle());
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              st.carouselInterface(this, t2);
            });
          }
          static dataApiClickHandler(t2) {
            const e2 = n(this);
            if (!e2 || !e2.classList.contains("carousel"))
              return;
            const i2 = { ...U.getDataAttributes(e2), ...U.getDataAttributes(this) }, s2 = this.getAttribute("data-bs-slide-to");
            s2 && (i2.interval = false), st.carouselInterface(e2, i2), s2 && st.getInstance(e2).to(s2), t2.preventDefault();
          }
        }
        j.on(document, "click.bs.carousel.data-api", "[data-bs-slide], [data-bs-slide-to]", st.dataApiClickHandler), j.on(window, "load.bs.carousel.data-api", () => {
          const t2 = V.find('[data-bs-ride="carousel"]');
          for (let e2 = 0, i2 = t2.length; e2 < i2; e2++)
            st.carouselInterface(t2[e2], st.getInstance(t2[e2]));
        }), g(st);
        const ot = "collapse", rt = { toggle: true, parent: null }, at = { toggle: "boolean", parent: "(null|element)" }, lt = "show", ct = "collapse", ht = "collapsing", dt = "collapsed", ut = ":scope .collapse .collapse", ft = '[data-bs-toggle="collapse"]';
        class pt extends B {
          constructor(t2, e2) {
            super(t2), this._isTransitioning = false, this._config = this._getConfig(e2), this._triggerArray = [];
            const n2 = V.find(ft);
            for (let t3 = 0, e3 = n2.length; t3 < e3; t3++) {
              const e4 = n2[t3], s2 = i(e4), o2 = V.find(s2).filter((t4) => t4 === this._element);
              null !== s2 && o2.length && (this._selector = s2, this._triggerArray.push(e4));
            }
            this._initializeChildren(), this._config.parent || this._addAriaAndCollapsedClass(this._triggerArray, this._isShown()), this._config.toggle && this.toggle();
          }
          static get Default() {
            return rt;
          }
          static get NAME() {
            return ot;
          }
          toggle() {
            this._isShown() ? this.hide() : this.show();
          }
          show() {
            if (this._isTransitioning || this._isShown())
              return;
            let t2, e2 = [];
            if (this._config.parent) {
              const t3 = V.find(ut, this._config.parent);
              e2 = V.find(".collapse.show, .collapse.collapsing", this._config.parent).filter((e3) => !t3.includes(e3));
            }
            const i2 = V.findOne(this._selector);
            if (e2.length) {
              const n3 = e2.find((t3) => i2 !== t3);
              if (t2 = n3 ? pt.getInstance(n3) : null, t2 && t2._isTransitioning)
                return;
            }
            if (j.trigger(this._element, "show.bs.collapse").defaultPrevented)
              return;
            e2.forEach((e3) => {
              i2 !== e3 && pt.getOrCreateInstance(e3, { toggle: false }).hide(), t2 || H.set(e3, "bs.collapse", null);
            });
            const n2 = this._getDimension();
            this._element.classList.remove(ct), this._element.classList.add(ht), this._element.style[n2] = 0, this._addAriaAndCollapsedClass(this._triggerArray, true), this._isTransitioning = true;
            const s2 = `scroll${n2[0].toUpperCase() + n2.slice(1)}`;
            this._queueCallback(() => {
              this._isTransitioning = false, this._element.classList.remove(ht), this._element.classList.add(ct, lt), this._element.style[n2] = "", j.trigger(this._element, "shown.bs.collapse");
            }, this._element, true), this._element.style[n2] = `${this._element[s2]}px`;
          }
          hide() {
            if (this._isTransitioning || !this._isShown())
              return;
            if (j.trigger(this._element, "hide.bs.collapse").defaultPrevented)
              return;
            const t2 = this._getDimension();
            this._element.style[t2] = `${this._element.getBoundingClientRect()[t2]}px`, u(this._element), this._element.classList.add(ht), this._element.classList.remove(ct, lt);
            const e2 = this._triggerArray.length;
            for (let t3 = 0; t3 < e2; t3++) {
              const e3 = this._triggerArray[t3], i2 = n(e3);
              i2 && !this._isShown(i2) && this._addAriaAndCollapsedClass([e3], false);
            }
            this._isTransitioning = true, this._element.style[t2] = "", this._queueCallback(() => {
              this._isTransitioning = false, this._element.classList.remove(ht), this._element.classList.add(ct), j.trigger(this._element, "hidden.bs.collapse");
            }, this._element, true);
          }
          _isShown(t2 = this._element) {
            return t2.classList.contains(lt);
          }
          _getConfig(t2) {
            return (t2 = { ...rt, ...U.getDataAttributes(this._element), ...t2 }).toggle = Boolean(t2.toggle), t2.parent = r(t2.parent), a(ot, t2, at), t2;
          }
          _getDimension() {
            return this._element.classList.contains("collapse-horizontal") ? "width" : "height";
          }
          _initializeChildren() {
            if (!this._config.parent)
              return;
            const t2 = V.find(ut, this._config.parent);
            V.find(ft, this._config.parent).filter((e2) => !t2.includes(e2)).forEach((t3) => {
              const e2 = n(t3);
              e2 && this._addAriaAndCollapsedClass([t3], this._isShown(e2));
            });
          }
          _addAriaAndCollapsedClass(t2, e2) {
            t2.length && t2.forEach((t3) => {
              e2 ? t3.classList.remove(dt) : t3.classList.add(dt), t3.setAttribute("aria-expanded", e2);
            });
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = {};
              "string" == typeof t2 && /show|hide/.test(t2) && (e2.toggle = false);
              const i2 = pt.getOrCreateInstance(this, e2);
              if ("string" == typeof t2) {
                if (void 0 === i2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                i2[t2]();
              }
            });
          }
        }
        j.on(document, "click.bs.collapse.data-api", ft, function(t2) {
          ("A" === t2.target.tagName || t2.delegateTarget && "A" === t2.delegateTarget.tagName) && t2.preventDefault();
          const e2 = i(this);
          V.find(e2).forEach((t3) => {
            pt.getOrCreateInstance(t3, { toggle: false }).toggle();
          });
        }), g(pt);
        var mt = "top", gt = "bottom", _t = "right", bt = "left", vt = "auto", yt = [mt, gt, _t, bt], wt = "start", Et = "end", At = "clippingParents", Tt = "viewport", Ot = "popper", Ct = "reference", kt = yt.reduce(function(t2, e2) {
          return t2.concat([e2 + "-" + wt, e2 + "-" + Et]);
        }, []), Lt = [].concat(yt, [vt]).reduce(function(t2, e2) {
          return t2.concat([e2, e2 + "-" + wt, e2 + "-" + Et]);
        }, []), xt = "beforeRead", Dt = "read", St = "afterRead", Nt = "beforeMain", It = "main", Pt = "afterMain", jt = "beforeWrite", Mt = "write", Ht = "afterWrite", Bt = [xt, Dt, St, Nt, It, Pt, jt, Mt, Ht];
        function Rt(t2) {
          return t2 ? (t2.nodeName || "").toLowerCase() : null;
        }
        function Wt(t2) {
          if (null == t2)
            return window;
          if ("[object Window]" !== t2.toString()) {
            var e2 = t2.ownerDocument;
            return e2 && e2.defaultView || window;
          }
          return t2;
        }
        function $t(t2) {
          return t2 instanceof Wt(t2).Element || t2 instanceof Element;
        }
        function zt(t2) {
          return t2 instanceof Wt(t2).HTMLElement || t2 instanceof HTMLElement;
        }
        function qt(t2) {
          return "undefined" != typeof ShadowRoot && (t2 instanceof Wt(t2).ShadowRoot || t2 instanceof ShadowRoot);
        }
        const Ft = { name: "applyStyles", enabled: true, phase: "write", fn: function(t2) {
          var e2 = t2.state;
          Object.keys(e2.elements).forEach(function(t3) {
            var i2 = e2.styles[t3] || {}, n2 = e2.attributes[t3] || {}, s2 = e2.elements[t3];
            zt(s2) && Rt(s2) && (Object.assign(s2.style, i2), Object.keys(n2).forEach(function(t4) {
              var e3 = n2[t4];
              false === e3 ? s2.removeAttribute(t4) : s2.setAttribute(t4, true === e3 ? "" : e3);
            }));
          });
        }, effect: function(t2) {
          var e2 = t2.state, i2 = { popper: { position: e2.options.strategy, left: "0", top: "0", margin: "0" }, arrow: { position: "absolute" }, reference: {} };
          return Object.assign(e2.elements.popper.style, i2.popper), e2.styles = i2, e2.elements.arrow && Object.assign(e2.elements.arrow.style, i2.arrow), function() {
            Object.keys(e2.elements).forEach(function(t3) {
              var n2 = e2.elements[t3], s2 = e2.attributes[t3] || {}, o2 = Object.keys(e2.styles.hasOwnProperty(t3) ? e2.styles[t3] : i2[t3]).reduce(function(t4, e3) {
                return t4[e3] = "", t4;
              }, {});
              zt(n2) && Rt(n2) && (Object.assign(n2.style, o2), Object.keys(s2).forEach(function(t4) {
                n2.removeAttribute(t4);
              }));
            });
          };
        }, requires: ["computeStyles"] };
        function Ut(t2) {
          return t2.split("-")[0];
        }
        function Vt(t2, e2) {
          var i2 = t2.getBoundingClientRect();
          return { width: i2.width / 1, height: i2.height / 1, top: i2.top / 1, right: i2.right / 1, bottom: i2.bottom / 1, left: i2.left / 1, x: i2.left / 1, y: i2.top / 1 };
        }
        function Kt(t2) {
          var e2 = Vt(t2), i2 = t2.offsetWidth, n2 = t2.offsetHeight;
          return Math.abs(e2.width - i2) <= 1 && (i2 = e2.width), Math.abs(e2.height - n2) <= 1 && (n2 = e2.height), { x: t2.offsetLeft, y: t2.offsetTop, width: i2, height: n2 };
        }
        function Xt(t2, e2) {
          var i2 = e2.getRootNode && e2.getRootNode();
          if (t2.contains(e2))
            return true;
          if (i2 && qt(i2)) {
            var n2 = e2;
            do {
              if (n2 && t2.isSameNode(n2))
                return true;
              n2 = n2.parentNode || n2.host;
            } while (n2);
          }
          return false;
        }
        function Yt(t2) {
          return Wt(t2).getComputedStyle(t2);
        }
        function Qt(t2) {
          return ["table", "td", "th"].indexOf(Rt(t2)) >= 0;
        }
        function Gt(t2) {
          return (($t(t2) ? t2.ownerDocument : t2.document) || window.document).documentElement;
        }
        function Zt(t2) {
          return "html" === Rt(t2) ? t2 : t2.assignedSlot || t2.parentNode || (qt(t2) ? t2.host : null) || Gt(t2);
        }
        function Jt(t2) {
          return zt(t2) && "fixed" !== Yt(t2).position ? t2.offsetParent : null;
        }
        function te(t2) {
          for (var e2 = Wt(t2), i2 = Jt(t2); i2 && Qt(i2) && "static" === Yt(i2).position; )
            i2 = Jt(i2);
          return i2 && ("html" === Rt(i2) || "body" === Rt(i2) && "static" === Yt(i2).position) ? e2 : i2 || function(t3) {
            var e3 = -1 !== navigator.userAgent.toLowerCase().indexOf("firefox");
            if (-1 !== navigator.userAgent.indexOf("Trident") && zt(t3) && "fixed" === Yt(t3).position)
              return null;
            for (var i3 = Zt(t3); zt(i3) && ["html", "body"].indexOf(Rt(i3)) < 0; ) {
              var n2 = Yt(i3);
              if ("none" !== n2.transform || "none" !== n2.perspective || "paint" === n2.contain || -1 !== ["transform", "perspective"].indexOf(n2.willChange) || e3 && "filter" === n2.willChange || e3 && n2.filter && "none" !== n2.filter)
                return i3;
              i3 = i3.parentNode;
            }
            return null;
          }(t2) || e2;
        }
        function ee(t2) {
          return ["top", "bottom"].indexOf(t2) >= 0 ? "x" : "y";
        }
        var ie = Math.max, ne = Math.min, se = Math.round;
        function oe(t2, e2, i2) {
          return ie(t2, ne(e2, i2));
        }
        function re(t2) {
          return Object.assign({}, { top: 0, right: 0, bottom: 0, left: 0 }, t2);
        }
        function ae(t2, e2) {
          return e2.reduce(function(e3, i2) {
            return e3[i2] = t2, e3;
          }, {});
        }
        const le = { name: "arrow", enabled: true, phase: "main", fn: function(t2) {
          var e2, i2 = t2.state, n2 = t2.name, s2 = t2.options, o2 = i2.elements.arrow, r2 = i2.modifiersData.popperOffsets, a2 = Ut(i2.placement), l2 = ee(a2), c2 = [bt, _t].indexOf(a2) >= 0 ? "height" : "width";
          if (o2 && r2) {
            var h2 = function(t3, e3) {
              return re("number" != typeof (t3 = "function" == typeof t3 ? t3(Object.assign({}, e3.rects, { placement: e3.placement })) : t3) ? t3 : ae(t3, yt));
            }(s2.padding, i2), d2 = Kt(o2), u2 = "y" === l2 ? mt : bt, f2 = "y" === l2 ? gt : _t, p2 = i2.rects.reference[c2] + i2.rects.reference[l2] - r2[l2] - i2.rects.popper[c2], m2 = r2[l2] - i2.rects.reference[l2], g2 = te(o2), _2 = g2 ? "y" === l2 ? g2.clientHeight || 0 : g2.clientWidth || 0 : 0, b2 = p2 / 2 - m2 / 2, v2 = h2[u2], y2 = _2 - d2[c2] - h2[f2], w2 = _2 / 2 - d2[c2] / 2 + b2, E2 = oe(v2, w2, y2), A2 = l2;
            i2.modifiersData[n2] = ((e2 = {})[A2] = E2, e2.centerOffset = E2 - w2, e2);
          }
        }, effect: function(t2) {
          var e2 = t2.state, i2 = t2.options.element, n2 = void 0 === i2 ? "[data-popper-arrow]" : i2;
          null != n2 && ("string" != typeof n2 || (n2 = e2.elements.popper.querySelector(n2))) && Xt(e2.elements.popper, n2) && (e2.elements.arrow = n2);
        }, requires: ["popperOffsets"], requiresIfExists: ["preventOverflow"] };
        function ce(t2) {
          return t2.split("-")[1];
        }
        var he = { top: "auto", right: "auto", bottom: "auto", left: "auto" };
        function de(t2) {
          var e2, i2 = t2.popper, n2 = t2.popperRect, s2 = t2.placement, o2 = t2.variation, r2 = t2.offsets, a2 = t2.position, l2 = t2.gpuAcceleration, c2 = t2.adaptive, h2 = t2.roundOffsets, d2 = true === h2 ? function(t3) {
            var e3 = t3.x, i3 = t3.y, n3 = window.devicePixelRatio || 1;
            return { x: se(se(e3 * n3) / n3) || 0, y: se(se(i3 * n3) / n3) || 0 };
          }(r2) : "function" == typeof h2 ? h2(r2) : r2, u2 = d2.x, f2 = void 0 === u2 ? 0 : u2, p2 = d2.y, m2 = void 0 === p2 ? 0 : p2, g2 = r2.hasOwnProperty("x"), _2 = r2.hasOwnProperty("y"), b2 = bt, v2 = mt, y2 = window;
          if (c2) {
            var w2 = te(i2), E2 = "clientHeight", A2 = "clientWidth";
            w2 === Wt(i2) && "static" !== Yt(w2 = Gt(i2)).position && "absolute" === a2 && (E2 = "scrollHeight", A2 = "scrollWidth"), w2 = w2, s2 !== mt && (s2 !== bt && s2 !== _t || o2 !== Et) || (v2 = gt, m2 -= w2[E2] - n2.height, m2 *= l2 ? 1 : -1), s2 !== bt && (s2 !== mt && s2 !== gt || o2 !== Et) || (b2 = _t, f2 -= w2[A2] - n2.width, f2 *= l2 ? 1 : -1);
          }
          var T2, O2 = Object.assign({ position: a2 }, c2 && he);
          return l2 ? Object.assign({}, O2, ((T2 = {})[v2] = _2 ? "0" : "", T2[b2] = g2 ? "0" : "", T2.transform = (y2.devicePixelRatio || 1) <= 1 ? "translate(" + f2 + "px, " + m2 + "px)" : "translate3d(" + f2 + "px, " + m2 + "px, 0)", T2)) : Object.assign({}, O2, ((e2 = {})[v2] = _2 ? m2 + "px" : "", e2[b2] = g2 ? f2 + "px" : "", e2.transform = "", e2));
        }
        const ue = { name: "computeStyles", enabled: true, phase: "beforeWrite", fn: function(t2) {
          var e2 = t2.state, i2 = t2.options, n2 = i2.gpuAcceleration, s2 = void 0 === n2 || n2, o2 = i2.adaptive, r2 = void 0 === o2 || o2, a2 = i2.roundOffsets, l2 = void 0 === a2 || a2, c2 = { placement: Ut(e2.placement), variation: ce(e2.placement), popper: e2.elements.popper, popperRect: e2.rects.popper, gpuAcceleration: s2 };
          null != e2.modifiersData.popperOffsets && (e2.styles.popper = Object.assign({}, e2.styles.popper, de(Object.assign({}, c2, { offsets: e2.modifiersData.popperOffsets, position: e2.options.strategy, adaptive: r2, roundOffsets: l2 })))), null != e2.modifiersData.arrow && (e2.styles.arrow = Object.assign({}, e2.styles.arrow, de(Object.assign({}, c2, { offsets: e2.modifiersData.arrow, position: "absolute", adaptive: false, roundOffsets: l2 })))), e2.attributes.popper = Object.assign({}, e2.attributes.popper, { "data-popper-placement": e2.placement });
        }, data: {} };
        var fe = { passive: true };
        const pe = { name: "eventListeners", enabled: true, phase: "write", fn: function() {
        }, effect: function(t2) {
          var e2 = t2.state, i2 = t2.instance, n2 = t2.options, s2 = n2.scroll, o2 = void 0 === s2 || s2, r2 = n2.resize, a2 = void 0 === r2 || r2, l2 = Wt(e2.elements.popper), c2 = [].concat(e2.scrollParents.reference, e2.scrollParents.popper);
          return o2 && c2.forEach(function(t3) {
            t3.addEventListener("scroll", i2.update, fe);
          }), a2 && l2.addEventListener("resize", i2.update, fe), function() {
            o2 && c2.forEach(function(t3) {
              t3.removeEventListener("scroll", i2.update, fe);
            }), a2 && l2.removeEventListener("resize", i2.update, fe);
          };
        }, data: {} };
        var me = { left: "right", right: "left", bottom: "top", top: "bottom" };
        function ge(t2) {
          return t2.replace(/left|right|bottom|top/g, function(t3) {
            return me[t3];
          });
        }
        var _e = { start: "end", end: "start" };
        function be(t2) {
          return t2.replace(/start|end/g, function(t3) {
            return _e[t3];
          });
        }
        function ve(t2) {
          var e2 = Wt(t2);
          return { scrollLeft: e2.pageXOffset, scrollTop: e2.pageYOffset };
        }
        function ye(t2) {
          return Vt(Gt(t2)).left + ve(t2).scrollLeft;
        }
        function we(t2) {
          var e2 = Yt(t2), i2 = e2.overflow, n2 = e2.overflowX, s2 = e2.overflowY;
          return /auto|scroll|overlay|hidden/.test(i2 + s2 + n2);
        }
        function Ee(t2) {
          return ["html", "body", "#document"].indexOf(Rt(t2)) >= 0 ? t2.ownerDocument.body : zt(t2) && we(t2) ? t2 : Ee(Zt(t2));
        }
        function Ae(t2, e2) {
          var i2;
          void 0 === e2 && (e2 = []);
          var n2 = Ee(t2), s2 = n2 === (null == (i2 = t2.ownerDocument) ? void 0 : i2.body), o2 = Wt(n2), r2 = s2 ? [o2].concat(o2.visualViewport || [], we(n2) ? n2 : []) : n2, a2 = e2.concat(r2);
          return s2 ? a2 : a2.concat(Ae(Zt(r2)));
        }
        function Te(t2) {
          return Object.assign({}, t2, { left: t2.x, top: t2.y, right: t2.x + t2.width, bottom: t2.y + t2.height });
        }
        function Oe(t2, e2) {
          return e2 === Tt ? Te(function(t3) {
            var e3 = Wt(t3), i2 = Gt(t3), n2 = e3.visualViewport, s2 = i2.clientWidth, o2 = i2.clientHeight, r2 = 0, a2 = 0;
            return n2 && (s2 = n2.width, o2 = n2.height, /^((?!chrome|android).)*safari/i.test(navigator.userAgent) || (r2 = n2.offsetLeft, a2 = n2.offsetTop)), { width: s2, height: o2, x: r2 + ye(t3), y: a2 };
          }(t2)) : zt(e2) ? function(t3) {
            var e3 = Vt(t3);
            return e3.top = e3.top + t3.clientTop, e3.left = e3.left + t3.clientLeft, e3.bottom = e3.top + t3.clientHeight, e3.right = e3.left + t3.clientWidth, e3.width = t3.clientWidth, e3.height = t3.clientHeight, e3.x = e3.left, e3.y = e3.top, e3;
          }(e2) : Te(function(t3) {
            var e3, i2 = Gt(t3), n2 = ve(t3), s2 = null == (e3 = t3.ownerDocument) ? void 0 : e3.body, o2 = ie(i2.scrollWidth, i2.clientWidth, s2 ? s2.scrollWidth : 0, s2 ? s2.clientWidth : 0), r2 = ie(i2.scrollHeight, i2.clientHeight, s2 ? s2.scrollHeight : 0, s2 ? s2.clientHeight : 0), a2 = -n2.scrollLeft + ye(t3), l2 = -n2.scrollTop;
            return "rtl" === Yt(s2 || i2).direction && (a2 += ie(i2.clientWidth, s2 ? s2.clientWidth : 0) - o2), { width: o2, height: r2, x: a2, y: l2 };
          }(Gt(t2)));
        }
        function Ce(t2) {
          var e2, i2 = t2.reference, n2 = t2.element, s2 = t2.placement, o2 = s2 ? Ut(s2) : null, r2 = s2 ? ce(s2) : null, a2 = i2.x + i2.width / 2 - n2.width / 2, l2 = i2.y + i2.height / 2 - n2.height / 2;
          switch (o2) {
            case mt:
              e2 = { x: a2, y: i2.y - n2.height };
              break;
            case gt:
              e2 = { x: a2, y: i2.y + i2.height };
              break;
            case _t:
              e2 = { x: i2.x + i2.width, y: l2 };
              break;
            case bt:
              e2 = { x: i2.x - n2.width, y: l2 };
              break;
            default:
              e2 = { x: i2.x, y: i2.y };
          }
          var c2 = o2 ? ee(o2) : null;
          if (null != c2) {
            var h2 = "y" === c2 ? "height" : "width";
            switch (r2) {
              case wt:
                e2[c2] = e2[c2] - (i2[h2] / 2 - n2[h2] / 2);
                break;
              case Et:
                e2[c2] = e2[c2] + (i2[h2] / 2 - n2[h2] / 2);
            }
          }
          return e2;
        }
        function ke(t2, e2) {
          void 0 === e2 && (e2 = {});
          var i2 = e2, n2 = i2.placement, s2 = void 0 === n2 ? t2.placement : n2, o2 = i2.boundary, r2 = void 0 === o2 ? At : o2, a2 = i2.rootBoundary, l2 = void 0 === a2 ? Tt : a2, c2 = i2.elementContext, h2 = void 0 === c2 ? Ot : c2, d2 = i2.altBoundary, u2 = void 0 !== d2 && d2, f2 = i2.padding, p2 = void 0 === f2 ? 0 : f2, m2 = re("number" != typeof p2 ? p2 : ae(p2, yt)), g2 = h2 === Ot ? Ct : Ot, _2 = t2.rects.popper, b2 = t2.elements[u2 ? g2 : h2], v2 = function(t3, e3, i3) {
            var n3 = "clippingParents" === e3 ? function(t4) {
              var e4 = Ae(Zt(t4)), i4 = ["absolute", "fixed"].indexOf(Yt(t4).position) >= 0 && zt(t4) ? te(t4) : t4;
              return $t(i4) ? e4.filter(function(t5) {
                return $t(t5) && Xt(t5, i4) && "body" !== Rt(t5);
              }) : [];
            }(t3) : [].concat(e3), s3 = [].concat(n3, [i3]), o3 = s3[0], r3 = s3.reduce(function(e4, i4) {
              var n4 = Oe(t3, i4);
              return e4.top = ie(n4.top, e4.top), e4.right = ne(n4.right, e4.right), e4.bottom = ne(n4.bottom, e4.bottom), e4.left = ie(n4.left, e4.left), e4;
            }, Oe(t3, o3));
            return r3.width = r3.right - r3.left, r3.height = r3.bottom - r3.top, r3.x = r3.left, r3.y = r3.top, r3;
          }($t(b2) ? b2 : b2.contextElement || Gt(t2.elements.popper), r2, l2), y2 = Vt(t2.elements.reference), w2 = Ce({ reference: y2, element: _2, strategy: "absolute", placement: s2 }), E2 = Te(Object.assign({}, _2, w2)), A2 = h2 === Ot ? E2 : y2, T2 = { top: v2.top - A2.top + m2.top, bottom: A2.bottom - v2.bottom + m2.bottom, left: v2.left - A2.left + m2.left, right: A2.right - v2.right + m2.right }, O2 = t2.modifiersData.offset;
          if (h2 === Ot && O2) {
            var C2 = O2[s2];
            Object.keys(T2).forEach(function(t3) {
              var e3 = [_t, gt].indexOf(t3) >= 0 ? 1 : -1, i3 = [mt, gt].indexOf(t3) >= 0 ? "y" : "x";
              T2[t3] += C2[i3] * e3;
            });
          }
          return T2;
        }
        function Le(t2, e2) {
          void 0 === e2 && (e2 = {});
          var i2 = e2, n2 = i2.placement, s2 = i2.boundary, o2 = i2.rootBoundary, r2 = i2.padding, a2 = i2.flipVariations, l2 = i2.allowedAutoPlacements, c2 = void 0 === l2 ? Lt : l2, h2 = ce(n2), d2 = h2 ? a2 ? kt : kt.filter(function(t3) {
            return ce(t3) === h2;
          }) : yt, u2 = d2.filter(function(t3) {
            return c2.indexOf(t3) >= 0;
          });
          0 === u2.length && (u2 = d2);
          var f2 = u2.reduce(function(e3, i3) {
            return e3[i3] = ke(t2, { placement: i3, boundary: s2, rootBoundary: o2, padding: r2 })[Ut(i3)], e3;
          }, {});
          return Object.keys(f2).sort(function(t3, e3) {
            return f2[t3] - f2[e3];
          });
        }
        const xe = { name: "flip", enabled: true, phase: "main", fn: function(t2) {
          var e2 = t2.state, i2 = t2.options, n2 = t2.name;
          if (!e2.modifiersData[n2]._skip) {
            for (var s2 = i2.mainAxis, o2 = void 0 === s2 || s2, r2 = i2.altAxis, a2 = void 0 === r2 || r2, l2 = i2.fallbackPlacements, c2 = i2.padding, h2 = i2.boundary, d2 = i2.rootBoundary, u2 = i2.altBoundary, f2 = i2.flipVariations, p2 = void 0 === f2 || f2, m2 = i2.allowedAutoPlacements, g2 = e2.options.placement, _2 = Ut(g2), b2 = l2 || (_2 !== g2 && p2 ? function(t3) {
              if (Ut(t3) === vt)
                return [];
              var e3 = ge(t3);
              return [be(t3), e3, be(e3)];
            }(g2) : [ge(g2)]), v2 = [g2].concat(b2).reduce(function(t3, i3) {
              return t3.concat(Ut(i3) === vt ? Le(e2, { placement: i3, boundary: h2, rootBoundary: d2, padding: c2, flipVariations: p2, allowedAutoPlacements: m2 }) : i3);
            }, []), y2 = e2.rects.reference, w2 = e2.rects.popper, E2 = /* @__PURE__ */ new Map(), A2 = true, T2 = v2[0], O2 = 0; O2 < v2.length; O2++) {
              var C2 = v2[O2], k2 = Ut(C2), L2 = ce(C2) === wt, x2 = [mt, gt].indexOf(k2) >= 0, D2 = x2 ? "width" : "height", S2 = ke(e2, { placement: C2, boundary: h2, rootBoundary: d2, altBoundary: u2, padding: c2 }), N2 = x2 ? L2 ? _t : bt : L2 ? gt : mt;
              y2[D2] > w2[D2] && (N2 = ge(N2));
              var I2 = ge(N2), P2 = [];
              if (o2 && P2.push(S2[k2] <= 0), a2 && P2.push(S2[N2] <= 0, S2[I2] <= 0), P2.every(function(t3) {
                return t3;
              })) {
                T2 = C2, A2 = false;
                break;
              }
              E2.set(C2, P2);
            }
            if (A2)
              for (var j2 = function(t3) {
                var e3 = v2.find(function(e4) {
                  var i3 = E2.get(e4);
                  if (i3)
                    return i3.slice(0, t3).every(function(t4) {
                      return t4;
                    });
                });
                if (e3)
                  return T2 = e3, "break";
              }, M2 = p2 ? 3 : 1; M2 > 0 && "break" !== j2(M2); M2--)
                ;
            e2.placement !== T2 && (e2.modifiersData[n2]._skip = true, e2.placement = T2, e2.reset = true);
          }
        }, requiresIfExists: ["offset"], data: { _skip: false } };
        function De(t2, e2, i2) {
          return void 0 === i2 && (i2 = { x: 0, y: 0 }), { top: t2.top - e2.height - i2.y, right: t2.right - e2.width + i2.x, bottom: t2.bottom - e2.height + i2.y, left: t2.left - e2.width - i2.x };
        }
        function Se(t2) {
          return [mt, _t, gt, bt].some(function(e2) {
            return t2[e2] >= 0;
          });
        }
        const Ne = { name: "hide", enabled: true, phase: "main", requiresIfExists: ["preventOverflow"], fn: function(t2) {
          var e2 = t2.state, i2 = t2.name, n2 = e2.rects.reference, s2 = e2.rects.popper, o2 = e2.modifiersData.preventOverflow, r2 = ke(e2, { elementContext: "reference" }), a2 = ke(e2, { altBoundary: true }), l2 = De(r2, n2), c2 = De(a2, s2, o2), h2 = Se(l2), d2 = Se(c2);
          e2.modifiersData[i2] = { referenceClippingOffsets: l2, popperEscapeOffsets: c2, isReferenceHidden: h2, hasPopperEscaped: d2 }, e2.attributes.popper = Object.assign({}, e2.attributes.popper, { "data-popper-reference-hidden": h2, "data-popper-escaped": d2 });
        } }, Ie = { name: "offset", enabled: true, phase: "main", requires: ["popperOffsets"], fn: function(t2) {
          var e2 = t2.state, i2 = t2.options, n2 = t2.name, s2 = i2.offset, o2 = void 0 === s2 ? [0, 0] : s2, r2 = Lt.reduce(function(t3, i3) {
            return t3[i3] = function(t4, e3, i4) {
              var n3 = Ut(t4), s3 = [bt, mt].indexOf(n3) >= 0 ? -1 : 1, o3 = "function" == typeof i4 ? i4(Object.assign({}, e3, { placement: t4 })) : i4, r3 = o3[0], a3 = o3[1];
              return r3 = r3 || 0, a3 = (a3 || 0) * s3, [bt, _t].indexOf(n3) >= 0 ? { x: a3, y: r3 } : { x: r3, y: a3 };
            }(i3, e2.rects, o2), t3;
          }, {}), a2 = r2[e2.placement], l2 = a2.x, c2 = a2.y;
          null != e2.modifiersData.popperOffsets && (e2.modifiersData.popperOffsets.x += l2, e2.modifiersData.popperOffsets.y += c2), e2.modifiersData[n2] = r2;
        } }, Pe = { name: "popperOffsets", enabled: true, phase: "read", fn: function(t2) {
          var e2 = t2.state, i2 = t2.name;
          e2.modifiersData[i2] = Ce({ reference: e2.rects.reference, element: e2.rects.popper, strategy: "absolute", placement: e2.placement });
        }, data: {} }, je = { name: "preventOverflow", enabled: true, phase: "main", fn: function(t2) {
          var e2 = t2.state, i2 = t2.options, n2 = t2.name, s2 = i2.mainAxis, o2 = void 0 === s2 || s2, r2 = i2.altAxis, a2 = void 0 !== r2 && r2, l2 = i2.boundary, c2 = i2.rootBoundary, h2 = i2.altBoundary, d2 = i2.padding, u2 = i2.tether, f2 = void 0 === u2 || u2, p2 = i2.tetherOffset, m2 = void 0 === p2 ? 0 : p2, g2 = ke(e2, { boundary: l2, rootBoundary: c2, padding: d2, altBoundary: h2 }), _2 = Ut(e2.placement), b2 = ce(e2.placement), v2 = !b2, y2 = ee(_2), w2 = "x" === y2 ? "y" : "x", E2 = e2.modifiersData.popperOffsets, A2 = e2.rects.reference, T2 = e2.rects.popper, O2 = "function" == typeof m2 ? m2(Object.assign({}, e2.rects, { placement: e2.placement })) : m2, C2 = { x: 0, y: 0 };
          if (E2) {
            if (o2 || a2) {
              var k2 = "y" === y2 ? mt : bt, L2 = "y" === y2 ? gt : _t, x2 = "y" === y2 ? "height" : "width", D2 = E2[y2], S2 = E2[y2] + g2[k2], N2 = E2[y2] - g2[L2], I2 = f2 ? -T2[x2] / 2 : 0, P2 = b2 === wt ? A2[x2] : T2[x2], j2 = b2 === wt ? -T2[x2] : -A2[x2], M2 = e2.elements.arrow, H2 = f2 && M2 ? Kt(M2) : { width: 0, height: 0 }, B2 = e2.modifiersData["arrow#persistent"] ? e2.modifiersData["arrow#persistent"].padding : { top: 0, right: 0, bottom: 0, left: 0 }, R2 = B2[k2], W2 = B2[L2], $2 = oe(0, A2[x2], H2[x2]), z2 = v2 ? A2[x2] / 2 - I2 - $2 - R2 - O2 : P2 - $2 - R2 - O2, q2 = v2 ? -A2[x2] / 2 + I2 + $2 + W2 + O2 : j2 + $2 + W2 + O2, F2 = e2.elements.arrow && te(e2.elements.arrow), U2 = F2 ? "y" === y2 ? F2.clientTop || 0 : F2.clientLeft || 0 : 0, V2 = e2.modifiersData.offset ? e2.modifiersData.offset[e2.placement][y2] : 0, K2 = E2[y2] + z2 - V2 - U2, X2 = E2[y2] + q2 - V2;
              if (o2) {
                var Y2 = oe(f2 ? ne(S2, K2) : S2, D2, f2 ? ie(N2, X2) : N2);
                E2[y2] = Y2, C2[y2] = Y2 - D2;
              }
              if (a2) {
                var Q2 = "x" === y2 ? mt : bt, G2 = "x" === y2 ? gt : _t, Z2 = E2[w2], J2 = Z2 + g2[Q2], tt2 = Z2 - g2[G2], et2 = oe(f2 ? ne(J2, K2) : J2, Z2, f2 ? ie(tt2, X2) : tt2);
                E2[w2] = et2, C2[w2] = et2 - Z2;
              }
            }
            e2.modifiersData[n2] = C2;
          }
        }, requiresIfExists: ["offset"] };
        function Me(t2, e2, i2) {
          void 0 === i2 && (i2 = false);
          var n2 = zt(e2);
          zt(e2) && function(t3) {
            var e3 = t3.getBoundingClientRect();
            e3.width, t3.offsetWidth, e3.height, t3.offsetHeight;
          }(e2);
          var s2, o2, r2 = Gt(e2), a2 = Vt(t2), l2 = { scrollLeft: 0, scrollTop: 0 }, c2 = { x: 0, y: 0 };
          return (n2 || !n2 && !i2) && (("body" !== Rt(e2) || we(r2)) && (l2 = (s2 = e2) !== Wt(s2) && zt(s2) ? { scrollLeft: (o2 = s2).scrollLeft, scrollTop: o2.scrollTop } : ve(s2)), zt(e2) ? ((c2 = Vt(e2)).x += e2.clientLeft, c2.y += e2.clientTop) : r2 && (c2.x = ye(r2))), { x: a2.left + l2.scrollLeft - c2.x, y: a2.top + l2.scrollTop - c2.y, width: a2.width, height: a2.height };
        }
        function He(t2) {
          var e2 = /* @__PURE__ */ new Map(), i2 = /* @__PURE__ */ new Set(), n2 = [];
          function s2(t3) {
            i2.add(t3.name), [].concat(t3.requires || [], t3.requiresIfExists || []).forEach(function(t4) {
              if (!i2.has(t4)) {
                var n3 = e2.get(t4);
                n3 && s2(n3);
              }
            }), n2.push(t3);
          }
          return t2.forEach(function(t3) {
            e2.set(t3.name, t3);
          }), t2.forEach(function(t3) {
            i2.has(t3.name) || s2(t3);
          }), n2;
        }
        var Be = { placement: "bottom", modifiers: [], strategy: "absolute" };
        function Re() {
          for (var t2 = arguments.length, e2 = new Array(t2), i2 = 0; i2 < t2; i2++)
            e2[i2] = arguments[i2];
          return !e2.some(function(t3) {
            return !(t3 && "function" == typeof t3.getBoundingClientRect);
          });
        }
        function We(t2) {
          void 0 === t2 && (t2 = {});
          var e2 = t2, i2 = e2.defaultModifiers, n2 = void 0 === i2 ? [] : i2, s2 = e2.defaultOptions, o2 = void 0 === s2 ? Be : s2;
          return function(t3, e3, i3) {
            void 0 === i3 && (i3 = o2);
            var s3, r2, a2 = { placement: "bottom", orderedModifiers: [], options: Object.assign({}, Be, o2), modifiersData: {}, elements: { reference: t3, popper: e3 }, attributes: {}, styles: {} }, l2 = [], c2 = false, h2 = { state: a2, setOptions: function(i4) {
              var s4 = "function" == typeof i4 ? i4(a2.options) : i4;
              d2(), a2.options = Object.assign({}, o2, a2.options, s4), a2.scrollParents = { reference: $t(t3) ? Ae(t3) : t3.contextElement ? Ae(t3.contextElement) : [], popper: Ae(e3) };
              var r3, c3, u2 = function(t4) {
                var e4 = He(t4);
                return Bt.reduce(function(t5, i5) {
                  return t5.concat(e4.filter(function(t6) {
                    return t6.phase === i5;
                  }));
                }, []);
              }((r3 = [].concat(n2, a2.options.modifiers), c3 = r3.reduce(function(t4, e4) {
                var i5 = t4[e4.name];
                return t4[e4.name] = i5 ? Object.assign({}, i5, e4, { options: Object.assign({}, i5.options, e4.options), data: Object.assign({}, i5.data, e4.data) }) : e4, t4;
              }, {}), Object.keys(c3).map(function(t4) {
                return c3[t4];
              })));
              return a2.orderedModifiers = u2.filter(function(t4) {
                return t4.enabled;
              }), a2.orderedModifiers.forEach(function(t4) {
                var e4 = t4.name, i5 = t4.options, n3 = void 0 === i5 ? {} : i5, s5 = t4.effect;
                if ("function" == typeof s5) {
                  var o3 = s5({ state: a2, name: e4, instance: h2, options: n3 });
                  l2.push(o3 || function() {
                  });
                }
              }), h2.update();
            }, forceUpdate: function() {
              if (!c2) {
                var t4 = a2.elements, e4 = t4.reference, i4 = t4.popper;
                if (Re(e4, i4)) {
                  a2.rects = { reference: Me(e4, te(i4), "fixed" === a2.options.strategy), popper: Kt(i4) }, a2.reset = false, a2.placement = a2.options.placement, a2.orderedModifiers.forEach(function(t5) {
                    return a2.modifiersData[t5.name] = Object.assign({}, t5.data);
                  });
                  for (var n3 = 0; n3 < a2.orderedModifiers.length; n3++)
                    if (true !== a2.reset) {
                      var s4 = a2.orderedModifiers[n3], o3 = s4.fn, r3 = s4.options, l3 = void 0 === r3 ? {} : r3, d3 = s4.name;
                      "function" == typeof o3 && (a2 = o3({ state: a2, options: l3, name: d3, instance: h2 }) || a2);
                    } else
                      a2.reset = false, n3 = -1;
                }
              }
            }, update: (s3 = function() {
              return new Promise(function(t4) {
                h2.forceUpdate(), t4(a2);
              });
            }, function() {
              return r2 || (r2 = new Promise(function(t4) {
                Promise.resolve().then(function() {
                  r2 = void 0, t4(s3());
                });
              })), r2;
            }), destroy: function() {
              d2(), c2 = true;
            } };
            if (!Re(t3, e3))
              return h2;
            function d2() {
              l2.forEach(function(t4) {
                return t4();
              }), l2 = [];
            }
            return h2.setOptions(i3).then(function(t4) {
              !c2 && i3.onFirstUpdate && i3.onFirstUpdate(t4);
            }), h2;
          };
        }
        var $e = We(), ze = We({ defaultModifiers: [pe, Pe, ue, Ft] }), qe = We({ defaultModifiers: [pe, Pe, ue, Ft, Ie, xe, je, le, Ne] });
        const Fe = Object.freeze({ __proto__: null, popperGenerator: We, detectOverflow: ke, createPopperBase: $e, createPopper: qe, createPopperLite: ze, top: mt, bottom: gt, right: _t, left: bt, auto: vt, basePlacements: yt, start: wt, end: Et, clippingParents: At, viewport: Tt, popper: Ot, reference: Ct, variationPlacements: kt, placements: Lt, beforeRead: xt, read: Dt, afterRead: St, beforeMain: Nt, main: It, afterMain: Pt, beforeWrite: jt, write: Mt, afterWrite: Ht, modifierPhases: Bt, applyStyles: Ft, arrow: le, computeStyles: ue, eventListeners: pe, flip: xe, hide: Ne, offset: Ie, popperOffsets: Pe, preventOverflow: je }), Ue = "dropdown", Ve = "Escape", Ke = "Space", Xe = "ArrowUp", Ye = "ArrowDown", Qe = new RegExp("ArrowUp|ArrowDown|Escape"), Ge = "click.bs.dropdown.data-api", Ze = "keydown.bs.dropdown.data-api", Je = "show", ti = '[data-bs-toggle="dropdown"]', ei = ".dropdown-menu", ii = m() ? "top-end" : "top-start", ni = m() ? "top-start" : "top-end", si = m() ? "bottom-end" : "bottom-start", oi = m() ? "bottom-start" : "bottom-end", ri = m() ? "left-start" : "right-start", ai = m() ? "right-start" : "left-start", li = { offset: [0, 2], boundary: "clippingParents", reference: "toggle", display: "dynamic", popperConfig: null, autoClose: true }, ci = { offset: "(array|string|function)", boundary: "(string|element)", reference: "(string|element|object)", display: "string", popperConfig: "(null|object|function)", autoClose: "(boolean|string)" };
        class hi extends B {
          constructor(t2, e2) {
            super(t2), this._popper = null, this._config = this._getConfig(e2), this._menu = this._getMenuElement(), this._inNavbar = this._detectNavbar();
          }
          static get Default() {
            return li;
          }
          static get DefaultType() {
            return ci;
          }
          static get NAME() {
            return Ue;
          }
          toggle() {
            return this._isShown() ? this.hide() : this.show();
          }
          show() {
            if (c(this._element) || this._isShown(this._menu))
              return;
            const t2 = { relatedTarget: this._element };
            if (j.trigger(this._element, "show.bs.dropdown", t2).defaultPrevented)
              return;
            const e2 = hi.getParentFromElement(this._element);
            this._inNavbar ? U.setDataAttribute(this._menu, "popper", "none") : this._createPopper(e2), "ontouchstart" in document.documentElement && !e2.closest(".navbar-nav") && [].concat(...document.body.children).forEach((t3) => j.on(t3, "mouseover", d)), this._element.focus(), this._element.setAttribute("aria-expanded", true), this._menu.classList.add(Je), this._element.classList.add(Je), j.trigger(this._element, "shown.bs.dropdown", t2);
          }
          hide() {
            if (c(this._element) || !this._isShown(this._menu))
              return;
            const t2 = { relatedTarget: this._element };
            this._completeHide(t2);
          }
          dispose() {
            this._popper && this._popper.destroy(), super.dispose();
          }
          update() {
            this._inNavbar = this._detectNavbar(), this._popper && this._popper.update();
          }
          _completeHide(t2) {
            j.trigger(this._element, "hide.bs.dropdown", t2).defaultPrevented || ("ontouchstart" in document.documentElement && [].concat(...document.body.children).forEach((t3) => j.off(t3, "mouseover", d)), this._popper && this._popper.destroy(), this._menu.classList.remove(Je), this._element.classList.remove(Je), this._element.setAttribute("aria-expanded", "false"), U.removeDataAttribute(this._menu, "popper"), j.trigger(this._element, "hidden.bs.dropdown", t2));
          }
          _getConfig(t2) {
            if (t2 = { ...this.constructor.Default, ...U.getDataAttributes(this._element), ...t2 }, a(Ue, t2, this.constructor.DefaultType), "object" == typeof t2.reference && !o(t2.reference) && "function" != typeof t2.reference.getBoundingClientRect)
              throw new TypeError(`${Ue.toUpperCase()}: Option "reference" provided type "object" without a required "getBoundingClientRect" method.`);
            return t2;
          }
          _createPopper(t2) {
            if (void 0 === Fe)
              throw new TypeError("Bootstrap's dropdowns require Popper (https://popper.js.org)");
            let e2 = this._element;
            "parent" === this._config.reference ? e2 = t2 : o(this._config.reference) ? e2 = r(this._config.reference) : "object" == typeof this._config.reference && (e2 = this._config.reference);
            const i2 = this._getPopperConfig(), n2 = i2.modifiers.find((t3) => "applyStyles" === t3.name && false === t3.enabled);
            this._popper = qe(e2, this._menu, i2), n2 && U.setDataAttribute(this._menu, "popper", "static");
          }
          _isShown(t2 = this._element) {
            return t2.classList.contains(Je);
          }
          _getMenuElement() {
            return V.next(this._element, ei)[0];
          }
          _getPlacement() {
            const t2 = this._element.parentNode;
            if (t2.classList.contains("dropend"))
              return ri;
            if (t2.classList.contains("dropstart"))
              return ai;
            const e2 = "end" === getComputedStyle(this._menu).getPropertyValue("--bs-position").trim();
            return t2.classList.contains("dropup") ? e2 ? ni : ii : e2 ? oi : si;
          }
          _detectNavbar() {
            return null !== this._element.closest(".navbar");
          }
          _getOffset() {
            const { offset: t2 } = this._config;
            return "string" == typeof t2 ? t2.split(",").map((t3) => Number.parseInt(t3, 10)) : "function" == typeof t2 ? (e2) => t2(e2, this._element) : t2;
          }
          _getPopperConfig() {
            const t2 = { placement: this._getPlacement(), modifiers: [{ name: "preventOverflow", options: { boundary: this._config.boundary } }, { name: "offset", options: { offset: this._getOffset() } }] };
            return "static" === this._config.display && (t2.modifiers = [{ name: "applyStyles", enabled: false }]), { ...t2, ..."function" == typeof this._config.popperConfig ? this._config.popperConfig(t2) : this._config.popperConfig };
          }
          _selectMenuItem({ key: t2, target: e2 }) {
            const i2 = V.find(".dropdown-menu .dropdown-item:not(.disabled):not(:disabled)", this._menu).filter(l);
            i2.length && v(i2, e2, t2 === Ye, !i2.includes(e2)).focus();
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = hi.getOrCreateInstance(this, t2);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2]();
              }
            });
          }
          static clearMenus(t2) {
            if (t2 && (2 === t2.button || "keyup" === t2.type && "Tab" !== t2.key))
              return;
            const e2 = V.find(ti);
            for (let i2 = 0, n2 = e2.length; i2 < n2; i2++) {
              const n3 = hi.getInstance(e2[i2]);
              if (!n3 || false === n3._config.autoClose)
                continue;
              if (!n3._isShown())
                continue;
              const s2 = { relatedTarget: n3._element };
              if (t2) {
                const e3 = t2.composedPath(), i3 = e3.includes(n3._menu);
                if (e3.includes(n3._element) || "inside" === n3._config.autoClose && !i3 || "outside" === n3._config.autoClose && i3)
                  continue;
                if (n3._menu.contains(t2.target) && ("keyup" === t2.type && "Tab" === t2.key || /input|select|option|textarea|form/i.test(t2.target.tagName)))
                  continue;
                "click" === t2.type && (s2.clickEvent = t2);
              }
              n3._completeHide(s2);
            }
          }
          static getParentFromElement(t2) {
            return n(t2) || t2.parentNode;
          }
          static dataApiKeydownHandler(t2) {
            if (/input|textarea/i.test(t2.target.tagName) ? t2.key === Ke || t2.key !== Ve && (t2.key !== Ye && t2.key !== Xe || t2.target.closest(ei)) : !Qe.test(t2.key))
              return;
            const e2 = this.classList.contains(Je);
            if (!e2 && t2.key === Ve)
              return;
            if (t2.preventDefault(), t2.stopPropagation(), c(this))
              return;
            const i2 = this.matches(ti) ? this : V.prev(this, ti)[0], n2 = hi.getOrCreateInstance(i2);
            if (t2.key !== Ve)
              return t2.key === Xe || t2.key === Ye ? (e2 || n2.show(), void n2._selectMenuItem(t2)) : void (e2 && t2.key !== Ke || hi.clearMenus());
            n2.hide();
          }
        }
        j.on(document, Ze, ti, hi.dataApiKeydownHandler), j.on(document, Ze, ei, hi.dataApiKeydownHandler), j.on(document, Ge, hi.clearMenus), j.on(document, "keyup.bs.dropdown.data-api", hi.clearMenus), j.on(document, Ge, ti, function(t2) {
          t2.preventDefault(), hi.getOrCreateInstance(this).toggle();
        }), g(hi);
        const di = ".fixed-top, .fixed-bottom, .is-fixed, .sticky-top", ui = ".sticky-top";
        class fi {
          constructor() {
            this._element = document.body;
          }
          getWidth() {
            const t2 = document.documentElement.clientWidth;
            return Math.abs(window.innerWidth - t2);
          }
          hide() {
            const t2 = this.getWidth();
            this._disableOverFlow(), this._setElementAttributes(this._element, "paddingRight", (e2) => e2 + t2), this._setElementAttributes(di, "paddingRight", (e2) => e2 + t2), this._setElementAttributes(ui, "marginRight", (e2) => e2 - t2);
          }
          _disableOverFlow() {
            this._saveInitialAttribute(this._element, "overflow"), this._element.style.overflow = "hidden";
          }
          _setElementAttributes(t2, e2, i2) {
            const n2 = this.getWidth();
            this._applyManipulationCallback(t2, (t3) => {
              if (t3 !== this._element && window.innerWidth > t3.clientWidth + n2)
                return;
              this._saveInitialAttribute(t3, e2);
              const s2 = window.getComputedStyle(t3)[e2];
              t3.style[e2] = `${i2(Number.parseFloat(s2))}px`;
            });
          }
          reset() {
            this._resetElementAttributes(this._element, "overflow"), this._resetElementAttributes(this._element, "paddingRight"), this._resetElementAttributes(di, "paddingRight"), this._resetElementAttributes(ui, "marginRight");
          }
          _saveInitialAttribute(t2, e2) {
            const i2 = t2.style[e2];
            i2 && U.setDataAttribute(t2, e2, i2);
          }
          _resetElementAttributes(t2, e2) {
            this._applyManipulationCallback(t2, (t3) => {
              const i2 = U.getDataAttribute(t3, e2);
              void 0 === i2 ? t3.style.removeProperty(e2) : (U.removeDataAttribute(t3, e2), t3.style[e2] = i2);
            });
          }
          _applyManipulationCallback(t2, e2) {
            o(t2) ? e2(t2) : V.find(t2, this._element).forEach(e2);
          }
          isOverflowing() {
            return this.getWidth() > 0;
          }
        }
        const pi = { className: "modal-backdrop", isVisible: true, isAnimated: false, rootElement: "body", clickCallback: null }, mi = { className: "string", isVisible: "boolean", isAnimated: "boolean", rootElement: "(element|string)", clickCallback: "(function|null)" }, gi = "show", _i = "mousedown.bs.backdrop";
        class bi {
          constructor(t2) {
            this._config = this._getConfig(t2), this._isAppended = false, this._element = null;
          }
          show(t2) {
            this._config.isVisible ? (this._append(), this._config.isAnimated && u(this._getElement()), this._getElement().classList.add(gi), this._emulateAnimation(() => {
              _(t2);
            })) : _(t2);
          }
          hide(t2) {
            this._config.isVisible ? (this._getElement().classList.remove(gi), this._emulateAnimation(() => {
              this.dispose(), _(t2);
            })) : _(t2);
          }
          _getElement() {
            if (!this._element) {
              const t2 = document.createElement("div");
              t2.className = this._config.className, this._config.isAnimated && t2.classList.add("fade"), this._element = t2;
            }
            return this._element;
          }
          _getConfig(t2) {
            return (t2 = { ...pi, ..."object" == typeof t2 ? t2 : {} }).rootElement = r(t2.rootElement), a("backdrop", t2, mi), t2;
          }
          _append() {
            this._isAppended || (this._config.rootElement.append(this._getElement()), j.on(this._getElement(), _i, () => {
              _(this._config.clickCallback);
            }), this._isAppended = true);
          }
          dispose() {
            this._isAppended && (j.off(this._element, _i), this._element.remove(), this._isAppended = false);
          }
          _emulateAnimation(t2) {
            b(t2, this._getElement(), this._config.isAnimated);
          }
        }
        const vi = { trapElement: null, autofocus: true }, yi = { trapElement: "element", autofocus: "boolean" }, wi = ".bs.focustrap", Ei = "backward";
        class Ai {
          constructor(t2) {
            this._config = this._getConfig(t2), this._isActive = false, this._lastTabNavDirection = null;
          }
          activate() {
            const { trapElement: t2, autofocus: e2 } = this._config;
            this._isActive || (e2 && t2.focus(), j.off(document, wi), j.on(document, "focusin.bs.focustrap", (t3) => this._handleFocusin(t3)), j.on(document, "keydown.tab.bs.focustrap", (t3) => this._handleKeydown(t3)), this._isActive = true);
          }
          deactivate() {
            this._isActive && (this._isActive = false, j.off(document, wi));
          }
          _handleFocusin(t2) {
            const { target: e2 } = t2, { trapElement: i2 } = this._config;
            if (e2 === document || e2 === i2 || i2.contains(e2))
              return;
            const n2 = V.focusableChildren(i2);
            0 === n2.length ? i2.focus() : this._lastTabNavDirection === Ei ? n2[n2.length - 1].focus() : n2[0].focus();
          }
          _handleKeydown(t2) {
            "Tab" === t2.key && (this._lastTabNavDirection = t2.shiftKey ? Ei : "forward");
          }
          _getConfig(t2) {
            return t2 = { ...vi, ..."object" == typeof t2 ? t2 : {} }, a("focustrap", t2, yi), t2;
          }
        }
        const Ti = "modal", Oi = "Escape", Ci = { backdrop: true, keyboard: true, focus: true }, ki = { backdrop: "(boolean|string)", keyboard: "boolean", focus: "boolean" }, Li = "hidden.bs.modal", xi = "show.bs.modal", Di = "resize.bs.modal", Si = "click.dismiss.bs.modal", Ni = "keydown.dismiss.bs.modal", Ii = "mousedown.dismiss.bs.modal", Pi = "modal-open", ji = "show", Mi = "modal-static";
        class Hi extends B {
          constructor(t2, e2) {
            super(t2), this._config = this._getConfig(e2), this._dialog = V.findOne(".modal-dialog", this._element), this._backdrop = this._initializeBackDrop(), this._focustrap = this._initializeFocusTrap(), this._isShown = false, this._ignoreBackdropClick = false, this._isTransitioning = false, this._scrollBar = new fi();
          }
          static get Default() {
            return Ci;
          }
          static get NAME() {
            return Ti;
          }
          toggle(t2) {
            return this._isShown ? this.hide() : this.show(t2);
          }
          show(t2) {
            this._isShown || this._isTransitioning || j.trigger(this._element, xi, { relatedTarget: t2 }).defaultPrevented || (this._isShown = true, this._isAnimated() && (this._isTransitioning = true), this._scrollBar.hide(), document.body.classList.add(Pi), this._adjustDialog(), this._setEscapeEvent(), this._setResizeEvent(), j.on(this._dialog, Ii, () => {
              j.one(this._element, "mouseup.dismiss.bs.modal", (t3) => {
                t3.target === this._element && (this._ignoreBackdropClick = true);
              });
            }), this._showBackdrop(() => this._showElement(t2)));
          }
          hide() {
            if (!this._isShown || this._isTransitioning)
              return;
            if (j.trigger(this._element, "hide.bs.modal").defaultPrevented)
              return;
            this._isShown = false;
            const t2 = this._isAnimated();
            t2 && (this._isTransitioning = true), this._setEscapeEvent(), this._setResizeEvent(), this._focustrap.deactivate(), this._element.classList.remove(ji), j.off(this._element, Si), j.off(this._dialog, Ii), this._queueCallback(() => this._hideModal(), this._element, t2);
          }
          dispose() {
            [window, this._dialog].forEach((t2) => j.off(t2, ".bs.modal")), this._backdrop.dispose(), this._focustrap.deactivate(), super.dispose();
          }
          handleUpdate() {
            this._adjustDialog();
          }
          _initializeBackDrop() {
            return new bi({ isVisible: Boolean(this._config.backdrop), isAnimated: this._isAnimated() });
          }
          _initializeFocusTrap() {
            return new Ai({ trapElement: this._element });
          }
          _getConfig(t2) {
            return t2 = { ...Ci, ...U.getDataAttributes(this._element), ..."object" == typeof t2 ? t2 : {} }, a(Ti, t2, ki), t2;
          }
          _showElement(t2) {
            const e2 = this._isAnimated(), i2 = V.findOne(".modal-body", this._dialog);
            this._element.parentNode && this._element.parentNode.nodeType === Node.ELEMENT_NODE || document.body.append(this._element), this._element.style.display = "block", this._element.removeAttribute("aria-hidden"), this._element.setAttribute("aria-modal", true), this._element.setAttribute("role", "dialog"), this._element.scrollTop = 0, i2 && (i2.scrollTop = 0), e2 && u(this._element), this._element.classList.add(ji), this._queueCallback(() => {
              this._config.focus && this._focustrap.activate(), this._isTransitioning = false, j.trigger(this._element, "shown.bs.modal", { relatedTarget: t2 });
            }, this._dialog, e2);
          }
          _setEscapeEvent() {
            this._isShown ? j.on(this._element, Ni, (t2) => {
              this._config.keyboard && t2.key === Oi ? (t2.preventDefault(), this.hide()) : this._config.keyboard || t2.key !== Oi || this._triggerBackdropTransition();
            }) : j.off(this._element, Ni);
          }
          _setResizeEvent() {
            this._isShown ? j.on(window, Di, () => this._adjustDialog()) : j.off(window, Di);
          }
          _hideModal() {
            this._element.style.display = "none", this._element.setAttribute("aria-hidden", true), this._element.removeAttribute("aria-modal"), this._element.removeAttribute("role"), this._isTransitioning = false, this._backdrop.hide(() => {
              document.body.classList.remove(Pi), this._resetAdjustments(), this._scrollBar.reset(), j.trigger(this._element, Li);
            });
          }
          _showBackdrop(t2) {
            j.on(this._element, Si, (t3) => {
              this._ignoreBackdropClick ? this._ignoreBackdropClick = false : t3.target === t3.currentTarget && (true === this._config.backdrop ? this.hide() : "static" === this._config.backdrop && this._triggerBackdropTransition());
            }), this._backdrop.show(t2);
          }
          _isAnimated() {
            return this._element.classList.contains("fade");
          }
          _triggerBackdropTransition() {
            if (j.trigger(this._element, "hidePrevented.bs.modal").defaultPrevented)
              return;
            const { classList: t2, scrollHeight: e2, style: i2 } = this._element, n2 = e2 > document.documentElement.clientHeight;
            !n2 && "hidden" === i2.overflowY || t2.contains(Mi) || (n2 || (i2.overflowY = "hidden"), t2.add(Mi), this._queueCallback(() => {
              t2.remove(Mi), n2 || this._queueCallback(() => {
                i2.overflowY = "";
              }, this._dialog);
            }, this._dialog), this._element.focus());
          }
          _adjustDialog() {
            const t2 = this._element.scrollHeight > document.documentElement.clientHeight, e2 = this._scrollBar.getWidth(), i2 = e2 > 0;
            (!i2 && t2 && !m() || i2 && !t2 && m()) && (this._element.style.paddingLeft = `${e2}px`), (i2 && !t2 && !m() || !i2 && t2 && m()) && (this._element.style.paddingRight = `${e2}px`);
          }
          _resetAdjustments() {
            this._element.style.paddingLeft = "", this._element.style.paddingRight = "";
          }
          static jQueryInterface(t2, e2) {
            return this.each(function() {
              const i2 = Hi.getOrCreateInstance(this, t2);
              if ("string" == typeof t2) {
                if (void 0 === i2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                i2[t2](e2);
              }
            });
          }
        }
        j.on(document, "click.bs.modal.data-api", '[data-bs-toggle="modal"]', function(t2) {
          const e2 = n(this);
          ["A", "AREA"].includes(this.tagName) && t2.preventDefault(), j.one(e2, xi, (t3) => {
            t3.defaultPrevented || j.one(e2, Li, () => {
              l(this) && this.focus();
            });
          });
          const i2 = V.findOne(".modal.show");
          i2 && Hi.getInstance(i2).hide(), Hi.getOrCreateInstance(e2).toggle(this);
        }), R(Hi), g(Hi);
        const Bi = "offcanvas", Ri = { backdrop: true, keyboard: true, scroll: false }, Wi = { backdrop: "boolean", keyboard: "boolean", scroll: "boolean" }, $i = "show", zi = ".offcanvas.show", qi = "hidden.bs.offcanvas";
        class Fi extends B {
          constructor(t2, e2) {
            super(t2), this._config = this._getConfig(e2), this._isShown = false, this._backdrop = this._initializeBackDrop(), this._focustrap = this._initializeFocusTrap(), this._addEventListeners();
          }
          static get NAME() {
            return Bi;
          }
          static get Default() {
            return Ri;
          }
          toggle(t2) {
            return this._isShown ? this.hide() : this.show(t2);
          }
          show(t2) {
            this._isShown || j.trigger(this._element, "show.bs.offcanvas", { relatedTarget: t2 }).defaultPrevented || (this._isShown = true, this._element.style.visibility = "visible", this._backdrop.show(), this._config.scroll || new fi().hide(), this._element.removeAttribute("aria-hidden"), this._element.setAttribute("aria-modal", true), this._element.setAttribute("role", "dialog"), this._element.classList.add($i), this._queueCallback(() => {
              this._config.scroll || this._focustrap.activate(), j.trigger(this._element, "shown.bs.offcanvas", { relatedTarget: t2 });
            }, this._element, true));
          }
          hide() {
            this._isShown && (j.trigger(this._element, "hide.bs.offcanvas").defaultPrevented || (this._focustrap.deactivate(), this._element.blur(), this._isShown = false, this._element.classList.remove($i), this._backdrop.hide(), this._queueCallback(() => {
              this._element.setAttribute("aria-hidden", true), this._element.removeAttribute("aria-modal"), this._element.removeAttribute("role"), this._element.style.visibility = "hidden", this._config.scroll || new fi().reset(), j.trigger(this._element, qi);
            }, this._element, true)));
          }
          dispose() {
            this._backdrop.dispose(), this._focustrap.deactivate(), super.dispose();
          }
          _getConfig(t2) {
            return t2 = { ...Ri, ...U.getDataAttributes(this._element), ..."object" == typeof t2 ? t2 : {} }, a(Bi, t2, Wi), t2;
          }
          _initializeBackDrop() {
            return new bi({ className: "offcanvas-backdrop", isVisible: this._config.backdrop, isAnimated: true, rootElement: this._element.parentNode, clickCallback: () => this.hide() });
          }
          _initializeFocusTrap() {
            return new Ai({ trapElement: this._element });
          }
          _addEventListeners() {
            j.on(this._element, "keydown.dismiss.bs.offcanvas", (t2) => {
              this._config.keyboard && "Escape" === t2.key && this.hide();
            });
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = Fi.getOrCreateInstance(this, t2);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2] || t2.startsWith("_") || "constructor" === t2)
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2](this);
              }
            });
          }
        }
        j.on(document, "click.bs.offcanvas.data-api", '[data-bs-toggle="offcanvas"]', function(t2) {
          const e2 = n(this);
          if (["A", "AREA"].includes(this.tagName) && t2.preventDefault(), c(this))
            return;
          j.one(e2, qi, () => {
            l(this) && this.focus();
          });
          const i2 = V.findOne(zi);
          i2 && i2 !== e2 && Fi.getInstance(i2).hide(), Fi.getOrCreateInstance(e2).toggle(this);
        }), j.on(window, "load.bs.offcanvas.data-api", () => V.find(zi).forEach((t2) => Fi.getOrCreateInstance(t2).show())), R(Fi), g(Fi);
        const Ui = /* @__PURE__ */ new Set(["background", "cite", "href", "itemtype", "longdesc", "poster", "src", "xlink:href"]), Vi = /^(?:(?:https?|mailto|ftp|tel|file|sms):|[^#&/:?]*(?:[#/?]|$))/i, Ki = /^data:(?:image\/(?:bmp|gif|jpeg|jpg|png|tiff|webp)|video\/(?:mpeg|mp4|ogg|webm)|audio\/(?:mp3|oga|ogg|opus));base64,[\d+/a-z]+=*$/i, Xi = (t2, e2) => {
          const i2 = t2.nodeName.toLowerCase();
          if (e2.includes(i2))
            return !Ui.has(i2) || Boolean(Vi.test(t2.nodeValue) || Ki.test(t2.nodeValue));
          const n2 = e2.filter((t3) => t3 instanceof RegExp);
          for (let t3 = 0, e3 = n2.length; t3 < e3; t3++)
            if (n2[t3].test(i2))
              return true;
          return false;
        };
        function Yi(t2, e2, i2) {
          if (!t2.length)
            return t2;
          if (i2 && "function" == typeof i2)
            return i2(t2);
          const n2 = new window.DOMParser().parseFromString(t2, "text/html"), s2 = [].concat(...n2.body.querySelectorAll("*"));
          for (let t3 = 0, i3 = s2.length; t3 < i3; t3++) {
            const i4 = s2[t3], n3 = i4.nodeName.toLowerCase();
            if (!Object.keys(e2).includes(n3)) {
              i4.remove();
              continue;
            }
            const o2 = [].concat(...i4.attributes), r2 = [].concat(e2["*"] || [], e2[n3] || []);
            o2.forEach((t4) => {
              Xi(t4, r2) || i4.removeAttribute(t4.nodeName);
            });
          }
          return n2.body.innerHTML;
        }
        const Qi = "tooltip", Gi = /* @__PURE__ */ new Set(["sanitize", "allowList", "sanitizeFn"]), Zi = { animation: "boolean", template: "string", title: "(string|element|function)", trigger: "string", delay: "(number|object)", html: "boolean", selector: "(string|boolean)", placement: "(string|function)", offset: "(array|string|function)", container: "(string|element|boolean)", fallbackPlacements: "array", boundary: "(string|element)", customClass: "(string|function)", sanitize: "boolean", sanitizeFn: "(null|function)", allowList: "object", popperConfig: "(null|object|function)" }, Ji = { AUTO: "auto", TOP: "top", RIGHT: m() ? "left" : "right", BOTTOM: "bottom", LEFT: m() ? "right" : "left" }, tn = { animation: true, template: '<div class="tooltip" role="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>', trigger: "hover focus", title: "", delay: 0, html: false, selector: false, placement: "top", offset: [0, 0], container: false, fallbackPlacements: ["top", "right", "bottom", "left"], boundary: "clippingParents", customClass: "", sanitize: true, sanitizeFn: null, allowList: { "*": ["class", "dir", "id", "lang", "role", /^aria-[\w-]*$/i], a: ["target", "href", "title", "rel"], area: [], b: [], br: [], col: [], code: [], div: [], em: [], hr: [], h1: [], h2: [], h3: [], h4: [], h5: [], h6: [], i: [], img: ["src", "srcset", "alt", "title", "width", "height"], li: [], ol: [], p: [], pre: [], s: [], small: [], span: [], sub: [], sup: [], strong: [], u: [], ul: [] }, popperConfig: null }, en = { HIDE: "hide.bs.tooltip", HIDDEN: "hidden.bs.tooltip", SHOW: "show.bs.tooltip", SHOWN: "shown.bs.tooltip", INSERTED: "inserted.bs.tooltip", CLICK: "click.bs.tooltip", FOCUSIN: "focusin.bs.tooltip", FOCUSOUT: "focusout.bs.tooltip", MOUSEENTER: "mouseenter.bs.tooltip", MOUSELEAVE: "mouseleave.bs.tooltip" }, nn = "fade", sn = "show", on = "show", rn = "out", an = ".tooltip-inner", ln = ".modal", cn = "hide.bs.modal", hn = "hover", dn = "focus";
        class un extends B {
          constructor(t2, e2) {
            if (void 0 === Fe)
              throw new TypeError("Bootstrap's tooltips require Popper (https://popper.js.org)");
            super(t2), this._isEnabled = true, this._timeout = 0, this._hoverState = "", this._activeTrigger = {}, this._popper = null, this._config = this._getConfig(e2), this.tip = null, this._setListeners();
          }
          static get Default() {
            return tn;
          }
          static get NAME() {
            return Qi;
          }
          static get Event() {
            return en;
          }
          static get DefaultType() {
            return Zi;
          }
          enable() {
            this._isEnabled = true;
          }
          disable() {
            this._isEnabled = false;
          }
          toggleEnabled() {
            this._isEnabled = !this._isEnabled;
          }
          toggle(t2) {
            if (this._isEnabled)
              if (t2) {
                const e2 = this._initializeOnDelegatedTarget(t2);
                e2._activeTrigger.click = !e2._activeTrigger.click, e2._isWithActiveTrigger() ? e2._enter(null, e2) : e2._leave(null, e2);
              } else {
                if (this.getTipElement().classList.contains(sn))
                  return void this._leave(null, this);
                this._enter(null, this);
              }
          }
          dispose() {
            clearTimeout(this._timeout), j.off(this._element.closest(ln), cn, this._hideModalHandler), this.tip && this.tip.remove(), this._disposePopper(), super.dispose();
          }
          show() {
            if ("none" === this._element.style.display)
              throw new Error("Please use show on visible elements");
            if (!this.isWithContent() || !this._isEnabled)
              return;
            const t2 = j.trigger(this._element, this.constructor.Event.SHOW), e2 = h(this._element), i2 = null === e2 ? this._element.ownerDocument.documentElement.contains(this._element) : e2.contains(this._element);
            if (t2.defaultPrevented || !i2)
              return;
            "tooltip" === this.constructor.NAME && this.tip && this.getTitle() !== this.tip.querySelector(an).innerHTML && (this._disposePopper(), this.tip.remove(), this.tip = null);
            const n2 = this.getTipElement(), s2 = ((t3) => {
              do {
                t3 += Math.floor(1e6 * Math.random());
              } while (document.getElementById(t3));
              return t3;
            })(this.constructor.NAME);
            n2.setAttribute("id", s2), this._element.setAttribute("aria-describedby", s2), this._config.animation && n2.classList.add(nn);
            const o2 = "function" == typeof this._config.placement ? this._config.placement.call(this, n2, this._element) : this._config.placement, r2 = this._getAttachment(o2);
            this._addAttachmentClass(r2);
            const { container: a2 } = this._config;
            H.set(n2, this.constructor.DATA_KEY, this), this._element.ownerDocument.documentElement.contains(this.tip) || (a2.append(n2), j.trigger(this._element, this.constructor.Event.INSERTED)), this._popper ? this._popper.update() : this._popper = qe(this._element, n2, this._getPopperConfig(r2)), n2.classList.add(sn);
            const l2 = this._resolvePossibleFunction(this._config.customClass);
            l2 && n2.classList.add(...l2.split(" ")), "ontouchstart" in document.documentElement && [].concat(...document.body.children).forEach((t3) => {
              j.on(t3, "mouseover", d);
            });
            const c2 = this.tip.classList.contains(nn);
            this._queueCallback(() => {
              const t3 = this._hoverState;
              this._hoverState = null, j.trigger(this._element, this.constructor.Event.SHOWN), t3 === rn && this._leave(null, this);
            }, this.tip, c2);
          }
          hide() {
            if (!this._popper)
              return;
            const t2 = this.getTipElement();
            if (j.trigger(this._element, this.constructor.Event.HIDE).defaultPrevented)
              return;
            t2.classList.remove(sn), "ontouchstart" in document.documentElement && [].concat(...document.body.children).forEach((t3) => j.off(t3, "mouseover", d)), this._activeTrigger.click = false, this._activeTrigger.focus = false, this._activeTrigger.hover = false;
            const e2 = this.tip.classList.contains(nn);
            this._queueCallback(() => {
              this._isWithActiveTrigger() || (this._hoverState !== on && t2.remove(), this._cleanTipClass(), this._element.removeAttribute("aria-describedby"), j.trigger(this._element, this.constructor.Event.HIDDEN), this._disposePopper());
            }, this.tip, e2), this._hoverState = "";
          }
          update() {
            null !== this._popper && this._popper.update();
          }
          isWithContent() {
            return Boolean(this.getTitle());
          }
          getTipElement() {
            if (this.tip)
              return this.tip;
            const t2 = document.createElement("div");
            t2.innerHTML = this._config.template;
            const e2 = t2.children[0];
            return this.setContent(e2), e2.classList.remove(nn, sn), this.tip = e2, this.tip;
          }
          setContent(t2) {
            this._sanitizeAndSetContent(t2, this.getTitle(), an);
          }
          _sanitizeAndSetContent(t2, e2, i2) {
            const n2 = V.findOne(i2, t2);
            e2 || !n2 ? this.setElementContent(n2, e2) : n2.remove();
          }
          setElementContent(t2, e2) {
            if (null !== t2)
              return o(e2) ? (e2 = r(e2), void (this._config.html ? e2.parentNode !== t2 && (t2.innerHTML = "", t2.append(e2)) : t2.textContent = e2.textContent)) : void (this._config.html ? (this._config.sanitize && (e2 = Yi(e2, this._config.allowList, this._config.sanitizeFn)), t2.innerHTML = e2) : t2.textContent = e2);
          }
          getTitle() {
            const t2 = this._element.getAttribute("data-bs-original-title") || this._config.title;
            return this._resolvePossibleFunction(t2);
          }
          updateAttachment(t2) {
            return "right" === t2 ? "end" : "left" === t2 ? "start" : t2;
          }
          _initializeOnDelegatedTarget(t2, e2) {
            return e2 || this.constructor.getOrCreateInstance(t2.delegateTarget, this._getDelegateConfig());
          }
          _getOffset() {
            const { offset: t2 } = this._config;
            return "string" == typeof t2 ? t2.split(",").map((t3) => Number.parseInt(t3, 10)) : "function" == typeof t2 ? (e2) => t2(e2, this._element) : t2;
          }
          _resolvePossibleFunction(t2) {
            return "function" == typeof t2 ? t2.call(this._element) : t2;
          }
          _getPopperConfig(t2) {
            const e2 = { placement: t2, modifiers: [{ name: "flip", options: { fallbackPlacements: this._config.fallbackPlacements } }, { name: "offset", options: { offset: this._getOffset() } }, { name: "preventOverflow", options: { boundary: this._config.boundary } }, { name: "arrow", options: { element: `.${this.constructor.NAME}-arrow` } }, { name: "onChange", enabled: true, phase: "afterWrite", fn: (t3) => this._handlePopperPlacementChange(t3) }], onFirstUpdate: (t3) => {
              t3.options.placement !== t3.placement && this._handlePopperPlacementChange(t3);
            } };
            return { ...e2, ..."function" == typeof this._config.popperConfig ? this._config.popperConfig(e2) : this._config.popperConfig };
          }
          _addAttachmentClass(t2) {
            this.getTipElement().classList.add(`${this._getBasicClassPrefix()}-${this.updateAttachment(t2)}`);
          }
          _getAttachment(t2) {
            return Ji[t2.toUpperCase()];
          }
          _setListeners() {
            this._config.trigger.split(" ").forEach((t2) => {
              if ("click" === t2)
                j.on(this._element, this.constructor.Event.CLICK, this._config.selector, (t3) => this.toggle(t3));
              else if ("manual" !== t2) {
                const e2 = t2 === hn ? this.constructor.Event.MOUSEENTER : this.constructor.Event.FOCUSIN, i2 = t2 === hn ? this.constructor.Event.MOUSELEAVE : this.constructor.Event.FOCUSOUT;
                j.on(this._element, e2, this._config.selector, (t3) => this._enter(t3)), j.on(this._element, i2, this._config.selector, (t3) => this._leave(t3));
              }
            }), this._hideModalHandler = () => {
              this._element && this.hide();
            }, j.on(this._element.closest(ln), cn, this._hideModalHandler), this._config.selector ? this._config = { ...this._config, trigger: "manual", selector: "" } : this._fixTitle();
          }
          _fixTitle() {
            const t2 = this._element.getAttribute("title"), e2 = typeof this._element.getAttribute("data-bs-original-title");
            (t2 || "string" !== e2) && (this._element.setAttribute("data-bs-original-title", t2 || ""), !t2 || this._element.getAttribute("aria-label") || this._element.textContent || this._element.setAttribute("aria-label", t2), this._element.setAttribute("title", ""));
          }
          _enter(t2, e2) {
            e2 = this._initializeOnDelegatedTarget(t2, e2), t2 && (e2._activeTrigger["focusin" === t2.type ? dn : hn] = true), e2.getTipElement().classList.contains(sn) || e2._hoverState === on ? e2._hoverState = on : (clearTimeout(e2._timeout), e2._hoverState = on, e2._config.delay && e2._config.delay.show ? e2._timeout = setTimeout(() => {
              e2._hoverState === on && e2.show();
            }, e2._config.delay.show) : e2.show());
          }
          _leave(t2, e2) {
            e2 = this._initializeOnDelegatedTarget(t2, e2), t2 && (e2._activeTrigger["focusout" === t2.type ? dn : hn] = e2._element.contains(t2.relatedTarget)), e2._isWithActiveTrigger() || (clearTimeout(e2._timeout), e2._hoverState = rn, e2._config.delay && e2._config.delay.hide ? e2._timeout = setTimeout(() => {
              e2._hoverState === rn && e2.hide();
            }, e2._config.delay.hide) : e2.hide());
          }
          _isWithActiveTrigger() {
            for (const t2 in this._activeTrigger)
              if (this._activeTrigger[t2])
                return true;
            return false;
          }
          _getConfig(t2) {
            const e2 = U.getDataAttributes(this._element);
            return Object.keys(e2).forEach((t3) => {
              Gi.has(t3) && delete e2[t3];
            }), (t2 = { ...this.constructor.Default, ...e2, ..."object" == typeof t2 && t2 ? t2 : {} }).container = false === t2.container ? document.body : r(t2.container), "number" == typeof t2.delay && (t2.delay = { show: t2.delay, hide: t2.delay }), "number" == typeof t2.title && (t2.title = t2.title.toString()), "number" == typeof t2.content && (t2.content = t2.content.toString()), a(Qi, t2, this.constructor.DefaultType), t2.sanitize && (t2.template = Yi(t2.template, t2.allowList, t2.sanitizeFn)), t2;
          }
          _getDelegateConfig() {
            const t2 = {};
            for (const e2 in this._config)
              this.constructor.Default[e2] !== this._config[e2] && (t2[e2] = this._config[e2]);
            return t2;
          }
          _cleanTipClass() {
            const t2 = this.getTipElement(), e2 = new RegExp(`(^|\\s)${this._getBasicClassPrefix()}\\S+`, "g"), i2 = t2.getAttribute("class").match(e2);
            null !== i2 && i2.length > 0 && i2.map((t3) => t3.trim()).forEach((e3) => t2.classList.remove(e3));
          }
          _getBasicClassPrefix() {
            return "bs-tooltip";
          }
          _handlePopperPlacementChange(t2) {
            const { state: e2 } = t2;
            e2 && (this.tip = e2.elements.popper, this._cleanTipClass(), this._addAttachmentClass(this._getAttachment(e2.placement)));
          }
          _disposePopper() {
            this._popper && (this._popper.destroy(), this._popper = null);
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = un.getOrCreateInstance(this, t2);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2]();
              }
            });
          }
        }
        g(un);
        const fn2 = { ...un.Default, placement: "right", offset: [0, 8], trigger: "click", content: "", template: '<div class="popover" role="tooltip"><div class="popover-arrow"></div><h3 class="popover-header"></h3><div class="popover-body"></div></div>' }, pn = { ...un.DefaultType, content: "(string|element|function)" }, mn = { HIDE: "hide.bs.popover", HIDDEN: "hidden.bs.popover", SHOW: "show.bs.popover", SHOWN: "shown.bs.popover", INSERTED: "inserted.bs.popover", CLICK: "click.bs.popover", FOCUSIN: "focusin.bs.popover", FOCUSOUT: "focusout.bs.popover", MOUSEENTER: "mouseenter.bs.popover", MOUSELEAVE: "mouseleave.bs.popover" };
        class gn extends un {
          static get Default() {
            return fn2;
          }
          static get NAME() {
            return "popover";
          }
          static get Event() {
            return mn;
          }
          static get DefaultType() {
            return pn;
          }
          isWithContent() {
            return this.getTitle() || this._getContent();
          }
          setContent(t2) {
            this._sanitizeAndSetContent(t2, this.getTitle(), ".popover-header"), this._sanitizeAndSetContent(t2, this._getContent(), ".popover-body");
          }
          _getContent() {
            return this._resolvePossibleFunction(this._config.content);
          }
          _getBasicClassPrefix() {
            return "bs-popover";
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = gn.getOrCreateInstance(this, t2);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2]();
              }
            });
          }
        }
        g(gn);
        const _n = "scrollspy", bn = { offset: 10, method: "auto", target: "" }, vn = { offset: "number", method: "string", target: "(string|element)" }, yn = "active", wn = ".nav-link, .list-group-item, .dropdown-item", En = "position";
        class An extends B {
          constructor(t2, e2) {
            super(t2), this._scrollElement = "BODY" === this._element.tagName ? window : this._element, this._config = this._getConfig(e2), this._offsets = [], this._targets = [], this._activeTarget = null, this._scrollHeight = 0, j.on(this._scrollElement, "scroll.bs.scrollspy", () => this._process()), this.refresh(), this._process();
          }
          static get Default() {
            return bn;
          }
          static get NAME() {
            return _n;
          }
          refresh() {
            const t2 = this._scrollElement === this._scrollElement.window ? "offset" : En, e2 = "auto" === this._config.method ? t2 : this._config.method, n2 = e2 === En ? this._getScrollTop() : 0;
            this._offsets = [], this._targets = [], this._scrollHeight = this._getScrollHeight(), V.find(wn, this._config.target).map((t3) => {
              const s2 = i(t3), o2 = s2 ? V.findOne(s2) : null;
              if (o2) {
                const t4 = o2.getBoundingClientRect();
                if (t4.width || t4.height)
                  return [U[e2](o2).top + n2, s2];
              }
              return null;
            }).filter((t3) => t3).sort((t3, e3) => t3[0] - e3[0]).forEach((t3) => {
              this._offsets.push(t3[0]), this._targets.push(t3[1]);
            });
          }
          dispose() {
            j.off(this._scrollElement, ".bs.scrollspy"), super.dispose();
          }
          _getConfig(t2) {
            return (t2 = { ...bn, ...U.getDataAttributes(this._element), ..."object" == typeof t2 && t2 ? t2 : {} }).target = r(t2.target) || document.documentElement, a(_n, t2, vn), t2;
          }
          _getScrollTop() {
            return this._scrollElement === window ? this._scrollElement.pageYOffset : this._scrollElement.scrollTop;
          }
          _getScrollHeight() {
            return this._scrollElement.scrollHeight || Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
          }
          _getOffsetHeight() {
            return this._scrollElement === window ? window.innerHeight : this._scrollElement.getBoundingClientRect().height;
          }
          _process() {
            const t2 = this._getScrollTop() + this._config.offset, e2 = this._getScrollHeight(), i2 = this._config.offset + e2 - this._getOffsetHeight();
            if (this._scrollHeight !== e2 && this.refresh(), t2 >= i2) {
              const t3 = this._targets[this._targets.length - 1];
              this._activeTarget !== t3 && this._activate(t3);
            } else {
              if (this._activeTarget && t2 < this._offsets[0] && this._offsets[0] > 0)
                return this._activeTarget = null, void this._clear();
              for (let e3 = this._offsets.length; e3--; )
                this._activeTarget !== this._targets[e3] && t2 >= this._offsets[e3] && (void 0 === this._offsets[e3 + 1] || t2 < this._offsets[e3 + 1]) && this._activate(this._targets[e3]);
            }
          }
          _activate(t2) {
            this._activeTarget = t2, this._clear();
            const e2 = wn.split(",").map((e3) => `${e3}[data-bs-target="${t2}"],${e3}[href="${t2}"]`), i2 = V.findOne(e2.join(","), this._config.target);
            i2.classList.add(yn), i2.classList.contains("dropdown-item") ? V.findOne(".dropdown-toggle", i2.closest(".dropdown")).classList.add(yn) : V.parents(i2, ".nav, .list-group").forEach((t3) => {
              V.prev(t3, ".nav-link, .list-group-item").forEach((t4) => t4.classList.add(yn)), V.prev(t3, ".nav-item").forEach((t4) => {
                V.children(t4, ".nav-link").forEach((t5) => t5.classList.add(yn));
              });
            }), j.trigger(this._scrollElement, "activate.bs.scrollspy", { relatedTarget: t2 });
          }
          _clear() {
            V.find(wn, this._config.target).filter((t2) => t2.classList.contains(yn)).forEach((t2) => t2.classList.remove(yn));
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = An.getOrCreateInstance(this, t2);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2]();
              }
            });
          }
        }
        j.on(window, "load.bs.scrollspy.data-api", () => {
          V.find('[data-bs-spy="scroll"]').forEach((t2) => new An(t2));
        }), g(An);
        const Tn = "active", On = "fade", Cn = "show", kn = ".active", Ln = ":scope > li > .active";
        class xn extends B {
          static get NAME() {
            return "tab";
          }
          show() {
            if (this._element.parentNode && this._element.parentNode.nodeType === Node.ELEMENT_NODE && this._element.classList.contains(Tn))
              return;
            let t2;
            const e2 = n(this._element), i2 = this._element.closest(".nav, .list-group");
            if (i2) {
              const e3 = "UL" === i2.nodeName || "OL" === i2.nodeName ? Ln : kn;
              t2 = V.find(e3, i2), t2 = t2[t2.length - 1];
            }
            const s2 = t2 ? j.trigger(t2, "hide.bs.tab", { relatedTarget: this._element }) : null;
            if (j.trigger(this._element, "show.bs.tab", { relatedTarget: t2 }).defaultPrevented || null !== s2 && s2.defaultPrevented)
              return;
            this._activate(this._element, i2);
            const o2 = () => {
              j.trigger(t2, "hidden.bs.tab", { relatedTarget: this._element }), j.trigger(this._element, "shown.bs.tab", { relatedTarget: t2 });
            };
            e2 ? this._activate(e2, e2.parentNode, o2) : o2();
          }
          _activate(t2, e2, i2) {
            const n2 = (!e2 || "UL" !== e2.nodeName && "OL" !== e2.nodeName ? V.children(e2, kn) : V.find(Ln, e2))[0], s2 = i2 && n2 && n2.classList.contains(On), o2 = () => this._transitionComplete(t2, n2, i2);
            n2 && s2 ? (n2.classList.remove(Cn), this._queueCallback(o2, t2, true)) : o2();
          }
          _transitionComplete(t2, e2, i2) {
            if (e2) {
              e2.classList.remove(Tn);
              const t3 = V.findOne(":scope > .dropdown-menu .active", e2.parentNode);
              t3 && t3.classList.remove(Tn), "tab" === e2.getAttribute("role") && e2.setAttribute("aria-selected", false);
            }
            t2.classList.add(Tn), "tab" === t2.getAttribute("role") && t2.setAttribute("aria-selected", true), u(t2), t2.classList.contains(On) && t2.classList.add(Cn);
            let n2 = t2.parentNode;
            if (n2 && "LI" === n2.nodeName && (n2 = n2.parentNode), n2 && n2.classList.contains("dropdown-menu")) {
              const e3 = t2.closest(".dropdown");
              e3 && V.find(".dropdown-toggle", e3).forEach((t3) => t3.classList.add(Tn)), t2.setAttribute("aria-expanded", true);
            }
            i2 && i2();
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = xn.getOrCreateInstance(this);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2]();
              }
            });
          }
        }
        j.on(document, "click.bs.tab.data-api", '[data-bs-toggle="tab"], [data-bs-toggle="pill"], [data-bs-toggle="list"]', function(t2) {
          ["A", "AREA"].includes(this.tagName) && t2.preventDefault(), c(this) || xn.getOrCreateInstance(this).show();
        }), g(xn);
        const Dn = "toast", Sn = "hide", Nn = "show", In = "showing", Pn = { animation: "boolean", autohide: "boolean", delay: "number" }, jn = { animation: true, autohide: true, delay: 5e3 };
        class Mn extends B {
          constructor(t2, e2) {
            super(t2), this._config = this._getConfig(e2), this._timeout = null, this._hasMouseInteraction = false, this._hasKeyboardInteraction = false, this._setListeners();
          }
          static get DefaultType() {
            return Pn;
          }
          static get Default() {
            return jn;
          }
          static get NAME() {
            return Dn;
          }
          show() {
            j.trigger(this._element, "show.bs.toast").defaultPrevented || (this._clearTimeout(), this._config.animation && this._element.classList.add("fade"), this._element.classList.remove(Sn), u(this._element), this._element.classList.add(Nn), this._element.classList.add(In), this._queueCallback(() => {
              this._element.classList.remove(In), j.trigger(this._element, "shown.bs.toast"), this._maybeScheduleHide();
            }, this._element, this._config.animation));
          }
          hide() {
            this._element.classList.contains(Nn) && (j.trigger(this._element, "hide.bs.toast").defaultPrevented || (this._element.classList.add(In), this._queueCallback(() => {
              this._element.classList.add(Sn), this._element.classList.remove(In), this._element.classList.remove(Nn), j.trigger(this._element, "hidden.bs.toast");
            }, this._element, this._config.animation)));
          }
          dispose() {
            this._clearTimeout(), this._element.classList.contains(Nn) && this._element.classList.remove(Nn), super.dispose();
          }
          _getConfig(t2) {
            return t2 = { ...jn, ...U.getDataAttributes(this._element), ..."object" == typeof t2 && t2 ? t2 : {} }, a(Dn, t2, this.constructor.DefaultType), t2;
          }
          _maybeScheduleHide() {
            this._config.autohide && (this._hasMouseInteraction || this._hasKeyboardInteraction || (this._timeout = setTimeout(() => {
              this.hide();
            }, this._config.delay)));
          }
          _onInteraction(t2, e2) {
            switch (t2.type) {
              case "mouseover":
              case "mouseout":
                this._hasMouseInteraction = e2;
                break;
              case "focusin":
              case "focusout":
                this._hasKeyboardInteraction = e2;
            }
            if (e2)
              return void this._clearTimeout();
            const i2 = t2.relatedTarget;
            this._element === i2 || this._element.contains(i2) || this._maybeScheduleHide();
          }
          _setListeners() {
            j.on(this._element, "mouseover.bs.toast", (t2) => this._onInteraction(t2, true)), j.on(this._element, "mouseout.bs.toast", (t2) => this._onInteraction(t2, false)), j.on(this._element, "focusin.bs.toast", (t2) => this._onInteraction(t2, true)), j.on(this._element, "focusout.bs.toast", (t2) => this._onInteraction(t2, false));
          }
          _clearTimeout() {
            clearTimeout(this._timeout), this._timeout = null;
          }
          static jQueryInterface(t2) {
            return this.each(function() {
              const e2 = Mn.getOrCreateInstance(this, t2);
              if ("string" == typeof t2) {
                if (void 0 === e2[t2])
                  throw new TypeError(`No method named "${t2}"`);
                e2[t2](this);
              }
            });
          }
        }
        return R(Mn), g(Mn), { Alert: W, Button: z, Carousel: st, Collapse: pt, Dropdown: hi, Modal: Hi, Offcanvas: Fi, Popover: gn, ScrollSpy: An, Tab: xn, Toast: Mn, Tooltip: un };
      });
    }
  });

  // app/javascript/mobilekit/plugins/progressbar-js/progressbar.min.js
  var require_progressbar_min = __commonJS({
    "app/javascript/mobilekit/plugins/progressbar-js/progressbar.min.js"(exports, module) {
      !function(a) {
        if ("object" == typeof exports && "undefined" != typeof module)
          module.exports = a();
        else if ("function" == typeof define && define.amd)
          define([], a);
        else {
          var b;
          b = "undefined" != typeof window ? window : "undefined" != typeof global ? global : "undefined" != typeof self ? self : this, b.ProgressBar = a();
        }
      }(function() {
        var a;
        return function() {
          function a2(b, c, d) {
            function e(g2, h) {
              if (!c[g2]) {
                if (!b[g2]) {
                  var i = "function" == typeof __require && __require;
                  if (!h && i)
                    return i(g2, true);
                  if (f)
                    return f(g2, true);
                  var j = new Error("Cannot find module '" + g2 + "'");
                  throw j.code = "MODULE_NOT_FOUND", j;
                }
                var k = c[g2] = { exports: {} };
                b[g2][0].call(k.exports, function(a3) {
                  return e(b[g2][1][a3] || a3);
                }, k, k.exports, a2, b, c, d);
              }
              return c[g2].exports;
            }
            for (var f = "function" == typeof __require && __require, g = 0; g < d.length; g++)
              e(d[g]);
            return e;
          }
          return a2;
        }()({ 1: [function(b, c, d) {
          !function(b2, e) {
            "object" == typeof d && "object" == typeof c ? c.exports = e() : "function" == typeof a && a.amd ? a("shifty", [], e) : "object" == typeof d ? d.shifty = e() : b2.shifty = e();
          }(window, function() {
            return function(a2) {
              function b2(d2) {
                if (c2[d2])
                  return c2[d2].exports;
                var e = c2[d2] = { i: d2, l: false, exports: {} };
                return a2[d2].call(e.exports, e, e.exports, b2), e.l = true, e.exports;
              }
              var c2 = {};
              return b2.m = a2, b2.c = c2, b2.d = function(a3, c3, d2) {
                b2.o(a3, c3) || Object.defineProperty(a3, c3, { enumerable: true, get: d2 });
              }, b2.r = function(a3) {
                "undefined" != typeof Symbol && Symbol.toStringTag && Object.defineProperty(a3, Symbol.toStringTag, { value: "Module" }), Object.defineProperty(a3, "__esModule", { value: true });
              }, b2.t = function(a3, c3) {
                if (1 & c3 && (a3 = b2(a3)), 8 & c3)
                  return a3;
                if (4 & c3 && "object" == typeof a3 && a3 && a3.__esModule)
                  return a3;
                var d2 = /* @__PURE__ */ Object.create(null);
                if (b2.r(d2), Object.defineProperty(d2, "default", { enumerable: true, value: a3 }), 2 & c3 && "string" != typeof a3)
                  for (var e in a3)
                    b2.d(d2, e, function(b3) {
                      return a3[b3];
                    }.bind(null, e));
                return d2;
              }, b2.n = function(a3) {
                var c3 = a3 && a3.__esModule ? function() {
                  return a3.default;
                } : function() {
                  return a3;
                };
                return b2.d(c3, "a", c3), c3;
              }, b2.o = function(a3, b3) {
                return Object.prototype.hasOwnProperty.call(a3, b3);
              }, b2.p = "", b2(b2.s = 3);
            }([function(a2, b2, c2) {
              "use strict";
              (function(a3) {
                function d2(a4, b3) {
                  for (var c3 = 0; c3 < b3.length; c3++) {
                    var d3 = b3[c3];
                    d3.enumerable = d3.enumerable || false, d3.configurable = true, "value" in d3 && (d3.writable = true), Object.defineProperty(a4, d3.key, d3);
                  }
                }
                function e(a4) {
                  return (e = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function(a5) {
                    return typeof a5;
                  } : function(a5) {
                    return a5 && "function" == typeof Symbol && a5.constructor === Symbol && a5 !== Symbol.prototype ? "symbol" : typeof a5;
                  })(a4);
                }
                function f(a4, b3) {
                  var c3 = Object.keys(a4);
                  if (Object.getOwnPropertySymbols) {
                    var d3 = Object.getOwnPropertySymbols(a4);
                    b3 && (d3 = d3.filter(function(b4) {
                      return Object.getOwnPropertyDescriptor(a4, b4).enumerable;
                    })), c3.push.apply(c3, d3);
                  }
                  return c3;
                }
                function g(a4) {
                  for (var b3 = 1; b3 < arguments.length; b3++) {
                    var c3 = null != arguments[b3] ? arguments[b3] : {};
                    b3 % 2 ? f(Object(c3), true).forEach(function(b4) {
                      h(a4, b4, c3[b4]);
                    }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(a4, Object.getOwnPropertyDescriptors(c3)) : f(Object(c3)).forEach(function(b4) {
                      Object.defineProperty(a4, b4, Object.getOwnPropertyDescriptor(c3, b4));
                    });
                  }
                  return a4;
                }
                function h(a4, b3, c3) {
                  return b3 in a4 ? Object.defineProperty(a4, b3, { value: c3, enumerable: true, configurable: true, writable: true }) : a4[b3] = c3, a4;
                }
                function i() {
                  var a4 = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : {}, b3 = new v(), c3 = b3.tween(a4);
                  return c3.tweenable = b3, c3;
                }
                c2.d(b2, "e", function() {
                  return q;
                }), c2.d(b2, "c", function() {
                  return s;
                }), c2.d(b2, "b", function() {
                  return t;
                }), c2.d(b2, "a", function() {
                  return v;
                }), c2.d(b2, "d", function() {
                  return i;
                });
                var j = c2(1), k = "undefined" != typeof window ? window : a3, l = k.requestAnimationFrame || k.webkitRequestAnimationFrame || k.oRequestAnimationFrame || k.msRequestAnimationFrame || k.mozCancelRequestAnimationFrame && k.mozRequestAnimationFrame || setTimeout, m = function() {
                }, n = null, o = null, p = g({}, j), q = function(a4, b3, c3, d3, e2, f2, g2) {
                  var h2 = a4 < f2 ? 0 : (a4 - f2) / e2;
                  for (var i2 in b3) {
                    var j2 = g2[i2], k2 = j2.call ? j2 : p[j2], l2 = c3[i2];
                    b3[i2] = l2 + (d3[i2] - l2) * k2(h2);
                  }
                  return b3;
                }, r = function(a4, b3) {
                  var c3 = a4._attachment, d3 = a4._currentState, e2 = a4._delay, f2 = a4._easing, g2 = a4._originalState, h2 = a4._duration, i2 = a4._step, j2 = a4._targetState, k2 = a4._timestamp, l2 = k2 + e2 + h2, m2 = b3 > l2 ? l2 : b3, n2 = h2 - (l2 - m2);
                  m2 >= l2 ? (i2(j2, c3, n2), a4.stop(true)) : (a4._applyFilter("beforeTween"), m2 < k2 + e2 ? (m2 = 1, h2 = 1, k2 = 1) : k2 += e2, q(m2, d3, g2, j2, h2, k2, f2), a4._applyFilter("afterTween"), i2(d3, c3, n2));
                }, s = function() {
                  for (var a4 = v.now(), b3 = n; b3; ) {
                    var c3 = b3._next;
                    r(b3, a4), b3 = c3;
                  }
                }, t = function(a4) {
                  var b3 = arguments.length > 1 && void 0 !== arguments[1] ? arguments[1] : "linear", c3 = {}, d3 = e(b3);
                  if ("string" === d3 || "function" === d3)
                    for (var f2 in a4)
                      c3[f2] = b3;
                  else
                    for (var g2 in a4)
                      c3[g2] = b3[g2] || "linear";
                  return c3;
                }, u = function(a4) {
                  if (a4 === n)
                    (n = a4._next) ? n._previous = null : o = null;
                  else if (a4 === o)
                    (o = a4._previous) ? o._next = null : n = null;
                  else {
                    var b3 = a4._previous, c3 = a4._next;
                    b3._next = c3, c3._previous = b3;
                  }
                  a4._previous = a4._next = null;
                }, v = function() {
                  function a4() {
                    var b4 = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : {}, c4 = arguments.length > 1 && void 0 !== arguments[1] ? arguments[1] : void 0;
                    !function(a5, b5) {
                      if (!(a5 instanceof b5))
                        throw new TypeError("Cannot call a class as a function");
                    }(this, a4), this._currentState = b4, this._configured = false, this._filters = [], this._timestamp = null, this._next = null, this._previous = null, c4 && this.setConfig(c4);
                  }
                  var b3, c3, e2;
                  return b3 = a4, (c3 = [{ key: "_applyFilter", value: function(a5) {
                    var b4 = true, c4 = false, d3 = void 0;
                    try {
                      for (var e3, f2 = this._filters[Symbol.iterator](); !(b4 = (e3 = f2.next()).done); b4 = true) {
                        var g2 = e3.value[a5];
                        g2 && g2(this);
                      }
                    } catch (a6) {
                      c4 = true, d3 = a6;
                    } finally {
                      try {
                        b4 || null == f2.return || f2.return();
                      } finally {
                        if (c4)
                          throw d3;
                      }
                    }
                  } }, { key: "tween", value: function() {
                    var b4 = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : void 0, c4 = this._attachment, d3 = this._configured;
                    return !b4 && d3 || this.setConfig(b4), this._pausedAtTime = null, this._timestamp = a4.now(), this._start(this.get(), c4), this.resume();
                  } }, { key: "setConfig", value: function() {
                    var b4 = this, c4 = arguments.length > 0 && void 0 !== arguments[0] ? arguments[0] : {}, d3 = c4.attachment, e3 = c4.delay, f2 = void 0 === e3 ? 0 : e3, h2 = c4.duration, i2 = void 0 === h2 ? 500 : h2, j2 = c4.easing, k2 = c4.from, l2 = c4.promise, n2 = void 0 === l2 ? Promise : l2, o2 = c4.start, p2 = void 0 === o2 ? m : o2, q2 = c4.step, r2 = void 0 === q2 ? m : q2, s2 = c4.to;
                    this._configured = true, this._attachment = d3, this._isPlaying = false, this._pausedAtTime = null, this._scheduleId = null, this._delay = f2, this._start = p2, this._step = r2, this._duration = i2, this._currentState = g({}, k2 || this.get()), this._originalState = this.get(), this._targetState = g({}, s2 || this.get());
                    var u2 = this._currentState;
                    this._targetState = g({}, u2, {}, this._targetState), this._easing = t(u2, j2);
                    var v2 = a4.filters;
                    for (var w in this._filters.length = 0, v2)
                      v2[w].doesApply(this) && this._filters.push(v2[w]);
                    return this._applyFilter("tweenCreated"), this._promise = new n2(function(a5, c5) {
                      b4._resolve = a5, b4._reject = c5;
                    }), this._promise.catch(m), this;
                  } }, { key: "get", value: function() {
                    return g({}, this._currentState);
                  } }, { key: "set", value: function(a5) {
                    this._currentState = a5;
                  } }, { key: "pause", value: function() {
                    if (this._isPlaying)
                      return this._pausedAtTime = a4.now(), this._isPlaying = false, u(this), this;
                  } }, { key: "resume", value: function() {
                    if (null === this._timestamp)
                      return this.tween();
                    if (this._isPlaying)
                      return this._promise;
                    var b4 = a4.now();
                    return this._pausedAtTime && (this._timestamp += b4 - this._pausedAtTime, this._pausedAtTime = null), this._isPlaying = true, null === n ? (n = this, o = this, function a5() {
                      n && (l.call(k, a5, 1e3 / 60), s());
                    }()) : (this._previous = o, o._next = this, o = this), this._promise;
                  } }, { key: "seek", value: function(b4) {
                    b4 = Math.max(b4, 0);
                    var c4 = a4.now();
                    return this._timestamp + b4 === 0 ? this : (this._timestamp = c4 - b4, this._isPlaying || r(this, c4), this);
                  } }, { key: "stop", value: function() {
                    var a5 = arguments.length > 0 && void 0 !== arguments[0] && arguments[0], b4 = this._attachment, c4 = this._currentState, d3 = this._easing, e3 = this._originalState, f2 = this._targetState;
                    if (this._isPlaying)
                      return this._isPlaying = false, u(this), a5 ? (this._applyFilter("beforeTween"), q(1, c4, e3, f2, 1, 0, d3), this._applyFilter("afterTween"), this._applyFilter("afterTweenEnd"), this._resolve(c4, b4)) : this._reject(c4, b4), this;
                  } }, { key: "isPlaying", value: function() {
                    return this._isPlaying;
                  } }, { key: "setScheduleFunction", value: function(b4) {
                    a4.setScheduleFunction(b4);
                  } }, { key: "dispose", value: function() {
                    for (var a5 in this)
                      delete this[a5];
                  } }]) && d2(b3.prototype, c3), e2 && d2(b3, e2), a4;
                }();
                v.setScheduleFunction = function(a4) {
                  return l = a4;
                }, v.formulas = p, v.filters = {}, v.now = Date.now || function() {
                  return +new Date();
                };
              }).call(this, c2(2));
            }, function(a2, b2, c2) {
              "use strict";
              c2.r(b2), c2.d(b2, "linear", function() {
                return d2;
              }), c2.d(b2, "easeInQuad", function() {
                return e;
              }), c2.d(b2, "easeOutQuad", function() {
                return f;
              }), c2.d(b2, "easeInOutQuad", function() {
                return g;
              }), c2.d(b2, "easeInCubic", function() {
                return h;
              }), c2.d(b2, "easeOutCubic", function() {
                return i;
              }), c2.d(b2, "easeInOutCubic", function() {
                return j;
              }), c2.d(b2, "easeInQuart", function() {
                return k;
              }), c2.d(b2, "easeOutQuart", function() {
                return l;
              }), c2.d(b2, "easeInOutQuart", function() {
                return m;
              }), c2.d(b2, "easeInQuint", function() {
                return n;
              }), c2.d(b2, "easeOutQuint", function() {
                return o;
              }), c2.d(b2, "easeInOutQuint", function() {
                return p;
              }), c2.d(b2, "easeInSine", function() {
                return q;
              }), c2.d(b2, "easeOutSine", function() {
                return r;
              }), c2.d(b2, "easeInOutSine", function() {
                return s;
              }), c2.d(b2, "easeInExpo", function() {
                return t;
              }), c2.d(b2, "easeOutExpo", function() {
                return u;
              }), c2.d(b2, "easeInOutExpo", function() {
                return v;
              }), c2.d(b2, "easeInCirc", function() {
                return w;
              }), c2.d(b2, "easeOutCirc", function() {
                return x;
              }), c2.d(b2, "easeInOutCirc", function() {
                return y;
              }), c2.d(b2, "easeOutBounce", function() {
                return z;
              }), c2.d(b2, "easeInBack", function() {
                return A;
              }), c2.d(b2, "easeOutBack", function() {
                return B;
              }), c2.d(b2, "easeInOutBack", function() {
                return C;
              }), c2.d(b2, "elastic", function() {
                return D;
              }), c2.d(b2, "swingFromTo", function() {
                return E;
              }), c2.d(b2, "swingFrom", function() {
                return F;
              }), c2.d(b2, "swingTo", function() {
                return G;
              }), c2.d(b2, "bounce", function() {
                return H;
              }), c2.d(b2, "bouncePast", function() {
                return I;
              }), c2.d(b2, "easeFromTo", function() {
                return J;
              }), c2.d(b2, "easeFrom", function() {
                return K;
              }), c2.d(b2, "easeTo", function() {
                return L;
              });
              var d2 = function(a3) {
                return a3;
              }, e = function(a3) {
                return Math.pow(a3, 2);
              }, f = function(a3) {
                return -(Math.pow(a3 - 1, 2) - 1);
              }, g = function(a3) {
                return (a3 /= 0.5) < 1 ? 0.5 * Math.pow(a3, 2) : -0.5 * ((a3 -= 2) * a3 - 2);
              }, h = function(a3) {
                return Math.pow(a3, 3);
              }, i = function(a3) {
                return Math.pow(a3 - 1, 3) + 1;
              }, j = function(a3) {
                return (a3 /= 0.5) < 1 ? 0.5 * Math.pow(a3, 3) : 0.5 * (Math.pow(a3 - 2, 3) + 2);
              }, k = function(a3) {
                return Math.pow(a3, 4);
              }, l = function(a3) {
                return -(Math.pow(a3 - 1, 4) - 1);
              }, m = function(a3) {
                return (a3 /= 0.5) < 1 ? 0.5 * Math.pow(a3, 4) : -0.5 * ((a3 -= 2) * Math.pow(a3, 3) - 2);
              }, n = function(a3) {
                return Math.pow(a3, 5);
              }, o = function(a3) {
                return Math.pow(a3 - 1, 5) + 1;
              }, p = function(a3) {
                return (a3 /= 0.5) < 1 ? 0.5 * Math.pow(a3, 5) : 0.5 * (Math.pow(a3 - 2, 5) + 2);
              }, q = function(a3) {
                return 1 - Math.cos(a3 * (Math.PI / 2));
              }, r = function(a3) {
                return Math.sin(a3 * (Math.PI / 2));
              }, s = function(a3) {
                return -0.5 * (Math.cos(Math.PI * a3) - 1);
              }, t = function(a3) {
                return 0 === a3 ? 0 : Math.pow(2, 10 * (a3 - 1));
              }, u = function(a3) {
                return 1 === a3 ? 1 : 1 - Math.pow(2, -10 * a3);
              }, v = function(a3) {
                return 0 === a3 ? 0 : 1 === a3 ? 1 : (a3 /= 0.5) < 1 ? 0.5 * Math.pow(2, 10 * (a3 - 1)) : 0.5 * (2 - Math.pow(2, -10 * --a3));
              }, w = function(a3) {
                return -(Math.sqrt(1 - a3 * a3) - 1);
              }, x = function(a3) {
                return Math.sqrt(1 - Math.pow(a3 - 1, 2));
              }, y = function(a3) {
                return (a3 /= 0.5) < 1 ? -0.5 * (Math.sqrt(1 - a3 * a3) - 1) : 0.5 * (Math.sqrt(1 - (a3 -= 2) * a3) + 1);
              }, z = function(a3) {
                return a3 < 1 / 2.75 ? 7.5625 * a3 * a3 : a3 < 2 / 2.75 ? 7.5625 * (a3 -= 1.5 / 2.75) * a3 + 0.75 : a3 < 2.5 / 2.75 ? 7.5625 * (a3 -= 2.25 / 2.75) * a3 + 0.9375 : 7.5625 * (a3 -= 2.625 / 2.75) * a3 + 0.984375;
              }, A = function(a3) {
                var b3 = 1.70158;
                return a3 * a3 * ((b3 + 1) * a3 - b3);
              }, B = function(a3) {
                var b3 = 1.70158;
                return (a3 -= 1) * a3 * ((b3 + 1) * a3 + b3) + 1;
              }, C = function(a3) {
                var b3 = 1.70158;
                return (a3 /= 0.5) < 1 ? a3 * a3 * ((1 + (b3 *= 1.525)) * a3 - b3) * 0.5 : 0.5 * ((a3 -= 2) * a3 * ((1 + (b3 *= 1.525)) * a3 + b3) + 2);
              }, D = function(a3) {
                return -1 * Math.pow(4, -8 * a3) * Math.sin((6 * a3 - 1) * (2 * Math.PI) / 2) + 1;
              }, E = function(a3) {
                var b3 = 1.70158;
                return (a3 /= 0.5) < 1 ? a3 * a3 * ((1 + (b3 *= 1.525)) * a3 - b3) * 0.5 : 0.5 * ((a3 -= 2) * a3 * ((1 + (b3 *= 1.525)) * a3 + b3) + 2);
              }, F = function(a3) {
                var b3 = 1.70158;
                return a3 * a3 * ((b3 + 1) * a3 - b3);
              }, G = function(a3) {
                var b3 = 1.70158;
                return (a3 -= 1) * a3 * ((b3 + 1) * a3 + b3) + 1;
              }, H = function(a3) {
                return a3 < 1 / 2.75 ? 7.5625 * a3 * a3 : a3 < 2 / 2.75 ? 7.5625 * (a3 -= 1.5 / 2.75) * a3 + 0.75 : a3 < 2.5 / 2.75 ? 7.5625 * (a3 -= 2.25 / 2.75) * a3 + 0.9375 : 7.5625 * (a3 -= 2.625 / 2.75) * a3 + 0.984375;
              }, I = function(a3) {
                return a3 < 1 / 2.75 ? 7.5625 * a3 * a3 : a3 < 2 / 2.75 ? 2 - (7.5625 * (a3 -= 1.5 / 2.75) * a3 + 0.75) : a3 < 2.5 / 2.75 ? 2 - (7.5625 * (a3 -= 2.25 / 2.75) * a3 + 0.9375) : 2 - (7.5625 * (a3 -= 2.625 / 2.75) * a3 + 0.984375);
              }, J = function(a3) {
                return (a3 /= 0.5) < 1 ? 0.5 * Math.pow(a3, 4) : -0.5 * ((a3 -= 2) * Math.pow(a3, 3) - 2);
              }, K = function(a3) {
                return Math.pow(a3, 4);
              }, L = function(a3) {
                return Math.pow(a3, 0.25);
              };
            }, function(a2, b2) {
              var c2;
              c2 = function() {
                return this;
              }();
              try {
                c2 = c2 || new Function("return this")();
              } catch (a3) {
                "object" == typeof window && (c2 = window);
              }
              a2.exports = c2;
            }, function(a2, b2, c2) {
              "use strict";
              function d2(a3) {
                return parseInt(a3, 16);
              }
              function e(a3) {
                var b3 = a3._currentState;
                [b3, a3._originalState, a3._targetState].forEach(B), a3._tokenData = E(b3);
              }
              function f(a3) {
                var b3 = a3._currentState, c3 = a3._originalState, d3 = a3._targetState, e2 = a3._easing, f2 = a3._tokenData;
                K(e2, f2), [b3, c3, d3].forEach(function(a4) {
                  return F(a4, f2);
                });
              }
              function g(a3) {
                var b3 = a3._currentState, c3 = a3._originalState, d3 = a3._targetState, e2 = a3._easing, f2 = a3._tokenData;
                [b3, c3, d3].forEach(function(a4) {
                  return J(a4, f2);
                }), L(e2, f2);
              }
              function h(a3, b3) {
                var c3 = Object.keys(a3);
                if (Object.getOwnPropertySymbols) {
                  var d3 = Object.getOwnPropertySymbols(a3);
                  b3 && (d3 = d3.filter(function(b4) {
                    return Object.getOwnPropertyDescriptor(a3, b4).enumerable;
                  })), c3.push.apply(c3, d3);
                }
                return c3;
              }
              function i(a3) {
                for (var b3 = 1; b3 < arguments.length; b3++) {
                  var c3 = null != arguments[b3] ? arguments[b3] : {};
                  b3 % 2 ? h(Object(c3), true).forEach(function(b4) {
                    j(a3, b4, c3[b4]);
                  }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(a3, Object.getOwnPropertyDescriptors(c3)) : h(Object(c3)).forEach(function(b4) {
                    Object.defineProperty(a3, b4, Object.getOwnPropertyDescriptor(c3, b4));
                  });
                }
                return a3;
              }
              function j(a3, b3, c3) {
                return b3 in a3 ? Object.defineProperty(a3, b3, { value: c3, enumerable: true, configurable: true, writable: true }) : a3[b3] = c3, a3;
              }
              function k(a3) {
                return function(a4) {
                  if (Array.isArray(a4)) {
                    for (var b3 = 0, c3 = new Array(a4.length); b3 < a4.length; b3++)
                      c3[b3] = a4[b3];
                    return c3;
                  }
                }(a3) || function(a4) {
                  if (Symbol.iterator in Object(a4) || "[object Arguments]" === Object.prototype.toString.call(a4))
                    return Array.from(a4);
                }(a3) || function() {
                  throw new TypeError("Invalid attempt to spread non-iterable instance");
                }();
              }
              function l(a3, b3) {
                for (var c3 = 0; c3 < b3.length; c3++) {
                  var d3 = b3[c3];
                  d3.enumerable = d3.enumerable || false, d3.configurable = true, "value" in d3 && (d3.writable = true), Object.defineProperty(a3, d3.key, d3);
                }
              }
              function m(a3, b3) {
                var c3 = b3.get(a3);
                if (!c3)
                  throw new TypeError("attempted to get private field on non-instance");
                return c3.get ? c3.get.call(a3) : c3.value;
              }
              function n(a3, b3, c3, d3, e2, f2) {
                var g2, h2, i2 = 0, j2 = 0, k2 = 0, l2 = 0, m2 = 0, n2 = 0, o2 = function(a4) {
                  return ((i2 * a4 + j2) * a4 + k2) * a4;
                }, p2 = function(a4) {
                  return (3 * i2 * a4 + 2 * j2) * a4 + k2;
                }, q2 = function(a4) {
                  return a4 >= 0 ? a4 : 0 - a4;
                };
                return i2 = 1 - (k2 = 3 * b3) - (j2 = 3 * (d3 - b3) - k2), l2 = 1 - (n2 = 3 * c3) - (m2 = 3 * (e2 - c3) - n2), g2 = a3, h2 = function(a4) {
                  return 1 / (200 * a4);
                }(f2), function(a4) {
                  return ((l2 * a4 + m2) * a4 + n2) * a4;
                }(function(a4, b4) {
                  var c4, d4, e3, f3, g3, h3;
                  for (e3 = a4, h3 = 0; h3 < 8; h3++) {
                    if (f3 = o2(e3) - a4, q2(f3) < b4)
                      return e3;
                    if (g3 = p2(e3), q2(g3) < 1e-6)
                      break;
                    e3 -= f3 / g3;
                  }
                  if ((e3 = a4) < (c4 = 0))
                    return c4;
                  if (e3 > (d4 = 1))
                    return d4;
                  for (; c4 < d4; ) {
                    if (f3 = o2(e3), q2(f3 - a4) < b4)
                      return e3;
                    a4 > f3 ? c4 = e3 : d4 = e3, e3 = 0.5 * (d4 - c4) + c4;
                  }
                  return e3;
                }(g2, h2));
              }
              c2.r(b2);
              var o = {};
              c2.r(o), c2.d(o, "doesApply", function() {
                return M;
              }), c2.d(o, "tweenCreated", function() {
                return e;
              }), c2.d(o, "beforeTween", function() {
                return f;
              }), c2.d(o, "afterTween", function() {
                return g;
              });
              var p, q, r = c2(0), s = /(\d|-|\.)/, t = /([^\-0-9.]+)/g, u = /[0-9.-]+/g, v = (p = u.source, q = /,\s*/.source, new RegExp("rgb\\(".concat(p).concat(q).concat(p).concat(q).concat(p, "\\)"), "g")), w = /^.*\(/, x = /#([0-9]|[a-f]){3,6}/gi, y = function(a3, b3) {
                return a3.map(function(a4, c3) {
                  return "_".concat(b3, "_").concat(c3);
                });
              }, z = function(a3) {
                return "rgb(".concat((b3 = a3, 3 === (b3 = b3.replace(/#/, "")).length && (b3 = (b3 = b3.split(""))[0] + b3[0] + b3[1] + b3[1] + b3[2] + b3[2]), [d2(b3.substr(0, 2)), d2(b3.substr(2, 2)), d2(b3.substr(4, 2))]).join(","), ")");
                var b3;
              }, A = function(a3, b3, c3) {
                var d3 = b3.match(a3), e2 = b3.replace(a3, "VAL");
                return d3 && d3.forEach(function(a4) {
                  return e2 = e2.replace("VAL", c3(a4));
                }), e2;
              }, B = function(a3) {
                for (var b3 in a3) {
                  var c3 = a3[b3];
                  "string" == typeof c3 && c3.match(x) && (a3[b3] = A(x, c3, z));
                }
              }, C = function(a3) {
                var b3 = a3.match(u).map(Math.floor);
                return "".concat(a3.match(w)[0]).concat(b3.join(","), ")");
              }, D = function(a3) {
                return a3.match(u);
              }, E = function(a3) {
                var b3, c3, d3 = {};
                for (var e2 in a3) {
                  var f2 = a3[e2];
                  "string" == typeof f2 && (d3[e2] = { formatString: (b3 = f2, c3 = void 0, c3 = b3.match(t), c3 ? (1 === c3.length || b3.charAt(0).match(s)) && c3.unshift("") : c3 = ["", ""], c3.join("VAL")), chunkNames: y(D(f2), e2) });
                }
                return d3;
              }, F = function(a3, b3) {
                var c3 = function(c4) {
                  D(a3[c4]).forEach(function(d4, e2) {
                    return a3[b3[c4].chunkNames[e2]] = +d4;
                  }), delete a3[c4];
                };
                for (var d3 in b3)
                  c3(d3);
              }, G = function(a3, b3) {
                var c3 = {};
                return b3.forEach(function(b4) {
                  c3[b4] = a3[b4], delete a3[b4];
                }), c3;
              }, H = function(a3, b3) {
                return b3.map(function(b4) {
                  return a3[b4];
                });
              }, I = function(a3, b3) {
                return b3.forEach(function(b4) {
                  return a3 = a3.replace("VAL", +b4.toFixed(4));
                }), a3;
              }, J = function(a3, b3) {
                for (var c3 in b3) {
                  var d3 = b3[c3], e2 = d3.chunkNames, f2 = d3.formatString, g2 = I(f2, H(G(a3, e2), e2));
                  a3[c3] = A(v, g2, C);
                }
              }, K = function(a3, b3) {
                var c3 = function(c4) {
                  var d4 = b3[c4].chunkNames, e2 = a3[c4];
                  if ("string" == typeof e2) {
                    var f2 = e2.split(" "), g2 = f2[f2.length - 1];
                    d4.forEach(function(b4, c5) {
                      return a3[b4] = f2[c5] || g2;
                    });
                  } else
                    d4.forEach(function(b4) {
                      return a3[b4] = e2;
                    });
                  delete a3[c4];
                };
                for (var d3 in b3)
                  c3(d3);
              }, L = function(a3, b3) {
                for (var c3 in b3) {
                  var d3 = b3[c3].chunkNames, e2 = a3[d3[0]];
                  a3[c3] = "string" == typeof e2 ? d3.map(function(b4) {
                    var c4 = a3[b4];
                    return delete a3[b4], c4;
                  }).join(" ") : e2;
                }
              }, M = function(a3) {
                var b3 = a3._currentState;
                return Object.keys(b3).some(function(a4) {
                  return "string" == typeof b3[a4];
                });
              }, N = new r.a(), O = r.a.filters, P = function(a3, b3, c3, d3) {
                var e2 = arguments.length > 4 && void 0 !== arguments[4] ? arguments[4] : 0, f2 = i({}, a3), g2 = Object(r.b)(a3, d3);
                for (var h2 in N._filters.length = 0, N.set({}), N._currentState = f2, N._originalState = a3, N._targetState = b3, N._easing = g2, O)
                  O[h2].doesApply(N) && N._filters.push(O[h2]);
                N._applyFilter("tweenCreated"), N._applyFilter("beforeTween");
                var j2 = Object(r.e)(c3, f2, a3, b3, 1, e2, g2);
                return N._applyFilter("afterTween"), j2;
              }, Q = function() {
                function a3() {
                  !function(a4, b5) {
                    if (!(a4 instanceof b5))
                      throw new TypeError("Cannot call a class as a function");
                  }(this, a3), R.set(this, { writable: true, value: [] });
                  for (var b4 = arguments.length, c4 = new Array(b4), d4 = 0; d4 < b4; d4++)
                    c4[d4] = arguments[d4];
                  c4.forEach(this.add.bind(this));
                }
                var b3, c3, d3;
                return b3 = a3, (c3 = [{ key: "add", value: function(a4) {
                  return m(this, R).push(a4), a4;
                } }, { key: "remove", value: function(a4) {
                  var b4 = m(this, R).indexOf(a4);
                  return ~b4 && m(this, R).splice(b4, 1), a4;
                } }, { key: "empty", value: function() {
                  return this.tweenables.map(this.remove.bind(this));
                } }, { key: "isPlaying", value: function() {
                  return m(this, R).some(function(a4) {
                    return a4.isPlaying();
                  });
                } }, { key: "play", value: function() {
                  return m(this, R).forEach(function(a4) {
                    return a4.tween();
                  }), this;
                } }, { key: "pause", value: function() {
                  return m(this, R).forEach(function(a4) {
                    return a4.pause();
                  }), this;
                } }, { key: "resume", value: function() {
                  return m(this, R).forEach(function(a4) {
                    return a4.resume();
                  }), this;
                } }, { key: "stop", value: function(a4) {
                  return m(this, R).forEach(function(b4) {
                    return b4.stop(a4);
                  }), this;
                } }, { key: "tweenables", get: function() {
                  return k(m(this, R));
                } }, { key: "promises", get: function() {
                  return m(this, R).map(function(a4) {
                    return a4._promise;
                  });
                } }]) && l(b3.prototype, c3), d3 && l(b3, d3), a3;
              }(), R = /* @__PURE__ */ new WeakMap(), S = function(a3, b3, c3, d3, e2) {
                var f2 = function(a4, b4, c4, d4) {
                  return function(e3) {
                    return n(e3, a4, b4, c4, d4, 1);
                  };
                }(b3, c3, d3, e2);
                return f2.displayName = a3, f2.x1 = b3, f2.y1 = c3, f2.x2 = d3, f2.y2 = e2, r.a.formulas[a3] = f2;
              }, T = function(a3) {
                return delete r.a.formulas[a3];
              };
              c2.d(b2, "processTweens", function() {
                return r.c;
              }), c2.d(b2, "Tweenable", function() {
                return r.a;
              }), c2.d(b2, "tween", function() {
                return r.d;
              }), c2.d(b2, "interpolate", function() {
                return P;
              }), c2.d(b2, "Scene", function() {
                return Q;
              }), c2.d(b2, "setBezierFunction", function() {
                return S;
              }), c2.d(b2, "unsetBezierFunction", function() {
                return T;
              }), r.a.filters.token = o;
            }]);
          });
        }, {}], 2: [function(a2, b, c) {
          var d = a2("./shape"), e = a2("./utils"), f = function(a3, b2) {
            this._pathTemplate = "M 50,50 m 0,-{radius} a {radius},{radius} 0 1 1 0,{2radius} a {radius},{radius} 0 1 1 0,-{2radius}", this.containerAspectRatio = 1, d.apply(this, arguments);
          };
          f.prototype = new d(), f.prototype.constructor = f, f.prototype._pathString = function(a3) {
            var b2 = a3.strokeWidth;
            a3.trailWidth && a3.trailWidth > a3.strokeWidth && (b2 = a3.trailWidth);
            var c2 = 50 - b2 / 2;
            return e.render(this._pathTemplate, { radius: c2, "2radius": 2 * c2 });
          }, f.prototype._trailString = function(a3) {
            return this._pathString(a3);
          }, b.exports = f;
        }, { "./shape": 7, "./utils": 9 }], 3: [function(a2, b, c) {
          var d = a2("./shape"), e = a2("./utils"), f = function(a3, b2) {
            this._pathTemplate = b2.vertical ? "M {center},100 L {center},0" : "M 0,{center} L 100,{center}", d.apply(this, arguments);
          };
          f.prototype = new d(), f.prototype.constructor = f, f.prototype._initializeSvg = function(a3, b2) {
            var c2 = b2.vertical ? "0 0 " + b2.strokeWidth + " 100" : "0 0 100 " + b2.strokeWidth;
            a3.setAttribute("viewBox", c2), a3.setAttribute("preserveAspectRatio", "none");
          }, f.prototype._pathString = function(a3) {
            return e.render(this._pathTemplate, { center: a3.strokeWidth / 2 });
          }, f.prototype._trailString = function(a3) {
            return this._pathString(a3);
          }, b.exports = f;
        }, { "./shape": 7, "./utils": 9 }], 4: [function(a2, b, c) {
          b.exports = { Line: a2("./line"), Circle: a2("./circle"), SemiCircle: a2("./semicircle"), Square: a2("./square"), Path: a2("./path"), Shape: a2("./shape"), utils: a2("./utils") };
        }, { "./circle": 2, "./line": 3, "./path": 5, "./semicircle": 6, "./shape": 7, "./square": 8, "./utils": 9 }], 5: [function(a2, b, c) {
          var d = a2("shifty"), e = a2("./utils"), f = d.Tweenable, g = { easeIn: "easeInCubic", easeOut: "easeOutCubic", easeInOut: "easeInOutCubic" }, h = function a3(b2, c2) {
            if (!(this instanceof a3))
              throw new Error("Constructor was called without new keyword");
            c2 = e.extend({ delay: 0, duration: 800, easing: "linear", from: {}, to: {}, step: function() {
            } }, c2);
            var d2;
            d2 = e.isString(b2) ? document.querySelector(b2) : b2, this.path = d2, this._opts = c2, this._tweenable = null;
            var f2 = this.path.getTotalLength();
            this.path.style.strokeDasharray = f2 + " " + f2, this.set(0);
          };
          h.prototype.value = function() {
            var a3 = this._getComputedDashOffset(), b2 = this.path.getTotalLength(), c2 = 1 - a3 / b2;
            return parseFloat(c2.toFixed(6), 10);
          }, h.prototype.set = function(a3) {
            this.stop(), this.path.style.strokeDashoffset = this._progressToOffset(a3);
            var b2 = this._opts.step;
            if (e.isFunction(b2)) {
              var c2 = this._easing(this._opts.easing);
              b2(this._calculateTo(a3, c2), this._opts.shape || this, this._opts.attachment);
            }
          }, h.prototype.stop = function() {
            this._stopTween(), this.path.style.strokeDashoffset = this._getComputedDashOffset();
          }, h.prototype.animate = function(a3, b2, c2) {
            b2 = b2 || {}, e.isFunction(b2) && (c2 = b2, b2 = {});
            var d2 = e.extend({}, b2), g2 = e.extend({}, this._opts);
            b2 = e.extend(g2, b2);
            var h2 = this._easing(b2.easing), i = this._resolveFromAndTo(a3, h2, d2);
            this.stop(), this.path.getBoundingClientRect();
            var j = this._getComputedDashOffset(), k = this._progressToOffset(a3), l = this;
            this._tweenable = new f(), this._tweenable.tween({ from: e.extend({ offset: j }, i.from), to: e.extend({ offset: k }, i.to), duration: b2.duration, delay: b2.delay, easing: h2, step: function(a4) {
              l.path.style.strokeDashoffset = a4.offset;
              var c3 = b2.shape || l;
              b2.step(a4, c3, b2.attachment);
            } }).then(function(a4) {
              e.isFunction(c2) && c2();
            }).catch(function(a4) {
              throw console.error("Error in tweening:", a4), a4;
            });
          }, h.prototype._getComputedDashOffset = function() {
            var a3 = window.getComputedStyle(this.path, null);
            return parseFloat(a3.getPropertyValue("stroke-dashoffset"), 10);
          }, h.prototype._progressToOffset = function(a3) {
            var b2 = this.path.getTotalLength();
            return b2 - a3 * b2;
          }, h.prototype._resolveFromAndTo = function(a3, b2, c2) {
            return c2.from && c2.to ? { from: c2.from, to: c2.to } : { from: this._calculateFrom(b2), to: this._calculateTo(a3, b2) };
          }, h.prototype._calculateFrom = function(a3) {
            return d.interpolate(this._opts.from, this._opts.to, this.value(), a3);
          }, h.prototype._calculateTo = function(a3, b2) {
            return d.interpolate(this._opts.from, this._opts.to, a3, b2);
          }, h.prototype._stopTween = function() {
            null !== this._tweenable && (this._tweenable.stop(true), this._tweenable = null);
          }, h.prototype._easing = function(a3) {
            return g.hasOwnProperty(a3) ? g[a3] : a3;
          }, b.exports = h;
        }, { "./utils": 9, shifty: 1 }], 6: [function(a2, b, c) {
          var d = a2("./shape"), e = a2("./circle"), f = a2("./utils"), g = function(a3, b2) {
            this._pathTemplate = "M 50,50 m -{radius},0 a {radius},{radius} 0 1 1 {2radius},0", this.containerAspectRatio = 2, d.apply(this, arguments);
          };
          g.prototype = new d(), g.prototype.constructor = g, g.prototype._initializeSvg = function(a3, b2) {
            a3.setAttribute("viewBox", "0 0 100 50");
          }, g.prototype._initializeTextContainer = function(a3, b2, c2) {
            a3.text.style && (c2.style.top = "auto", c2.style.bottom = "0", a3.text.alignToBottom ? f.setStyle(c2, "transform", "translate(-50%, 0)") : f.setStyle(c2, "transform", "translate(-50%, 50%)"));
          }, g.prototype._pathString = e.prototype._pathString, g.prototype._trailString = e.prototype._trailString, b.exports = g;
        }, { "./circle": 2, "./shape": 7, "./utils": 9 }], 7: [function(a2, b, c) {
          var d = a2("./path"), e = a2("./utils"), f = "Object is destroyed", g = function a3(b2, c2) {
            if (!(this instanceof a3))
              throw new Error("Constructor was called without new keyword");
            if (0 !== arguments.length) {
              this._opts = e.extend({ color: "#555", strokeWidth: 1, trailColor: null, trailWidth: null, fill: null, text: { style: { color: null, position: "absolute", left: "50%", top: "50%", padding: 0, margin: 0, transform: { prefix: true, value: "translate(-50%, -50%)" } }, autoStyleContainer: true, alignToBottom: true, value: null, className: "progressbar-text" }, svgStyle: { display: "block", width: "100%" }, warnings: false }, c2, true), e.isObject(c2) && void 0 !== c2.svgStyle && (this._opts.svgStyle = c2.svgStyle), e.isObject(c2) && e.isObject(c2.text) && void 0 !== c2.text.style && (this._opts.text.style = c2.text.style);
              var f2, g2 = this._createSvgView(this._opts);
              if (!(f2 = e.isString(b2) ? document.querySelector(b2) : b2))
                throw new Error("Container does not exist: " + b2);
              this._container = f2, this._container.appendChild(g2.svg), this._opts.warnings && this._warnContainerAspectRatio(this._container), this._opts.svgStyle && e.setStyles(g2.svg, this._opts.svgStyle), this.svg = g2.svg, this.path = g2.path, this.trail = g2.trail, this.text = null;
              var h = e.extend({ attachment: void 0, shape: this }, this._opts);
              this._progressPath = new d(g2.path, h), e.isObject(this._opts.text) && null !== this._opts.text.value && this.setText(this._opts.text.value);
            }
          };
          g.prototype.animate = function(a3, b2, c2) {
            if (null === this._progressPath)
              throw new Error(f);
            this._progressPath.animate(a3, b2, c2);
          }, g.prototype.stop = function() {
            if (null === this._progressPath)
              throw new Error(f);
            void 0 !== this._progressPath && this._progressPath.stop();
          }, g.prototype.pause = function() {
            if (null === this._progressPath)
              throw new Error(f);
            void 0 !== this._progressPath && this._progressPath._tweenable && this._progressPath._tweenable.pause();
          }, g.prototype.resume = function() {
            if (null === this._progressPath)
              throw new Error(f);
            void 0 !== this._progressPath && this._progressPath._tweenable && this._progressPath._tweenable.resume();
          }, g.prototype.destroy = function() {
            if (null === this._progressPath)
              throw new Error(f);
            this.stop(), this.svg.parentNode.removeChild(this.svg), this.svg = null, this.path = null, this.trail = null, this._progressPath = null, null !== this.text && (this.text.parentNode.removeChild(this.text), this.text = null);
          }, g.prototype.set = function(a3) {
            if (null === this._progressPath)
              throw new Error(f);
            this._progressPath.set(a3);
          }, g.prototype.value = function() {
            if (null === this._progressPath)
              throw new Error(f);
            return void 0 === this._progressPath ? 0 : this._progressPath.value();
          }, g.prototype.setText = function(a3) {
            if (null === this._progressPath)
              throw new Error(f);
            null === this.text && (this.text = this._createTextContainer(this._opts, this._container), this._container.appendChild(this.text)), e.isObject(a3) ? (e.removeChildren(this.text), this.text.appendChild(a3)) : this.text.innerHTML = a3;
          }, g.prototype._createSvgView = function(a3) {
            var b2 = document.createElementNS("http://www.w3.org/2000/svg", "svg");
            this._initializeSvg(b2, a3);
            var c2 = null;
            (a3.trailColor || a3.trailWidth) && (c2 = this._createTrail(a3), b2.appendChild(c2));
            var d2 = this._createPath(a3);
            return b2.appendChild(d2), { svg: b2, path: d2, trail: c2 };
          }, g.prototype._initializeSvg = function(a3, b2) {
            a3.setAttribute("viewBox", "0 0 100 100");
          }, g.prototype._createPath = function(a3) {
            var b2 = this._pathString(a3);
            return this._createPathElement(b2, a3);
          }, g.prototype._createTrail = function(a3) {
            var b2 = this._trailString(a3), c2 = e.extend({}, a3);
            return c2.trailColor || (c2.trailColor = "#eee"), c2.trailWidth || (c2.trailWidth = c2.strokeWidth), c2.color = c2.trailColor, c2.strokeWidth = c2.trailWidth, c2.fill = null, this._createPathElement(b2, c2);
          }, g.prototype._createPathElement = function(a3, b2) {
            var c2 = document.createElementNS("http://www.w3.org/2000/svg", "path");
            return c2.setAttribute("d", a3), c2.setAttribute("stroke", b2.color), c2.setAttribute("stroke-width", b2.strokeWidth), b2.fill ? c2.setAttribute("fill", b2.fill) : c2.setAttribute("fill-opacity", "0"), c2;
          }, g.prototype._createTextContainer = function(a3, b2) {
            var c2 = document.createElement("div");
            c2.className = a3.text.className;
            var d2 = a3.text.style;
            return d2 && (a3.text.autoStyleContainer && (b2.style.position = "relative"), e.setStyles(c2, d2), d2.color || (c2.style.color = a3.color)), this._initializeTextContainer(a3, b2, c2), c2;
          }, g.prototype._initializeTextContainer = function(a3, b2, c2) {
          }, g.prototype._pathString = function(a3) {
            throw new Error("Override this function for each progress bar");
          }, g.prototype._trailString = function(a3) {
            throw new Error("Override this function for each progress bar");
          }, g.prototype._warnContainerAspectRatio = function(a3) {
            if (this.containerAspectRatio) {
              var b2 = window.getComputedStyle(a3, null), c2 = parseFloat(b2.getPropertyValue("width"), 10), d2 = parseFloat(b2.getPropertyValue("height"), 10);
              e.floatEquals(this.containerAspectRatio, c2 / d2) || (console.warn("Incorrect aspect ratio of container", "#" + a3.id, "detected:", b2.getPropertyValue("width") + "(width)", "/", b2.getPropertyValue("height") + "(height)", "=", c2 / d2), console.warn("Aspect ratio of should be", this.containerAspectRatio));
            }
          }, b.exports = g;
        }, { "./path": 5, "./utils": 9 }], 8: [function(a2, b, c) {
          var d = a2("./shape"), e = a2("./utils"), f = function(a3, b2) {
            this._pathTemplate = "M 0,{halfOfStrokeWidth} L {width},{halfOfStrokeWidth} L {width},{width} L {halfOfStrokeWidth},{width} L {halfOfStrokeWidth},{strokeWidth}", this._trailTemplate = "M {startMargin},{halfOfStrokeWidth} L {width},{halfOfStrokeWidth} L {width},{width} L {halfOfStrokeWidth},{width} L {halfOfStrokeWidth},{halfOfStrokeWidth}", d.apply(this, arguments);
          };
          f.prototype = new d(), f.prototype.constructor = f, f.prototype._pathString = function(a3) {
            var b2 = 100 - a3.strokeWidth / 2;
            return e.render(this._pathTemplate, { width: b2, strokeWidth: a3.strokeWidth, halfOfStrokeWidth: a3.strokeWidth / 2 });
          }, f.prototype._trailString = function(a3) {
            var b2 = 100 - a3.strokeWidth / 2;
            return e.render(this._trailTemplate, { width: b2, strokeWidth: a3.strokeWidth, halfOfStrokeWidth: a3.strokeWidth / 2, startMargin: a3.strokeWidth / 2 - a3.trailWidth / 2 });
          }, b.exports = f;
        }, { "./shape": 7, "./utils": 9 }], 9: [function(a2, b, c) {
          function d(a3, b2, c2) {
            a3 = a3 || {}, b2 = b2 || {}, c2 = c2 || false;
            for (var e2 in b2)
              if (b2.hasOwnProperty(e2)) {
                var f2 = a3[e2], g2 = b2[e2];
                c2 && l(f2) && l(g2) ? a3[e2] = d(f2, g2, c2) : a3[e2] = g2;
              }
            return a3;
          }
          function e(a3, b2) {
            var c2 = a3;
            for (var d2 in b2)
              if (b2.hasOwnProperty(d2)) {
                var e2 = b2[d2], f2 = "\\{" + d2 + "\\}", g2 = new RegExp(f2, "g");
                c2 = c2.replace(g2, e2);
              }
            return c2;
          }
          function f(a3, b2, c2) {
            for (var d2 = a3.style, e2 = 0; e2 < p.length; ++e2) {
              d2[p[e2] + h(b2)] = c2;
            }
            d2[b2] = c2;
          }
          function g(a3, b2) {
            m(b2, function(b3, c2) {
              null !== b3 && void 0 !== b3 && (l(b3) && true === b3.prefix ? f(a3, c2, b3.value) : a3.style[c2] = b3);
            });
          }
          function h(a3) {
            return a3.charAt(0).toUpperCase() + a3.slice(1);
          }
          function i(a3) {
            return "string" == typeof a3 || a3 instanceof String;
          }
          function j(a3) {
            return "function" == typeof a3;
          }
          function k(a3) {
            return "[object Array]" === Object.prototype.toString.call(a3);
          }
          function l(a3) {
            return !k(a3) && ("object" == typeof a3 && !!a3);
          }
          function m(a3, b2) {
            for (var c2 in a3)
              if (a3.hasOwnProperty(c2)) {
                var d2 = a3[c2];
                b2(d2, c2);
              }
          }
          function n(a3, b2) {
            return Math.abs(a3 - b2) < q;
          }
          function o(a3) {
            for (; a3.firstChild; )
              a3.removeChild(a3.firstChild);
          }
          var p = "Webkit Moz O ms".split(" "), q = 1e-3;
          b.exports = { extend: d, render: e, setStyle: f, setStyles: g, capitalize: h, isString: i, isFunction: j, isObject: l, forEachObject: m, floatEquals: n, removeChildren: o };
        }, {}] }, {}, [4])(4);
      });
    }
  });

  // node_modules/@hotwired/turbo/dist/turbo.es2017-esm.js
  (function() {
    if (window.Reflect === void 0 || window.customElements === void 0 || window.customElements.polyfillWrapFlushCallback) {
      return;
    }
    const BuiltInHTMLElement = HTMLElement;
    const wrapperForTheName = {
      HTMLElement: function HTMLElement2() {
        return Reflect.construct(BuiltInHTMLElement, [], this.constructor);
      }
    };
    window.HTMLElement = wrapperForTheName["HTMLElement"];
    HTMLElement.prototype = BuiltInHTMLElement.prototype;
    HTMLElement.prototype.constructor = HTMLElement;
    Object.setPrototypeOf(HTMLElement, BuiltInHTMLElement);
  })();
  (function(prototype) {
    if (typeof prototype.requestSubmit == "function")
      return;
    prototype.requestSubmit = function(submitter) {
      if (submitter) {
        validateSubmitter(submitter, this);
        submitter.click();
      } else {
        submitter = document.createElement("input");
        submitter.type = "submit";
        submitter.hidden = true;
        this.appendChild(submitter);
        submitter.click();
        this.removeChild(submitter);
      }
    };
    function validateSubmitter(submitter, form) {
      submitter instanceof HTMLElement || raise(TypeError, "parameter 1 is not of type 'HTMLElement'");
      submitter.type == "submit" || raise(TypeError, "The specified element is not a submit button");
      submitter.form == form || raise(DOMException, "The specified element is not owned by this form element", "NotFoundError");
    }
    function raise(errorConstructor, message, name) {
      throw new errorConstructor("Failed to execute 'requestSubmit' on 'HTMLFormElement': " + message + ".", name);
    }
  })(HTMLFormElement.prototype);
  var submittersByForm = /* @__PURE__ */ new WeakMap();
  function findSubmitterFromClickTarget(target) {
    const element = target instanceof Element ? target : target instanceof Node ? target.parentElement : null;
    const candidate = element ? element.closest("input, button") : null;
    return (candidate === null || candidate === void 0 ? void 0 : candidate.type) == "submit" ? candidate : null;
  }
  function clickCaptured(event) {
    const submitter = findSubmitterFromClickTarget(event.target);
    if (submitter && submitter.form) {
      submittersByForm.set(submitter.form, submitter);
    }
  }
  (function() {
    if ("submitter" in Event.prototype)
      return;
    let prototype = window.Event.prototype;
    if ("SubmitEvent" in window && /Apple Computer/.test(navigator.vendor)) {
      prototype = window.SubmitEvent.prototype;
    } else if ("SubmitEvent" in window) {
      return;
    }
    addEventListener("click", clickCaptured, true);
    Object.defineProperty(prototype, "submitter", {
      get() {
        if (this.type == "submit" && this.target instanceof HTMLFormElement) {
          return submittersByForm.get(this.target);
        }
      }
    });
  })();
  var FrameLoadingStyle;
  (function(FrameLoadingStyle2) {
    FrameLoadingStyle2["eager"] = "eager";
    FrameLoadingStyle2["lazy"] = "lazy";
  })(FrameLoadingStyle || (FrameLoadingStyle = {}));
  var FrameElement = class extends HTMLElement {
    static get observedAttributes() {
      return ["disabled", "complete", "loading", "src"];
    }
    constructor() {
      super();
      this.loaded = Promise.resolve();
      this.delegate = new FrameElement.delegateConstructor(this);
    }
    connectedCallback() {
      this.delegate.connect();
    }
    disconnectedCallback() {
      this.delegate.disconnect();
    }
    reload() {
      return this.delegate.sourceURLReloaded();
    }
    attributeChangedCallback(name) {
      if (name == "loading") {
        this.delegate.loadingStyleChanged();
      } else if (name == "complete") {
        this.delegate.completeChanged();
      } else if (name == "src") {
        this.delegate.sourceURLChanged();
      } else {
        this.delegate.disabledChanged();
      }
    }
    get src() {
      return this.getAttribute("src");
    }
    set src(value) {
      if (value) {
        this.setAttribute("src", value);
      } else {
        this.removeAttribute("src");
      }
    }
    get loading() {
      return frameLoadingStyleFromString(this.getAttribute("loading") || "");
    }
    set loading(value) {
      if (value) {
        this.setAttribute("loading", value);
      } else {
        this.removeAttribute("loading");
      }
    }
    get disabled() {
      return this.hasAttribute("disabled");
    }
    set disabled(value) {
      if (value) {
        this.setAttribute("disabled", "");
      } else {
        this.removeAttribute("disabled");
      }
    }
    get autoscroll() {
      return this.hasAttribute("autoscroll");
    }
    set autoscroll(value) {
      if (value) {
        this.setAttribute("autoscroll", "");
      } else {
        this.removeAttribute("autoscroll");
      }
    }
    get complete() {
      return !this.delegate.isLoading;
    }
    get isActive() {
      return this.ownerDocument === document && !this.isPreview;
    }
    get isPreview() {
      var _a, _b;
      return (_b = (_a = this.ownerDocument) === null || _a === void 0 ? void 0 : _a.documentElement) === null || _b === void 0 ? void 0 : _b.hasAttribute("data-turbo-preview");
    }
  };
  function frameLoadingStyleFromString(style) {
    switch (style.toLowerCase()) {
      case "lazy":
        return FrameLoadingStyle.lazy;
      default:
        return FrameLoadingStyle.eager;
    }
  }
  function expandURL(locatable) {
    return new URL(locatable.toString(), document.baseURI);
  }
  function getAnchor(url) {
    let anchorMatch;
    if (url.hash) {
      return url.hash.slice(1);
    } else if (anchorMatch = url.href.match(/#(.*)$/)) {
      return anchorMatch[1];
    }
  }
  function getAction(form, submitter) {
    const action = (submitter === null || submitter === void 0 ? void 0 : submitter.getAttribute("formaction")) || form.getAttribute("action") || form.action;
    return expandURL(action);
  }
  function getExtension(url) {
    return (getLastPathComponent(url).match(/\.[^.]*$/) || [])[0] || "";
  }
  function isHTML(url) {
    return !!getExtension(url).match(/^(?:|\.(?:htm|html|xhtml|php))$/);
  }
  function isPrefixedBy(baseURL, url) {
    const prefix = getPrefix(url);
    return baseURL.href === expandURL(prefix).href || baseURL.href.startsWith(prefix);
  }
  function locationIsVisitable(location2, rootLocation) {
    return isPrefixedBy(location2, rootLocation) && isHTML(location2);
  }
  function getRequestURL(url) {
    const anchor = getAnchor(url);
    return anchor != null ? url.href.slice(0, -(anchor.length + 1)) : url.href;
  }
  function toCacheKey(url) {
    return getRequestURL(url);
  }
  function urlsAreEqual(left2, right2) {
    return expandURL(left2).href == expandURL(right2).href;
  }
  function getPathComponents(url) {
    return url.pathname.split("/").slice(1);
  }
  function getLastPathComponent(url) {
    return getPathComponents(url).slice(-1)[0];
  }
  function getPrefix(url) {
    return addTrailingSlash(url.origin + url.pathname);
  }
  function addTrailingSlash(value) {
    return value.endsWith("/") ? value : value + "/";
  }
  var FetchResponse = class {
    constructor(response) {
      this.response = response;
    }
    get succeeded() {
      return this.response.ok;
    }
    get failed() {
      return !this.succeeded;
    }
    get clientError() {
      return this.statusCode >= 400 && this.statusCode <= 499;
    }
    get serverError() {
      return this.statusCode >= 500 && this.statusCode <= 599;
    }
    get redirected() {
      return this.response.redirected;
    }
    get location() {
      return expandURL(this.response.url);
    }
    get isHTML() {
      return this.contentType && this.contentType.match(/^(?:text\/([^\s;,]+\b)?html|application\/xhtml\+xml)\b/);
    }
    get statusCode() {
      return this.response.status;
    }
    get contentType() {
      return this.header("Content-Type");
    }
    get responseText() {
      return this.response.clone().text();
    }
    get responseHTML() {
      if (this.isHTML) {
        return this.response.clone().text();
      } else {
        return Promise.resolve(void 0);
      }
    }
    header(name) {
      return this.response.headers.get(name);
    }
  };
  function activateScriptElement(element) {
    if (element.getAttribute("data-turbo-eval") == "false") {
      return element;
    } else {
      const createdScriptElement = document.createElement("script");
      const cspNonce = getMetaContent("csp-nonce");
      if (cspNonce) {
        createdScriptElement.nonce = cspNonce;
      }
      createdScriptElement.textContent = element.textContent;
      createdScriptElement.async = false;
      copyElementAttributes(createdScriptElement, element);
      return createdScriptElement;
    }
  }
  function copyElementAttributes(destinationElement, sourceElement) {
    for (const { name, value } of sourceElement.attributes) {
      destinationElement.setAttribute(name, value);
    }
  }
  function createDocumentFragment(html) {
    const template = document.createElement("template");
    template.innerHTML = html;
    return template.content;
  }
  function dispatch(eventName, { target, cancelable, detail } = {}) {
    const event = new CustomEvent(eventName, {
      cancelable,
      bubbles: true,
      composed: true,
      detail
    });
    if (target && target.isConnected) {
      target.dispatchEvent(event);
    } else {
      document.documentElement.dispatchEvent(event);
    }
    return event;
  }
  function nextAnimationFrame() {
    return new Promise((resolve) => requestAnimationFrame(() => resolve()));
  }
  function nextEventLoopTick() {
    return new Promise((resolve) => setTimeout(() => resolve(), 0));
  }
  function nextMicrotask() {
    return Promise.resolve();
  }
  function parseHTMLDocument(html = "") {
    return new DOMParser().parseFromString(html, "text/html");
  }
  function unindent(strings, ...values) {
    const lines = interpolate(strings, values).replace(/^\n/, "").split("\n");
    const match = lines[0].match(/^\s+/);
    const indent = match ? match[0].length : 0;
    return lines.map((line) => line.slice(indent)).join("\n");
  }
  function interpolate(strings, values) {
    return strings.reduce((result, string, i) => {
      const value = values[i] == void 0 ? "" : values[i];
      return result + string + value;
    }, "");
  }
  function uuid() {
    return Array.from({ length: 36 }).map((_, i) => {
      if (i == 8 || i == 13 || i == 18 || i == 23) {
        return "-";
      } else if (i == 14) {
        return "4";
      } else if (i == 19) {
        return (Math.floor(Math.random() * 4) + 8).toString(16);
      } else {
        return Math.floor(Math.random() * 15).toString(16);
      }
    }).join("");
  }
  function getAttribute(attributeName, ...elements) {
    for (const value of elements.map((element) => element === null || element === void 0 ? void 0 : element.getAttribute(attributeName))) {
      if (typeof value == "string")
        return value;
    }
    return null;
  }
  function hasAttribute(attributeName, ...elements) {
    return elements.some((element) => element && element.hasAttribute(attributeName));
  }
  function markAsBusy(...elements) {
    for (const element of elements) {
      if (element.localName == "turbo-frame") {
        element.setAttribute("busy", "");
      }
      element.setAttribute("aria-busy", "true");
    }
  }
  function clearBusyState(...elements) {
    for (const element of elements) {
      if (element.localName == "turbo-frame") {
        element.removeAttribute("busy");
      }
      element.removeAttribute("aria-busy");
    }
  }
  function waitForLoad(element, timeoutInMilliseconds = 2e3) {
    return new Promise((resolve) => {
      const onComplete = () => {
        element.removeEventListener("error", onComplete);
        element.removeEventListener("load", onComplete);
        resolve();
      };
      element.addEventListener("load", onComplete, { once: true });
      element.addEventListener("error", onComplete, { once: true });
      setTimeout(resolve, timeoutInMilliseconds);
    });
  }
  function getHistoryMethodForAction(action) {
    switch (action) {
      case "replace":
        return history.replaceState;
      case "advance":
      case "restore":
        return history.pushState;
    }
  }
  function isAction(action) {
    return action == "advance" || action == "replace" || action == "restore";
  }
  function getVisitAction(...elements) {
    const action = getAttribute("data-turbo-action", ...elements);
    return isAction(action) ? action : null;
  }
  function getMetaElement(name) {
    return document.querySelector(`meta[name="${name}"]`);
  }
  function getMetaContent(name) {
    const element = getMetaElement(name);
    return element && element.content;
  }
  function setMetaContent(name, content) {
    let element = getMetaElement(name);
    if (!element) {
      element = document.createElement("meta");
      element.setAttribute("name", name);
      document.head.appendChild(element);
    }
    element.setAttribute("content", content);
    return element;
  }
  function findClosestRecursively(element, selector) {
    var _a;
    if (element instanceof Element) {
      return element.closest(selector) || findClosestRecursively(element.assignedSlot || ((_a = element.getRootNode()) === null || _a === void 0 ? void 0 : _a.host), selector);
    }
  }
  var FetchMethod;
  (function(FetchMethod2) {
    FetchMethod2[FetchMethod2["get"] = 0] = "get";
    FetchMethod2[FetchMethod2["post"] = 1] = "post";
    FetchMethod2[FetchMethod2["put"] = 2] = "put";
    FetchMethod2[FetchMethod2["patch"] = 3] = "patch";
    FetchMethod2[FetchMethod2["delete"] = 4] = "delete";
  })(FetchMethod || (FetchMethod = {}));
  function fetchMethodFromString(method) {
    switch (method.toLowerCase()) {
      case "get":
        return FetchMethod.get;
      case "post":
        return FetchMethod.post;
      case "put":
        return FetchMethod.put;
      case "patch":
        return FetchMethod.patch;
      case "delete":
        return FetchMethod.delete;
    }
  }
  var FetchRequest = class {
    constructor(delegate, method, location2, body = new URLSearchParams(), target = null) {
      this.abortController = new AbortController();
      this.resolveRequestPromise = (_value) => {
      };
      this.delegate = delegate;
      this.method = method;
      this.headers = this.defaultHeaders;
      this.body = body;
      this.url = location2;
      this.target = target;
    }
    get location() {
      return this.url;
    }
    get params() {
      return this.url.searchParams;
    }
    get entries() {
      return this.body ? Array.from(this.body.entries()) : [];
    }
    cancel() {
      this.abortController.abort();
    }
    async perform() {
      const { fetchOptions } = this;
      this.delegate.prepareRequest(this);
      await this.allowRequestToBeIntercepted(fetchOptions);
      try {
        this.delegate.requestStarted(this);
        const response = await fetch(this.url.href, fetchOptions);
        return await this.receive(response);
      } catch (error2) {
        if (error2.name !== "AbortError") {
          if (this.willDelegateErrorHandling(error2)) {
            this.delegate.requestErrored(this, error2);
          }
          throw error2;
        }
      } finally {
        this.delegate.requestFinished(this);
      }
    }
    async receive(response) {
      const fetchResponse = new FetchResponse(response);
      const event = dispatch("turbo:before-fetch-response", {
        cancelable: true,
        detail: { fetchResponse },
        target: this.target
      });
      if (event.defaultPrevented) {
        this.delegate.requestPreventedHandlingResponse(this, fetchResponse);
      } else if (fetchResponse.succeeded) {
        this.delegate.requestSucceededWithResponse(this, fetchResponse);
      } else {
        this.delegate.requestFailedWithResponse(this, fetchResponse);
      }
      return fetchResponse;
    }
    get fetchOptions() {
      var _a;
      return {
        method: FetchMethod[this.method].toUpperCase(),
        credentials: "same-origin",
        headers: this.headers,
        redirect: "follow",
        body: this.isSafe ? null : this.body,
        signal: this.abortSignal,
        referrer: (_a = this.delegate.referrer) === null || _a === void 0 ? void 0 : _a.href
      };
    }
    get defaultHeaders() {
      return {
        Accept: "text/html, application/xhtml+xml"
      };
    }
    get isSafe() {
      return this.method === FetchMethod.get;
    }
    get abortSignal() {
      return this.abortController.signal;
    }
    acceptResponseType(mimeType) {
      this.headers["Accept"] = [mimeType, this.headers["Accept"]].join(", ");
    }
    async allowRequestToBeIntercepted(fetchOptions) {
      const requestInterception = new Promise((resolve) => this.resolveRequestPromise = resolve);
      const event = dispatch("turbo:before-fetch-request", {
        cancelable: true,
        detail: {
          fetchOptions,
          url: this.url,
          resume: this.resolveRequestPromise
        },
        target: this.target
      });
      if (event.defaultPrevented)
        await requestInterception;
    }
    willDelegateErrorHandling(error2) {
      const event = dispatch("turbo:fetch-request-error", {
        target: this.target,
        cancelable: true,
        detail: { request: this, error: error2 }
      });
      return !event.defaultPrevented;
    }
  };
  var AppearanceObserver = class {
    constructor(delegate, element) {
      this.started = false;
      this.intersect = (entries) => {
        const lastEntry = entries.slice(-1)[0];
        if (lastEntry === null || lastEntry === void 0 ? void 0 : lastEntry.isIntersecting) {
          this.delegate.elementAppearedInViewport(this.element);
        }
      };
      this.delegate = delegate;
      this.element = element;
      this.intersectionObserver = new IntersectionObserver(this.intersect);
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.intersectionObserver.observe(this.element);
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.intersectionObserver.unobserve(this.element);
      }
    }
  };
  var StreamMessage = class {
    static wrap(message) {
      if (typeof message == "string") {
        return new this(createDocumentFragment(message));
      } else {
        return message;
      }
    }
    constructor(fragment) {
      this.fragment = importStreamElements(fragment);
    }
  };
  StreamMessage.contentType = "text/vnd.turbo-stream.html";
  function importStreamElements(fragment) {
    for (const element of fragment.querySelectorAll("turbo-stream")) {
      const streamElement = document.importNode(element, true);
      for (const inertScriptElement of streamElement.templateElement.content.querySelectorAll("script")) {
        inertScriptElement.replaceWith(activateScriptElement(inertScriptElement));
      }
      element.replaceWith(streamElement);
    }
    return fragment;
  }
  var FormSubmissionState;
  (function(FormSubmissionState2) {
    FormSubmissionState2[FormSubmissionState2["initialized"] = 0] = "initialized";
    FormSubmissionState2[FormSubmissionState2["requesting"] = 1] = "requesting";
    FormSubmissionState2[FormSubmissionState2["waiting"] = 2] = "waiting";
    FormSubmissionState2[FormSubmissionState2["receiving"] = 3] = "receiving";
    FormSubmissionState2[FormSubmissionState2["stopping"] = 4] = "stopping";
    FormSubmissionState2[FormSubmissionState2["stopped"] = 5] = "stopped";
  })(FormSubmissionState || (FormSubmissionState = {}));
  var FormEnctype;
  (function(FormEnctype2) {
    FormEnctype2["urlEncoded"] = "application/x-www-form-urlencoded";
    FormEnctype2["multipart"] = "multipart/form-data";
    FormEnctype2["plain"] = "text/plain";
  })(FormEnctype || (FormEnctype = {}));
  function formEnctypeFromString(encoding) {
    switch (encoding.toLowerCase()) {
      case FormEnctype.multipart:
        return FormEnctype.multipart;
      case FormEnctype.plain:
        return FormEnctype.plain;
      default:
        return FormEnctype.urlEncoded;
    }
  }
  var FormSubmission = class {
    static confirmMethod(message, _element, _submitter) {
      return Promise.resolve(confirm(message));
    }
    constructor(delegate, formElement, submitter, mustRedirect = false) {
      this.state = FormSubmissionState.initialized;
      this.delegate = delegate;
      this.formElement = formElement;
      this.submitter = submitter;
      this.formData = buildFormData(formElement, submitter);
      this.location = expandURL(this.action);
      if (this.method == FetchMethod.get) {
        mergeFormDataEntries(this.location, [...this.body.entries()]);
      }
      this.fetchRequest = new FetchRequest(this, this.method, this.location, this.body, this.formElement);
      this.mustRedirect = mustRedirect;
    }
    get method() {
      var _a;
      const method = ((_a = this.submitter) === null || _a === void 0 ? void 0 : _a.getAttribute("formmethod")) || this.formElement.getAttribute("method") || "";
      return fetchMethodFromString(method.toLowerCase()) || FetchMethod.get;
    }
    get action() {
      var _a;
      const formElementAction = typeof this.formElement.action === "string" ? this.formElement.action : null;
      if ((_a = this.submitter) === null || _a === void 0 ? void 0 : _a.hasAttribute("formaction")) {
        return this.submitter.getAttribute("formaction") || "";
      } else {
        return this.formElement.getAttribute("action") || formElementAction || "";
      }
    }
    get body() {
      if (this.enctype == FormEnctype.urlEncoded || this.method == FetchMethod.get) {
        return new URLSearchParams(this.stringFormData);
      } else {
        return this.formData;
      }
    }
    get enctype() {
      var _a;
      return formEnctypeFromString(((_a = this.submitter) === null || _a === void 0 ? void 0 : _a.getAttribute("formenctype")) || this.formElement.enctype);
    }
    get isSafe() {
      return this.fetchRequest.isSafe;
    }
    get stringFormData() {
      return [...this.formData].reduce((entries, [name, value]) => {
        return entries.concat(typeof value == "string" ? [[name, value]] : []);
      }, []);
    }
    async start() {
      const { initialized, requesting } = FormSubmissionState;
      const confirmationMessage = getAttribute("data-turbo-confirm", this.submitter, this.formElement);
      if (typeof confirmationMessage === "string") {
        const answer = await FormSubmission.confirmMethod(confirmationMessage, this.formElement, this.submitter);
        if (!answer) {
          return;
        }
      }
      if (this.state == initialized) {
        this.state = requesting;
        return this.fetchRequest.perform();
      }
    }
    stop() {
      const { stopping, stopped } = FormSubmissionState;
      if (this.state != stopping && this.state != stopped) {
        this.state = stopping;
        this.fetchRequest.cancel();
        return true;
      }
    }
    prepareRequest(request) {
      if (!request.isSafe) {
        const token = getCookieValue(getMetaContent("csrf-param")) || getMetaContent("csrf-token");
        if (token) {
          request.headers["X-CSRF-Token"] = token;
        }
      }
      if (this.requestAcceptsTurboStreamResponse(request)) {
        request.acceptResponseType(StreamMessage.contentType);
      }
    }
    requestStarted(_request) {
      var _a;
      this.state = FormSubmissionState.waiting;
      (_a = this.submitter) === null || _a === void 0 ? void 0 : _a.setAttribute("disabled", "");
      this.setSubmitsWith();
      dispatch("turbo:submit-start", {
        target: this.formElement,
        detail: { formSubmission: this }
      });
      this.delegate.formSubmissionStarted(this);
    }
    requestPreventedHandlingResponse(request, response) {
      this.result = { success: response.succeeded, fetchResponse: response };
    }
    requestSucceededWithResponse(request, response) {
      if (response.clientError || response.serverError) {
        this.delegate.formSubmissionFailedWithResponse(this, response);
      } else if (this.requestMustRedirect(request) && responseSucceededWithoutRedirect(response)) {
        const error2 = new Error("Form responses must redirect to another location");
        this.delegate.formSubmissionErrored(this, error2);
      } else {
        this.state = FormSubmissionState.receiving;
        this.result = { success: true, fetchResponse: response };
        this.delegate.formSubmissionSucceededWithResponse(this, response);
      }
    }
    requestFailedWithResponse(request, response) {
      this.result = { success: false, fetchResponse: response };
      this.delegate.formSubmissionFailedWithResponse(this, response);
    }
    requestErrored(request, error2) {
      this.result = { success: false, error: error2 };
      this.delegate.formSubmissionErrored(this, error2);
    }
    requestFinished(_request) {
      var _a;
      this.state = FormSubmissionState.stopped;
      (_a = this.submitter) === null || _a === void 0 ? void 0 : _a.removeAttribute("disabled");
      this.resetSubmitterText();
      dispatch("turbo:submit-end", {
        target: this.formElement,
        detail: Object.assign({ formSubmission: this }, this.result)
      });
      this.delegate.formSubmissionFinished(this);
    }
    setSubmitsWith() {
      if (!this.submitter || !this.submitsWith)
        return;
      if (this.submitter.matches("button")) {
        this.originalSubmitText = this.submitter.innerHTML;
        this.submitter.innerHTML = this.submitsWith;
      } else if (this.submitter.matches("input")) {
        const input = this.submitter;
        this.originalSubmitText = input.value;
        input.value = this.submitsWith;
      }
    }
    resetSubmitterText() {
      if (!this.submitter || !this.originalSubmitText)
        return;
      if (this.submitter.matches("button")) {
        this.submitter.innerHTML = this.originalSubmitText;
      } else if (this.submitter.matches("input")) {
        const input = this.submitter;
        input.value = this.originalSubmitText;
      }
    }
    requestMustRedirect(request) {
      return !request.isSafe && this.mustRedirect;
    }
    requestAcceptsTurboStreamResponse(request) {
      return !request.isSafe || hasAttribute("data-turbo-stream", this.submitter, this.formElement);
    }
    get submitsWith() {
      var _a;
      return (_a = this.submitter) === null || _a === void 0 ? void 0 : _a.getAttribute("data-turbo-submits-with");
    }
  };
  function buildFormData(formElement, submitter) {
    const formData = new FormData(formElement);
    const name = submitter === null || submitter === void 0 ? void 0 : submitter.getAttribute("name");
    const value = submitter === null || submitter === void 0 ? void 0 : submitter.getAttribute("value");
    if (name) {
      formData.append(name, value || "");
    }
    return formData;
  }
  function getCookieValue(cookieName) {
    if (cookieName != null) {
      const cookies = document.cookie ? document.cookie.split("; ") : [];
      const cookie = cookies.find((cookie2) => cookie2.startsWith(cookieName));
      if (cookie) {
        const value = cookie.split("=").slice(1).join("=");
        return value ? decodeURIComponent(value) : void 0;
      }
    }
  }
  function responseSucceededWithoutRedirect(response) {
    return response.statusCode == 200 && !response.redirected;
  }
  function mergeFormDataEntries(url, entries) {
    const searchParams = new URLSearchParams();
    for (const [name, value] of entries) {
      if (value instanceof File)
        continue;
      searchParams.append(name, value);
    }
    url.search = searchParams.toString();
    return url;
  }
  var Snapshot = class {
    constructor(element) {
      this.element = element;
    }
    get activeElement() {
      return this.element.ownerDocument.activeElement;
    }
    get children() {
      return [...this.element.children];
    }
    hasAnchor(anchor) {
      return this.getElementForAnchor(anchor) != null;
    }
    getElementForAnchor(anchor) {
      return anchor ? this.element.querySelector(`[id='${anchor}'], a[name='${anchor}']`) : null;
    }
    get isConnected() {
      return this.element.isConnected;
    }
    get firstAutofocusableElement() {
      const inertDisabledOrHidden = "[inert], :disabled, [hidden], details:not([open]), dialog:not([open])";
      for (const element of this.element.querySelectorAll("[autofocus]")) {
        if (element.closest(inertDisabledOrHidden) == null)
          return element;
        else
          continue;
      }
      return null;
    }
    get permanentElements() {
      return queryPermanentElementsAll(this.element);
    }
    getPermanentElementById(id) {
      return getPermanentElementById(this.element, id);
    }
    getPermanentElementMapForSnapshot(snapshot) {
      const permanentElementMap = {};
      for (const currentPermanentElement of this.permanentElements) {
        const { id } = currentPermanentElement;
        const newPermanentElement = snapshot.getPermanentElementById(id);
        if (newPermanentElement) {
          permanentElementMap[id] = [currentPermanentElement, newPermanentElement];
        }
      }
      return permanentElementMap;
    }
  };
  function getPermanentElementById(node, id) {
    return node.querySelector(`#${id}[data-turbo-permanent]`);
  }
  function queryPermanentElementsAll(node) {
    return node.querySelectorAll("[id][data-turbo-permanent]");
  }
  var FormSubmitObserver = class {
    constructor(delegate, eventTarget) {
      this.started = false;
      this.submitCaptured = () => {
        this.eventTarget.removeEventListener("submit", this.submitBubbled, false);
        this.eventTarget.addEventListener("submit", this.submitBubbled, false);
      };
      this.submitBubbled = (event) => {
        if (!event.defaultPrevented) {
          const form = event.target instanceof HTMLFormElement ? event.target : void 0;
          const submitter = event.submitter || void 0;
          if (form && submissionDoesNotDismissDialog(form, submitter) && submissionDoesNotTargetIFrame(form, submitter) && this.delegate.willSubmitForm(form, submitter)) {
            event.preventDefault();
            event.stopImmediatePropagation();
            this.delegate.formSubmitted(form, submitter);
          }
        }
      };
      this.delegate = delegate;
      this.eventTarget = eventTarget;
    }
    start() {
      if (!this.started) {
        this.eventTarget.addEventListener("submit", this.submitCaptured, true);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        this.eventTarget.removeEventListener("submit", this.submitCaptured, true);
        this.started = false;
      }
    }
  };
  function submissionDoesNotDismissDialog(form, submitter) {
    const method = (submitter === null || submitter === void 0 ? void 0 : submitter.getAttribute("formmethod")) || form.getAttribute("method");
    return method != "dialog";
  }
  function submissionDoesNotTargetIFrame(form, submitter) {
    if ((submitter === null || submitter === void 0 ? void 0 : submitter.hasAttribute("formtarget")) || form.hasAttribute("target")) {
      const target = (submitter === null || submitter === void 0 ? void 0 : submitter.getAttribute("formtarget")) || form.target;
      for (const element of document.getElementsByName(target)) {
        if (element instanceof HTMLIFrameElement)
          return false;
      }
      return true;
    } else {
      return true;
    }
  }
  var View = class {
    constructor(delegate, element) {
      this.resolveRenderPromise = (_value) => {
      };
      this.resolveInterceptionPromise = (_value) => {
      };
      this.delegate = delegate;
      this.element = element;
    }
    scrollToAnchor(anchor) {
      const element = this.snapshot.getElementForAnchor(anchor);
      if (element) {
        this.scrollToElement(element);
        this.focusElement(element);
      } else {
        this.scrollToPosition({ x: 0, y: 0 });
      }
    }
    scrollToAnchorFromLocation(location2) {
      this.scrollToAnchor(getAnchor(location2));
    }
    scrollToElement(element) {
      element.scrollIntoView();
    }
    focusElement(element) {
      if (element instanceof HTMLElement) {
        if (element.hasAttribute("tabindex")) {
          element.focus();
        } else {
          element.setAttribute("tabindex", "-1");
          element.focus();
          element.removeAttribute("tabindex");
        }
      }
    }
    scrollToPosition({ x, y }) {
      this.scrollRoot.scrollTo(x, y);
    }
    scrollToTop() {
      this.scrollToPosition({ x: 0, y: 0 });
    }
    get scrollRoot() {
      return window;
    }
    async render(renderer) {
      const { isPreview, shouldRender, newSnapshot: snapshot } = renderer;
      if (shouldRender) {
        try {
          this.renderPromise = new Promise((resolve) => this.resolveRenderPromise = resolve);
          this.renderer = renderer;
          await this.prepareToRenderSnapshot(renderer);
          const renderInterception = new Promise((resolve) => this.resolveInterceptionPromise = resolve);
          const options = { resume: this.resolveInterceptionPromise, render: this.renderer.renderElement };
          const immediateRender = this.delegate.allowsImmediateRender(snapshot, options);
          if (!immediateRender)
            await renderInterception;
          await this.renderSnapshot(renderer);
          this.delegate.viewRenderedSnapshot(snapshot, isPreview);
          this.delegate.preloadOnLoadLinksForView(this.element);
          this.finishRenderingSnapshot(renderer);
        } finally {
          delete this.renderer;
          this.resolveRenderPromise(void 0);
          delete this.renderPromise;
        }
      } else {
        this.invalidate(renderer.reloadReason);
      }
    }
    invalidate(reason) {
      this.delegate.viewInvalidated(reason);
    }
    async prepareToRenderSnapshot(renderer) {
      this.markAsPreview(renderer.isPreview);
      await renderer.prepareToRender();
    }
    markAsPreview(isPreview) {
      if (isPreview) {
        this.element.setAttribute("data-turbo-preview", "");
      } else {
        this.element.removeAttribute("data-turbo-preview");
      }
    }
    async renderSnapshot(renderer) {
      await renderer.render();
    }
    finishRenderingSnapshot(renderer) {
      renderer.finishRendering();
    }
  };
  var FrameView = class extends View {
    missing() {
      this.element.innerHTML = `<strong class="turbo-frame-error">Content missing</strong>`;
    }
    get snapshot() {
      return new Snapshot(this.element);
    }
  };
  var LinkInterceptor = class {
    constructor(delegate, element) {
      this.clickBubbled = (event) => {
        if (this.respondsToEventTarget(event.target)) {
          this.clickEvent = event;
        } else {
          delete this.clickEvent;
        }
      };
      this.linkClicked = (event) => {
        if (this.clickEvent && this.respondsToEventTarget(event.target) && event.target instanceof Element) {
          if (this.delegate.shouldInterceptLinkClick(event.target, event.detail.url, event.detail.originalEvent)) {
            this.clickEvent.preventDefault();
            event.preventDefault();
            this.delegate.linkClickIntercepted(event.target, event.detail.url, event.detail.originalEvent);
          }
        }
        delete this.clickEvent;
      };
      this.willVisit = (_event) => {
        delete this.clickEvent;
      };
      this.delegate = delegate;
      this.element = element;
    }
    start() {
      this.element.addEventListener("click", this.clickBubbled);
      document.addEventListener("turbo:click", this.linkClicked);
      document.addEventListener("turbo:before-visit", this.willVisit);
    }
    stop() {
      this.element.removeEventListener("click", this.clickBubbled);
      document.removeEventListener("turbo:click", this.linkClicked);
      document.removeEventListener("turbo:before-visit", this.willVisit);
    }
    respondsToEventTarget(target) {
      const element = target instanceof Element ? target : target instanceof Node ? target.parentElement : null;
      return element && element.closest("turbo-frame, html") == this.element;
    }
  };
  var LinkClickObserver = class {
    constructor(delegate, eventTarget) {
      this.started = false;
      this.clickCaptured = () => {
        this.eventTarget.removeEventListener("click", this.clickBubbled, false);
        this.eventTarget.addEventListener("click", this.clickBubbled, false);
      };
      this.clickBubbled = (event) => {
        if (event instanceof MouseEvent && this.clickEventIsSignificant(event)) {
          const target = event.composedPath && event.composedPath()[0] || event.target;
          const link = this.findLinkFromClickTarget(target);
          if (link && doesNotTargetIFrame(link)) {
            const location2 = this.getLocationForLink(link);
            if (this.delegate.willFollowLinkToLocation(link, location2, event)) {
              event.preventDefault();
              this.delegate.followedLinkToLocation(link, location2);
            }
          }
        }
      };
      this.delegate = delegate;
      this.eventTarget = eventTarget;
    }
    start() {
      if (!this.started) {
        this.eventTarget.addEventListener("click", this.clickCaptured, true);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        this.eventTarget.removeEventListener("click", this.clickCaptured, true);
        this.started = false;
      }
    }
    clickEventIsSignificant(event) {
      return !(event.target && event.target.isContentEditable || event.defaultPrevented || event.which > 1 || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey);
    }
    findLinkFromClickTarget(target) {
      return findClosestRecursively(target, "a[href]:not([target^=_]):not([download])");
    }
    getLocationForLink(link) {
      return expandURL(link.getAttribute("href") || "");
    }
  };
  function doesNotTargetIFrame(anchor) {
    if (anchor.hasAttribute("target")) {
      for (const element of document.getElementsByName(anchor.target)) {
        if (element instanceof HTMLIFrameElement)
          return false;
      }
      return true;
    } else {
      return true;
    }
  }
  var FormLinkClickObserver = class {
    constructor(delegate, element) {
      this.delegate = delegate;
      this.linkInterceptor = new LinkClickObserver(this, element);
    }
    start() {
      this.linkInterceptor.start();
    }
    stop() {
      this.linkInterceptor.stop();
    }
    willFollowLinkToLocation(link, location2, originalEvent) {
      return this.delegate.willSubmitFormLinkToLocation(link, location2, originalEvent) && link.hasAttribute("data-turbo-method");
    }
    followedLinkToLocation(link, location2) {
      const form = document.createElement("form");
      const type = "hidden";
      for (const [name, value] of location2.searchParams) {
        form.append(Object.assign(document.createElement("input"), { type, name, value }));
      }
      const action = Object.assign(location2, { search: "" });
      form.setAttribute("data-turbo", "true");
      form.setAttribute("action", action.href);
      form.setAttribute("hidden", "");
      const method = link.getAttribute("data-turbo-method");
      if (method)
        form.setAttribute("method", method);
      const turboFrame = link.getAttribute("data-turbo-frame");
      if (turboFrame)
        form.setAttribute("data-turbo-frame", turboFrame);
      const turboAction = getVisitAction(link);
      if (turboAction)
        form.setAttribute("data-turbo-action", turboAction);
      const turboConfirm = link.getAttribute("data-turbo-confirm");
      if (turboConfirm)
        form.setAttribute("data-turbo-confirm", turboConfirm);
      const turboStream = link.hasAttribute("data-turbo-stream");
      if (turboStream)
        form.setAttribute("data-turbo-stream", "");
      this.delegate.submittedFormLinkToLocation(link, location2, form);
      document.body.appendChild(form);
      form.addEventListener("turbo:submit-end", () => form.remove(), { once: true });
      requestAnimationFrame(() => form.requestSubmit());
    }
  };
  var Bardo = class {
    static async preservingPermanentElements(delegate, permanentElementMap, callback) {
      const bardo = new this(delegate, permanentElementMap);
      bardo.enter();
      await callback();
      bardo.leave();
    }
    constructor(delegate, permanentElementMap) {
      this.delegate = delegate;
      this.permanentElementMap = permanentElementMap;
    }
    enter() {
      for (const id in this.permanentElementMap) {
        const [currentPermanentElement, newPermanentElement] = this.permanentElementMap[id];
        this.delegate.enteringBardo(currentPermanentElement, newPermanentElement);
        this.replaceNewPermanentElementWithPlaceholder(newPermanentElement);
      }
    }
    leave() {
      for (const id in this.permanentElementMap) {
        const [currentPermanentElement] = this.permanentElementMap[id];
        this.replaceCurrentPermanentElementWithClone(currentPermanentElement);
        this.replacePlaceholderWithPermanentElement(currentPermanentElement);
        this.delegate.leavingBardo(currentPermanentElement);
      }
    }
    replaceNewPermanentElementWithPlaceholder(permanentElement) {
      const placeholder = createPlaceholderForPermanentElement(permanentElement);
      permanentElement.replaceWith(placeholder);
    }
    replaceCurrentPermanentElementWithClone(permanentElement) {
      const clone = permanentElement.cloneNode(true);
      permanentElement.replaceWith(clone);
    }
    replacePlaceholderWithPermanentElement(permanentElement) {
      const placeholder = this.getPlaceholderById(permanentElement.id);
      placeholder === null || placeholder === void 0 ? void 0 : placeholder.replaceWith(permanentElement);
    }
    getPlaceholderById(id) {
      return this.placeholders.find((element) => element.content == id);
    }
    get placeholders() {
      return [...document.querySelectorAll("meta[name=turbo-permanent-placeholder][content]")];
    }
  };
  function createPlaceholderForPermanentElement(permanentElement) {
    const element = document.createElement("meta");
    element.setAttribute("name", "turbo-permanent-placeholder");
    element.setAttribute("content", permanentElement.id);
    return element;
  }
  var Renderer = class {
    constructor(currentSnapshot, newSnapshot, renderElement, isPreview, willRender = true) {
      this.activeElement = null;
      this.currentSnapshot = currentSnapshot;
      this.newSnapshot = newSnapshot;
      this.isPreview = isPreview;
      this.willRender = willRender;
      this.renderElement = renderElement;
      this.promise = new Promise((resolve, reject) => this.resolvingFunctions = { resolve, reject });
    }
    get shouldRender() {
      return true;
    }
    get reloadReason() {
      return;
    }
    prepareToRender() {
      return;
    }
    finishRendering() {
      if (this.resolvingFunctions) {
        this.resolvingFunctions.resolve();
        delete this.resolvingFunctions;
      }
    }
    async preservingPermanentElements(callback) {
      await Bardo.preservingPermanentElements(this, this.permanentElementMap, callback);
    }
    focusFirstAutofocusableElement() {
      const element = this.connectedSnapshot.firstAutofocusableElement;
      if (elementIsFocusable(element)) {
        element.focus();
      }
    }
    enteringBardo(currentPermanentElement) {
      if (this.activeElement)
        return;
      if (currentPermanentElement.contains(this.currentSnapshot.activeElement)) {
        this.activeElement = this.currentSnapshot.activeElement;
      }
    }
    leavingBardo(currentPermanentElement) {
      if (currentPermanentElement.contains(this.activeElement) && this.activeElement instanceof HTMLElement) {
        this.activeElement.focus();
        this.activeElement = null;
      }
    }
    get connectedSnapshot() {
      return this.newSnapshot.isConnected ? this.newSnapshot : this.currentSnapshot;
    }
    get currentElement() {
      return this.currentSnapshot.element;
    }
    get newElement() {
      return this.newSnapshot.element;
    }
    get permanentElementMap() {
      return this.currentSnapshot.getPermanentElementMapForSnapshot(this.newSnapshot);
    }
  };
  function elementIsFocusable(element) {
    return element && typeof element.focus == "function";
  }
  var FrameRenderer = class extends Renderer {
    static renderElement(currentElement, newElement) {
      var _a;
      const destinationRange = document.createRange();
      destinationRange.selectNodeContents(currentElement);
      destinationRange.deleteContents();
      const frameElement = newElement;
      const sourceRange = (_a = frameElement.ownerDocument) === null || _a === void 0 ? void 0 : _a.createRange();
      if (sourceRange) {
        sourceRange.selectNodeContents(frameElement);
        currentElement.appendChild(sourceRange.extractContents());
      }
    }
    constructor(delegate, currentSnapshot, newSnapshot, renderElement, isPreview, willRender = true) {
      super(currentSnapshot, newSnapshot, renderElement, isPreview, willRender);
      this.delegate = delegate;
    }
    get shouldRender() {
      return true;
    }
    async render() {
      await nextAnimationFrame();
      this.preservingPermanentElements(() => {
        this.loadFrameElement();
      });
      this.scrollFrameIntoView();
      await nextAnimationFrame();
      this.focusFirstAutofocusableElement();
      await nextAnimationFrame();
      this.activateScriptElements();
    }
    loadFrameElement() {
      this.delegate.willRenderFrame(this.currentElement, this.newElement);
      this.renderElement(this.currentElement, this.newElement);
    }
    scrollFrameIntoView() {
      if (this.currentElement.autoscroll || this.newElement.autoscroll) {
        const element = this.currentElement.firstElementChild;
        const block = readScrollLogicalPosition(this.currentElement.getAttribute("data-autoscroll-block"), "end");
        const behavior = readScrollBehavior(this.currentElement.getAttribute("data-autoscroll-behavior"), "auto");
        if (element) {
          element.scrollIntoView({ block, behavior });
          return true;
        }
      }
      return false;
    }
    activateScriptElements() {
      for (const inertScriptElement of this.newScriptElements) {
        const activatedScriptElement = activateScriptElement(inertScriptElement);
        inertScriptElement.replaceWith(activatedScriptElement);
      }
    }
    get newScriptElements() {
      return this.currentElement.querySelectorAll("script");
    }
  };
  function readScrollLogicalPosition(value, defaultValue) {
    if (value == "end" || value == "start" || value == "center" || value == "nearest") {
      return value;
    } else {
      return defaultValue;
    }
  }
  function readScrollBehavior(value, defaultValue) {
    if (value == "auto" || value == "smooth") {
      return value;
    } else {
      return defaultValue;
    }
  }
  var ProgressBar = class {
    static get defaultCSS() {
      return unindent`
      .turbo-progress-bar {
        position: fixed;
        display: block;
        top: 0;
        left: 0;
        height: 3px;
        background: #0076ff;
        z-index: 2147483647;
        transition:
          width ${ProgressBar.animationDuration}ms ease-out,
          opacity ${ProgressBar.animationDuration / 2}ms ${ProgressBar.animationDuration / 2}ms ease-in;
        transform: translate3d(0, 0, 0);
      }
    `;
    }
    constructor() {
      this.hiding = false;
      this.value = 0;
      this.visible = false;
      this.trickle = () => {
        this.setValue(this.value + Math.random() / 100);
      };
      this.stylesheetElement = this.createStylesheetElement();
      this.progressElement = this.createProgressElement();
      this.installStylesheetElement();
      this.setValue(0);
    }
    show() {
      if (!this.visible) {
        this.visible = true;
        this.installProgressElement();
        this.startTrickling();
      }
    }
    hide() {
      if (this.visible && !this.hiding) {
        this.hiding = true;
        this.fadeProgressElement(() => {
          this.uninstallProgressElement();
          this.stopTrickling();
          this.visible = false;
          this.hiding = false;
        });
      }
    }
    setValue(value) {
      this.value = value;
      this.refresh();
    }
    installStylesheetElement() {
      document.head.insertBefore(this.stylesheetElement, document.head.firstChild);
    }
    installProgressElement() {
      this.progressElement.style.width = "0";
      this.progressElement.style.opacity = "1";
      document.documentElement.insertBefore(this.progressElement, document.body);
      this.refresh();
    }
    fadeProgressElement(callback) {
      this.progressElement.style.opacity = "0";
      setTimeout(callback, ProgressBar.animationDuration * 1.5);
    }
    uninstallProgressElement() {
      if (this.progressElement.parentNode) {
        document.documentElement.removeChild(this.progressElement);
      }
    }
    startTrickling() {
      if (!this.trickleInterval) {
        this.trickleInterval = window.setInterval(this.trickle, ProgressBar.animationDuration);
      }
    }
    stopTrickling() {
      window.clearInterval(this.trickleInterval);
      delete this.trickleInterval;
    }
    refresh() {
      requestAnimationFrame(() => {
        this.progressElement.style.width = `${10 + this.value * 90}%`;
      });
    }
    createStylesheetElement() {
      const element = document.createElement("style");
      element.type = "text/css";
      element.textContent = ProgressBar.defaultCSS;
      if (this.cspNonce) {
        element.nonce = this.cspNonce;
      }
      return element;
    }
    createProgressElement() {
      const element = document.createElement("div");
      element.className = "turbo-progress-bar";
      return element;
    }
    get cspNonce() {
      return getMetaContent("csp-nonce");
    }
  };
  ProgressBar.animationDuration = 300;
  var HeadSnapshot = class extends Snapshot {
    constructor() {
      super(...arguments);
      this.detailsByOuterHTML = this.children.filter((element) => !elementIsNoscript(element)).map((element) => elementWithoutNonce(element)).reduce((result, element) => {
        const { outerHTML } = element;
        const details = outerHTML in result ? result[outerHTML] : {
          type: elementType(element),
          tracked: elementIsTracked(element),
          elements: []
        };
        return Object.assign(Object.assign({}, result), { [outerHTML]: Object.assign(Object.assign({}, details), { elements: [...details.elements, element] }) });
      }, {});
    }
    get trackedElementSignature() {
      return Object.keys(this.detailsByOuterHTML).filter((outerHTML) => this.detailsByOuterHTML[outerHTML].tracked).join("");
    }
    getScriptElementsNotInSnapshot(snapshot) {
      return this.getElementsMatchingTypeNotInSnapshot("script", snapshot);
    }
    getStylesheetElementsNotInSnapshot(snapshot) {
      return this.getElementsMatchingTypeNotInSnapshot("stylesheet", snapshot);
    }
    getElementsMatchingTypeNotInSnapshot(matchedType, snapshot) {
      return Object.keys(this.detailsByOuterHTML).filter((outerHTML) => !(outerHTML in snapshot.detailsByOuterHTML)).map((outerHTML) => this.detailsByOuterHTML[outerHTML]).filter(({ type }) => type == matchedType).map(({ elements: [element] }) => element);
    }
    get provisionalElements() {
      return Object.keys(this.detailsByOuterHTML).reduce((result, outerHTML) => {
        const { type, tracked, elements } = this.detailsByOuterHTML[outerHTML];
        if (type == null && !tracked) {
          return [...result, ...elements];
        } else if (elements.length > 1) {
          return [...result, ...elements.slice(1)];
        } else {
          return result;
        }
      }, []);
    }
    getMetaValue(name) {
      const element = this.findMetaElementByName(name);
      return element ? element.getAttribute("content") : null;
    }
    findMetaElementByName(name) {
      return Object.keys(this.detailsByOuterHTML).reduce((result, outerHTML) => {
        const { elements: [element] } = this.detailsByOuterHTML[outerHTML];
        return elementIsMetaElementWithName(element, name) ? element : result;
      }, void 0);
    }
  };
  function elementType(element) {
    if (elementIsScript(element)) {
      return "script";
    } else if (elementIsStylesheet(element)) {
      return "stylesheet";
    }
  }
  function elementIsTracked(element) {
    return element.getAttribute("data-turbo-track") == "reload";
  }
  function elementIsScript(element) {
    const tagName = element.localName;
    return tagName == "script";
  }
  function elementIsNoscript(element) {
    const tagName = element.localName;
    return tagName == "noscript";
  }
  function elementIsStylesheet(element) {
    const tagName = element.localName;
    return tagName == "style" || tagName == "link" && element.getAttribute("rel") == "stylesheet";
  }
  function elementIsMetaElementWithName(element, name) {
    const tagName = element.localName;
    return tagName == "meta" && element.getAttribute("name") == name;
  }
  function elementWithoutNonce(element) {
    if (element.hasAttribute("nonce")) {
      element.setAttribute("nonce", "");
    }
    return element;
  }
  var PageSnapshot = class extends Snapshot {
    static fromHTMLString(html = "") {
      return this.fromDocument(parseHTMLDocument(html));
    }
    static fromElement(element) {
      return this.fromDocument(element.ownerDocument);
    }
    static fromDocument({ head, body }) {
      return new this(body, new HeadSnapshot(head));
    }
    constructor(element, headSnapshot) {
      super(element);
      this.headSnapshot = headSnapshot;
    }
    clone() {
      const clonedElement = this.element.cloneNode(true);
      const selectElements = this.element.querySelectorAll("select");
      const clonedSelectElements = clonedElement.querySelectorAll("select");
      for (const [index, source] of selectElements.entries()) {
        const clone = clonedSelectElements[index];
        for (const option of clone.selectedOptions)
          option.selected = false;
        for (const option of source.selectedOptions)
          clone.options[option.index].selected = true;
      }
      for (const clonedPasswordInput of clonedElement.querySelectorAll('input[type="password"]')) {
        clonedPasswordInput.value = "";
      }
      return new PageSnapshot(clonedElement, this.headSnapshot);
    }
    get headElement() {
      return this.headSnapshot.element;
    }
    get rootLocation() {
      var _a;
      const root = (_a = this.getSetting("root")) !== null && _a !== void 0 ? _a : "/";
      return expandURL(root);
    }
    get cacheControlValue() {
      return this.getSetting("cache-control");
    }
    get isPreviewable() {
      return this.cacheControlValue != "no-preview";
    }
    get isCacheable() {
      return this.cacheControlValue != "no-cache";
    }
    get isVisitable() {
      return this.getSetting("visit-control") != "reload";
    }
    getSetting(name) {
      return this.headSnapshot.getMetaValue(`turbo-${name}`);
    }
  };
  var TimingMetric;
  (function(TimingMetric2) {
    TimingMetric2["visitStart"] = "visitStart";
    TimingMetric2["requestStart"] = "requestStart";
    TimingMetric2["requestEnd"] = "requestEnd";
    TimingMetric2["visitEnd"] = "visitEnd";
  })(TimingMetric || (TimingMetric = {}));
  var VisitState;
  (function(VisitState2) {
    VisitState2["initialized"] = "initialized";
    VisitState2["started"] = "started";
    VisitState2["canceled"] = "canceled";
    VisitState2["failed"] = "failed";
    VisitState2["completed"] = "completed";
  })(VisitState || (VisitState = {}));
  var defaultOptions = {
    action: "advance",
    historyChanged: false,
    visitCachedSnapshot: () => {
    },
    willRender: true,
    updateHistory: true,
    shouldCacheSnapshot: true,
    acceptsStreamResponse: false
  };
  var SystemStatusCode;
  (function(SystemStatusCode2) {
    SystemStatusCode2[SystemStatusCode2["networkFailure"] = 0] = "networkFailure";
    SystemStatusCode2[SystemStatusCode2["timeoutFailure"] = -1] = "timeoutFailure";
    SystemStatusCode2[SystemStatusCode2["contentTypeMismatch"] = -2] = "contentTypeMismatch";
  })(SystemStatusCode || (SystemStatusCode = {}));
  var Visit = class {
    constructor(delegate, location2, restorationIdentifier, options = {}) {
      this.identifier = uuid();
      this.timingMetrics = {};
      this.followedRedirect = false;
      this.historyChanged = false;
      this.scrolled = false;
      this.shouldCacheSnapshot = true;
      this.acceptsStreamResponse = false;
      this.snapshotCached = false;
      this.state = VisitState.initialized;
      this.delegate = delegate;
      this.location = location2;
      this.restorationIdentifier = restorationIdentifier || uuid();
      const { action, historyChanged, referrer, snapshot, snapshotHTML, response, visitCachedSnapshot, willRender, updateHistory, shouldCacheSnapshot, acceptsStreamResponse } = Object.assign(Object.assign({}, defaultOptions), options);
      this.action = action;
      this.historyChanged = historyChanged;
      this.referrer = referrer;
      this.snapshot = snapshot;
      this.snapshotHTML = snapshotHTML;
      this.response = response;
      this.isSamePage = this.delegate.locationWithActionIsSamePage(this.location, this.action);
      this.visitCachedSnapshot = visitCachedSnapshot;
      this.willRender = willRender;
      this.updateHistory = updateHistory;
      this.scrolled = !willRender;
      this.shouldCacheSnapshot = shouldCacheSnapshot;
      this.acceptsStreamResponse = acceptsStreamResponse;
    }
    get adapter() {
      return this.delegate.adapter;
    }
    get view() {
      return this.delegate.view;
    }
    get history() {
      return this.delegate.history;
    }
    get restorationData() {
      return this.history.getRestorationDataForIdentifier(this.restorationIdentifier);
    }
    get silent() {
      return this.isSamePage;
    }
    start() {
      if (this.state == VisitState.initialized) {
        this.recordTimingMetric(TimingMetric.visitStart);
        this.state = VisitState.started;
        this.adapter.visitStarted(this);
        this.delegate.visitStarted(this);
      }
    }
    cancel() {
      if (this.state == VisitState.started) {
        if (this.request) {
          this.request.cancel();
        }
        this.cancelRender();
        this.state = VisitState.canceled;
      }
    }
    complete() {
      if (this.state == VisitState.started) {
        this.recordTimingMetric(TimingMetric.visitEnd);
        this.state = VisitState.completed;
        this.followRedirect();
        if (!this.followedRedirect) {
          this.adapter.visitCompleted(this);
          this.delegate.visitCompleted(this);
        }
      }
    }
    fail() {
      if (this.state == VisitState.started) {
        this.state = VisitState.failed;
        this.adapter.visitFailed(this);
      }
    }
    changeHistory() {
      var _a;
      if (!this.historyChanged && this.updateHistory) {
        const actionForHistory = this.location.href === ((_a = this.referrer) === null || _a === void 0 ? void 0 : _a.href) ? "replace" : this.action;
        const method = getHistoryMethodForAction(actionForHistory);
        this.history.update(method, this.location, this.restorationIdentifier);
        this.historyChanged = true;
      }
    }
    issueRequest() {
      if (this.hasPreloadedResponse()) {
        this.simulateRequest();
      } else if (this.shouldIssueRequest() && !this.request) {
        this.request = new FetchRequest(this, FetchMethod.get, this.location);
        this.request.perform();
      }
    }
    simulateRequest() {
      if (this.response) {
        this.startRequest();
        this.recordResponse();
        this.finishRequest();
      }
    }
    startRequest() {
      this.recordTimingMetric(TimingMetric.requestStart);
      this.adapter.visitRequestStarted(this);
    }
    recordResponse(response = this.response) {
      this.response = response;
      if (response) {
        const { statusCode } = response;
        if (isSuccessful(statusCode)) {
          this.adapter.visitRequestCompleted(this);
        } else {
          this.adapter.visitRequestFailedWithStatusCode(this, statusCode);
        }
      }
    }
    finishRequest() {
      this.recordTimingMetric(TimingMetric.requestEnd);
      this.adapter.visitRequestFinished(this);
    }
    loadResponse() {
      if (this.response) {
        const { statusCode, responseHTML } = this.response;
        this.render(async () => {
          if (this.shouldCacheSnapshot)
            this.cacheSnapshot();
          if (this.view.renderPromise)
            await this.view.renderPromise;
          if (isSuccessful(statusCode) && responseHTML != null) {
            await this.view.renderPage(PageSnapshot.fromHTMLString(responseHTML), false, this.willRender, this);
            this.performScroll();
            this.adapter.visitRendered(this);
            this.complete();
          } else {
            await this.view.renderError(PageSnapshot.fromHTMLString(responseHTML), this);
            this.adapter.visitRendered(this);
            this.fail();
          }
        });
      }
    }
    getCachedSnapshot() {
      const snapshot = this.view.getCachedSnapshotForLocation(this.location) || this.getPreloadedSnapshot();
      if (snapshot && (!getAnchor(this.location) || snapshot.hasAnchor(getAnchor(this.location)))) {
        if (this.action == "restore" || snapshot.isPreviewable) {
          return snapshot;
        }
      }
    }
    getPreloadedSnapshot() {
      if (this.snapshotHTML) {
        return PageSnapshot.fromHTMLString(this.snapshotHTML);
      }
    }
    hasCachedSnapshot() {
      return this.getCachedSnapshot() != null;
    }
    loadCachedSnapshot() {
      const snapshot = this.getCachedSnapshot();
      if (snapshot) {
        const isPreview = this.shouldIssueRequest();
        this.render(async () => {
          this.cacheSnapshot();
          if (this.isSamePage) {
            this.adapter.visitRendered(this);
          } else {
            if (this.view.renderPromise)
              await this.view.renderPromise;
            await this.view.renderPage(snapshot, isPreview, this.willRender, this);
            this.performScroll();
            this.adapter.visitRendered(this);
            if (!isPreview) {
              this.complete();
            }
          }
        });
      }
    }
    followRedirect() {
      var _a;
      if (this.redirectedToLocation && !this.followedRedirect && ((_a = this.response) === null || _a === void 0 ? void 0 : _a.redirected)) {
        this.adapter.visitProposedToLocation(this.redirectedToLocation, {
          action: "replace",
          response: this.response,
          shouldCacheSnapshot: false,
          willRender: false
        });
        this.followedRedirect = true;
      }
    }
    goToSamePageAnchor() {
      if (this.isSamePage) {
        this.render(async () => {
          this.cacheSnapshot();
          this.performScroll();
          this.changeHistory();
          this.adapter.visitRendered(this);
        });
      }
    }
    prepareRequest(request) {
      if (this.acceptsStreamResponse) {
        request.acceptResponseType(StreamMessage.contentType);
      }
    }
    requestStarted() {
      this.startRequest();
    }
    requestPreventedHandlingResponse(_request, _response) {
    }
    async requestSucceededWithResponse(request, response) {
      const responseHTML = await response.responseHTML;
      const { redirected, statusCode } = response;
      if (responseHTML == void 0) {
        this.recordResponse({
          statusCode: SystemStatusCode.contentTypeMismatch,
          redirected
        });
      } else {
        this.redirectedToLocation = response.redirected ? response.location : void 0;
        this.recordResponse({ statusCode, responseHTML, redirected });
      }
    }
    async requestFailedWithResponse(request, response) {
      const responseHTML = await response.responseHTML;
      const { redirected, statusCode } = response;
      if (responseHTML == void 0) {
        this.recordResponse({
          statusCode: SystemStatusCode.contentTypeMismatch,
          redirected
        });
      } else {
        this.recordResponse({ statusCode, responseHTML, redirected });
      }
    }
    requestErrored(_request, _error) {
      this.recordResponse({
        statusCode: SystemStatusCode.networkFailure,
        redirected: false
      });
    }
    requestFinished() {
      this.finishRequest();
    }
    performScroll() {
      if (!this.scrolled && !this.view.forceReloaded) {
        if (this.action == "restore") {
          this.scrollToRestoredPosition() || this.scrollToAnchor() || this.view.scrollToTop();
        } else {
          this.scrollToAnchor() || this.view.scrollToTop();
        }
        if (this.isSamePage) {
          this.delegate.visitScrolledToSamePageLocation(this.view.lastRenderedLocation, this.location);
        }
        this.scrolled = true;
      }
    }
    scrollToRestoredPosition() {
      const { scrollPosition } = this.restorationData;
      if (scrollPosition) {
        this.view.scrollToPosition(scrollPosition);
        return true;
      }
    }
    scrollToAnchor() {
      const anchor = getAnchor(this.location);
      if (anchor != null) {
        this.view.scrollToAnchor(anchor);
        return true;
      }
    }
    recordTimingMetric(metric) {
      this.timingMetrics[metric] = new Date().getTime();
    }
    getTimingMetrics() {
      return Object.assign({}, this.timingMetrics);
    }
    getHistoryMethodForAction(action) {
      switch (action) {
        case "replace":
          return history.replaceState;
        case "advance":
        case "restore":
          return history.pushState;
      }
    }
    hasPreloadedResponse() {
      return typeof this.response == "object";
    }
    shouldIssueRequest() {
      if (this.isSamePage) {
        return false;
      } else if (this.action == "restore") {
        return !this.hasCachedSnapshot();
      } else {
        return this.willRender;
      }
    }
    cacheSnapshot() {
      if (!this.snapshotCached) {
        this.view.cacheSnapshot(this.snapshot).then((snapshot) => snapshot && this.visitCachedSnapshot(snapshot));
        this.snapshotCached = true;
      }
    }
    async render(callback) {
      this.cancelRender();
      await new Promise((resolve) => {
        this.frame = requestAnimationFrame(() => resolve());
      });
      await callback();
      delete this.frame;
    }
    cancelRender() {
      if (this.frame) {
        cancelAnimationFrame(this.frame);
        delete this.frame;
      }
    }
  };
  function isSuccessful(statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }
  var BrowserAdapter = class {
    constructor(session2) {
      this.progressBar = new ProgressBar();
      this.showProgressBar = () => {
        this.progressBar.show();
      };
      this.session = session2;
    }
    visitProposedToLocation(location2, options) {
      this.navigator.startVisit(location2, (options === null || options === void 0 ? void 0 : options.restorationIdentifier) || uuid(), options);
    }
    visitStarted(visit2) {
      this.location = visit2.location;
      visit2.loadCachedSnapshot();
      visit2.issueRequest();
      visit2.goToSamePageAnchor();
    }
    visitRequestStarted(visit2) {
      this.progressBar.setValue(0);
      if (visit2.hasCachedSnapshot() || visit2.action != "restore") {
        this.showVisitProgressBarAfterDelay();
      } else {
        this.showProgressBar();
      }
    }
    visitRequestCompleted(visit2) {
      visit2.loadResponse();
    }
    visitRequestFailedWithStatusCode(visit2, statusCode) {
      switch (statusCode) {
        case SystemStatusCode.networkFailure:
        case SystemStatusCode.timeoutFailure:
        case SystemStatusCode.contentTypeMismatch:
          return this.reload({
            reason: "request_failed",
            context: {
              statusCode
            }
          });
        default:
          return visit2.loadResponse();
      }
    }
    visitRequestFinished(_visit) {
      this.progressBar.setValue(1);
      this.hideVisitProgressBar();
    }
    visitCompleted(_visit) {
    }
    pageInvalidated(reason) {
      this.reload(reason);
    }
    visitFailed(_visit) {
    }
    visitRendered(_visit) {
    }
    formSubmissionStarted(_formSubmission) {
      this.progressBar.setValue(0);
      this.showFormProgressBarAfterDelay();
    }
    formSubmissionFinished(_formSubmission) {
      this.progressBar.setValue(1);
      this.hideFormProgressBar();
    }
    showVisitProgressBarAfterDelay() {
      this.visitProgressBarTimeout = window.setTimeout(this.showProgressBar, this.session.progressBarDelay);
    }
    hideVisitProgressBar() {
      this.progressBar.hide();
      if (this.visitProgressBarTimeout != null) {
        window.clearTimeout(this.visitProgressBarTimeout);
        delete this.visitProgressBarTimeout;
      }
    }
    showFormProgressBarAfterDelay() {
      if (this.formProgressBarTimeout == null) {
        this.formProgressBarTimeout = window.setTimeout(this.showProgressBar, this.session.progressBarDelay);
      }
    }
    hideFormProgressBar() {
      this.progressBar.hide();
      if (this.formProgressBarTimeout != null) {
        window.clearTimeout(this.formProgressBarTimeout);
        delete this.formProgressBarTimeout;
      }
    }
    reload(reason) {
      var _a;
      dispatch("turbo:reload", { detail: reason });
      window.location.href = ((_a = this.location) === null || _a === void 0 ? void 0 : _a.toString()) || window.location.href;
    }
    get navigator() {
      return this.session.navigator;
    }
  };
  var CacheObserver = class {
    constructor() {
      this.selector = "[data-turbo-temporary]";
      this.deprecatedSelector = "[data-turbo-cache=false]";
      this.started = false;
      this.removeTemporaryElements = (_event) => {
        for (const element of this.temporaryElements) {
          element.remove();
        }
      };
    }
    start() {
      if (!this.started) {
        this.started = true;
        addEventListener("turbo:before-cache", this.removeTemporaryElements, false);
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        removeEventListener("turbo:before-cache", this.removeTemporaryElements, false);
      }
    }
    get temporaryElements() {
      return [...document.querySelectorAll(this.selector), ...this.temporaryElementsWithDeprecation];
    }
    get temporaryElementsWithDeprecation() {
      const elements = document.querySelectorAll(this.deprecatedSelector);
      if (elements.length) {
        console.warn(`The ${this.deprecatedSelector} selector is deprecated and will be removed in a future version. Use ${this.selector} instead.`);
      }
      return [...elements];
    }
  };
  var FrameRedirector = class {
    constructor(session2, element) {
      this.session = session2;
      this.element = element;
      this.linkInterceptor = new LinkInterceptor(this, element);
      this.formSubmitObserver = new FormSubmitObserver(this, element);
    }
    start() {
      this.linkInterceptor.start();
      this.formSubmitObserver.start();
    }
    stop() {
      this.linkInterceptor.stop();
      this.formSubmitObserver.stop();
    }
    shouldInterceptLinkClick(element, _location, _event) {
      return this.shouldRedirect(element);
    }
    linkClickIntercepted(element, url, event) {
      const frame = this.findFrameElement(element);
      if (frame) {
        frame.delegate.linkClickIntercepted(element, url, event);
      }
    }
    willSubmitForm(element, submitter) {
      return element.closest("turbo-frame") == null && this.shouldSubmit(element, submitter) && this.shouldRedirect(element, submitter);
    }
    formSubmitted(element, submitter) {
      const frame = this.findFrameElement(element, submitter);
      if (frame) {
        frame.delegate.formSubmitted(element, submitter);
      }
    }
    shouldSubmit(form, submitter) {
      var _a;
      const action = getAction(form, submitter);
      const meta = this.element.ownerDocument.querySelector(`meta[name="turbo-root"]`);
      const rootLocation = expandURL((_a = meta === null || meta === void 0 ? void 0 : meta.content) !== null && _a !== void 0 ? _a : "/");
      return this.shouldRedirect(form, submitter) && locationIsVisitable(action, rootLocation);
    }
    shouldRedirect(element, submitter) {
      const isNavigatable = element instanceof HTMLFormElement ? this.session.submissionIsNavigatable(element, submitter) : this.session.elementIsNavigatable(element);
      if (isNavigatable) {
        const frame = this.findFrameElement(element, submitter);
        return frame ? frame != element.closest("turbo-frame") : false;
      } else {
        return false;
      }
    }
    findFrameElement(element, submitter) {
      const id = (submitter === null || submitter === void 0 ? void 0 : submitter.getAttribute("data-turbo-frame")) || element.getAttribute("data-turbo-frame");
      if (id && id != "_top") {
        const frame = this.element.querySelector(`#${id}:not([disabled])`);
        if (frame instanceof FrameElement) {
          return frame;
        }
      }
    }
  };
  var History = class {
    constructor(delegate) {
      this.restorationIdentifier = uuid();
      this.restorationData = {};
      this.started = false;
      this.pageLoaded = false;
      this.onPopState = (event) => {
        if (this.shouldHandlePopState()) {
          const { turbo } = event.state || {};
          if (turbo) {
            this.location = new URL(window.location.href);
            const { restorationIdentifier } = turbo;
            this.restorationIdentifier = restorationIdentifier;
            this.delegate.historyPoppedToLocationWithRestorationIdentifier(this.location, restorationIdentifier);
          }
        }
      };
      this.onPageLoad = async (_event) => {
        await nextMicrotask();
        this.pageLoaded = true;
      };
      this.delegate = delegate;
    }
    start() {
      if (!this.started) {
        addEventListener("popstate", this.onPopState, false);
        addEventListener("load", this.onPageLoad, false);
        this.started = true;
        this.replace(new URL(window.location.href));
      }
    }
    stop() {
      if (this.started) {
        removeEventListener("popstate", this.onPopState, false);
        removeEventListener("load", this.onPageLoad, false);
        this.started = false;
      }
    }
    push(location2, restorationIdentifier) {
      this.update(history.pushState, location2, restorationIdentifier);
    }
    replace(location2, restorationIdentifier) {
      this.update(history.replaceState, location2, restorationIdentifier);
    }
    update(method, location2, restorationIdentifier = uuid()) {
      const state = { turbo: { restorationIdentifier } };
      method.call(history, state, "", location2.href);
      this.location = location2;
      this.restorationIdentifier = restorationIdentifier;
    }
    getRestorationDataForIdentifier(restorationIdentifier) {
      return this.restorationData[restorationIdentifier] || {};
    }
    updateRestorationData(additionalData) {
      const { restorationIdentifier } = this;
      const restorationData = this.restorationData[restorationIdentifier];
      this.restorationData[restorationIdentifier] = Object.assign(Object.assign({}, restorationData), additionalData);
    }
    assumeControlOfScrollRestoration() {
      var _a;
      if (!this.previousScrollRestoration) {
        this.previousScrollRestoration = (_a = history.scrollRestoration) !== null && _a !== void 0 ? _a : "auto";
        history.scrollRestoration = "manual";
      }
    }
    relinquishControlOfScrollRestoration() {
      if (this.previousScrollRestoration) {
        history.scrollRestoration = this.previousScrollRestoration;
        delete this.previousScrollRestoration;
      }
    }
    shouldHandlePopState() {
      return this.pageIsLoaded();
    }
    pageIsLoaded() {
      return this.pageLoaded || document.readyState == "complete";
    }
  };
  var Navigator = class {
    constructor(delegate) {
      this.delegate = delegate;
    }
    proposeVisit(location2, options = {}) {
      if (this.delegate.allowsVisitingLocationWithAction(location2, options.action)) {
        if (locationIsVisitable(location2, this.view.snapshot.rootLocation)) {
          this.delegate.visitProposedToLocation(location2, options);
        } else {
          window.location.href = location2.toString();
        }
      }
    }
    startVisit(locatable, restorationIdentifier, options = {}) {
      this.stop();
      this.currentVisit = new Visit(this, expandURL(locatable), restorationIdentifier, Object.assign({ referrer: this.location }, options));
      this.currentVisit.start();
    }
    submitForm(form, submitter) {
      this.stop();
      this.formSubmission = new FormSubmission(this, form, submitter, true);
      this.formSubmission.start();
    }
    stop() {
      if (this.formSubmission) {
        this.formSubmission.stop();
        delete this.formSubmission;
      }
      if (this.currentVisit) {
        this.currentVisit.cancel();
        delete this.currentVisit;
      }
    }
    get adapter() {
      return this.delegate.adapter;
    }
    get view() {
      return this.delegate.view;
    }
    get history() {
      return this.delegate.history;
    }
    formSubmissionStarted(formSubmission) {
      if (typeof this.adapter.formSubmissionStarted === "function") {
        this.adapter.formSubmissionStarted(formSubmission);
      }
    }
    async formSubmissionSucceededWithResponse(formSubmission, fetchResponse) {
      if (formSubmission == this.formSubmission) {
        const responseHTML = await fetchResponse.responseHTML;
        if (responseHTML) {
          const shouldCacheSnapshot = formSubmission.isSafe;
          if (!shouldCacheSnapshot) {
            this.view.clearSnapshotCache();
          }
          const { statusCode, redirected } = fetchResponse;
          const action = this.getActionForFormSubmission(formSubmission);
          const visitOptions = {
            action,
            shouldCacheSnapshot,
            response: { statusCode, responseHTML, redirected }
          };
          this.proposeVisit(fetchResponse.location, visitOptions);
        }
      }
    }
    async formSubmissionFailedWithResponse(formSubmission, fetchResponse) {
      const responseHTML = await fetchResponse.responseHTML;
      if (responseHTML) {
        const snapshot = PageSnapshot.fromHTMLString(responseHTML);
        if (fetchResponse.serverError) {
          await this.view.renderError(snapshot, this.currentVisit);
        } else {
          await this.view.renderPage(snapshot, false, true, this.currentVisit);
        }
        this.view.scrollToTop();
        this.view.clearSnapshotCache();
      }
    }
    formSubmissionErrored(formSubmission, error2) {
      console.error(error2);
    }
    formSubmissionFinished(formSubmission) {
      if (typeof this.adapter.formSubmissionFinished === "function") {
        this.adapter.formSubmissionFinished(formSubmission);
      }
    }
    visitStarted(visit2) {
      this.delegate.visitStarted(visit2);
    }
    visitCompleted(visit2) {
      this.delegate.visitCompleted(visit2);
    }
    locationWithActionIsSamePage(location2, action) {
      const anchor = getAnchor(location2);
      const currentAnchor = getAnchor(this.view.lastRenderedLocation);
      const isRestorationToTop = action === "restore" && typeof anchor === "undefined";
      return action !== "replace" && getRequestURL(location2) === getRequestURL(this.view.lastRenderedLocation) && (isRestorationToTop || anchor != null && anchor !== currentAnchor);
    }
    visitScrolledToSamePageLocation(oldURL, newURL) {
      this.delegate.visitScrolledToSamePageLocation(oldURL, newURL);
    }
    get location() {
      return this.history.location;
    }
    get restorationIdentifier() {
      return this.history.restorationIdentifier;
    }
    getActionForFormSubmission({ submitter, formElement }) {
      return getVisitAction(submitter, formElement) || "advance";
    }
  };
  var PageStage;
  (function(PageStage2) {
    PageStage2[PageStage2["initial"] = 0] = "initial";
    PageStage2[PageStage2["loading"] = 1] = "loading";
    PageStage2[PageStage2["interactive"] = 2] = "interactive";
    PageStage2[PageStage2["complete"] = 3] = "complete";
  })(PageStage || (PageStage = {}));
  var PageObserver = class {
    constructor(delegate) {
      this.stage = PageStage.initial;
      this.started = false;
      this.interpretReadyState = () => {
        const { readyState } = this;
        if (readyState == "interactive") {
          this.pageIsInteractive();
        } else if (readyState == "complete") {
          this.pageIsComplete();
        }
      };
      this.pageWillUnload = () => {
        this.delegate.pageWillUnload();
      };
      this.delegate = delegate;
    }
    start() {
      if (!this.started) {
        if (this.stage == PageStage.initial) {
          this.stage = PageStage.loading;
        }
        document.addEventListener("readystatechange", this.interpretReadyState, false);
        addEventListener("pagehide", this.pageWillUnload, false);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        document.removeEventListener("readystatechange", this.interpretReadyState, false);
        removeEventListener("pagehide", this.pageWillUnload, false);
        this.started = false;
      }
    }
    pageIsInteractive() {
      if (this.stage == PageStage.loading) {
        this.stage = PageStage.interactive;
        this.delegate.pageBecameInteractive();
      }
    }
    pageIsComplete() {
      this.pageIsInteractive();
      if (this.stage == PageStage.interactive) {
        this.stage = PageStage.complete;
        this.delegate.pageLoaded();
      }
    }
    get readyState() {
      return document.readyState;
    }
  };
  var ScrollObserver = class {
    constructor(delegate) {
      this.started = false;
      this.onScroll = () => {
        this.updatePosition({ x: window.pageXOffset, y: window.pageYOffset });
      };
      this.delegate = delegate;
    }
    start() {
      if (!this.started) {
        addEventListener("scroll", this.onScroll, false);
        this.onScroll();
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        removeEventListener("scroll", this.onScroll, false);
        this.started = false;
      }
    }
    updatePosition(position) {
      this.delegate.scrollPositionChanged(position);
    }
  };
  var StreamMessageRenderer = class {
    render({ fragment }) {
      Bardo.preservingPermanentElements(this, getPermanentElementMapForFragment(fragment), () => document.documentElement.appendChild(fragment));
    }
    enteringBardo(currentPermanentElement, newPermanentElement) {
      newPermanentElement.replaceWith(currentPermanentElement.cloneNode(true));
    }
    leavingBardo() {
    }
  };
  function getPermanentElementMapForFragment(fragment) {
    const permanentElementsInDocument = queryPermanentElementsAll(document.documentElement);
    const permanentElementMap = {};
    for (const permanentElementInDocument of permanentElementsInDocument) {
      const { id } = permanentElementInDocument;
      for (const streamElement of fragment.querySelectorAll("turbo-stream")) {
        const elementInStream = getPermanentElementById(streamElement.templateElement.content, id);
        if (elementInStream) {
          permanentElementMap[id] = [permanentElementInDocument, elementInStream];
        }
      }
    }
    return permanentElementMap;
  }
  var StreamObserver = class {
    constructor(delegate) {
      this.sources = /* @__PURE__ */ new Set();
      this.started = false;
      this.inspectFetchResponse = (event) => {
        const response = fetchResponseFromEvent(event);
        if (response && fetchResponseIsStream(response)) {
          event.preventDefault();
          this.receiveMessageResponse(response);
        }
      };
      this.receiveMessageEvent = (event) => {
        if (this.started && typeof event.data == "string") {
          this.receiveMessageHTML(event.data);
        }
      };
      this.delegate = delegate;
    }
    start() {
      if (!this.started) {
        this.started = true;
        addEventListener("turbo:before-fetch-response", this.inspectFetchResponse, false);
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        removeEventListener("turbo:before-fetch-response", this.inspectFetchResponse, false);
      }
    }
    connectStreamSource(source) {
      if (!this.streamSourceIsConnected(source)) {
        this.sources.add(source);
        source.addEventListener("message", this.receiveMessageEvent, false);
      }
    }
    disconnectStreamSource(source) {
      if (this.streamSourceIsConnected(source)) {
        this.sources.delete(source);
        source.removeEventListener("message", this.receiveMessageEvent, false);
      }
    }
    streamSourceIsConnected(source) {
      return this.sources.has(source);
    }
    async receiveMessageResponse(response) {
      const html = await response.responseHTML;
      if (html) {
        this.receiveMessageHTML(html);
      }
    }
    receiveMessageHTML(html) {
      this.delegate.receivedMessageFromStream(StreamMessage.wrap(html));
    }
  };
  function fetchResponseFromEvent(event) {
    var _a;
    const fetchResponse = (_a = event.detail) === null || _a === void 0 ? void 0 : _a.fetchResponse;
    if (fetchResponse instanceof FetchResponse) {
      return fetchResponse;
    }
  }
  function fetchResponseIsStream(response) {
    var _a;
    const contentType = (_a = response.contentType) !== null && _a !== void 0 ? _a : "";
    return contentType.startsWith(StreamMessage.contentType);
  }
  var ErrorRenderer = class extends Renderer {
    static renderElement(currentElement, newElement) {
      const { documentElement, body } = document;
      documentElement.replaceChild(newElement, body);
    }
    async render() {
      this.replaceHeadAndBody();
      this.activateScriptElements();
    }
    replaceHeadAndBody() {
      const { documentElement, head } = document;
      documentElement.replaceChild(this.newHead, head);
      this.renderElement(this.currentElement, this.newElement);
    }
    activateScriptElements() {
      for (const replaceableElement of this.scriptElements) {
        const parentNode = replaceableElement.parentNode;
        if (parentNode) {
          const element = activateScriptElement(replaceableElement);
          parentNode.replaceChild(element, replaceableElement);
        }
      }
    }
    get newHead() {
      return this.newSnapshot.headSnapshot.element;
    }
    get scriptElements() {
      return document.documentElement.querySelectorAll("script");
    }
  };
  var PageRenderer = class extends Renderer {
    static renderElement(currentElement, newElement) {
      if (document.body && newElement instanceof HTMLBodyElement) {
        document.body.replaceWith(newElement);
      } else {
        document.documentElement.appendChild(newElement);
      }
    }
    get shouldRender() {
      return this.newSnapshot.isVisitable && this.trackedElementsAreIdentical;
    }
    get reloadReason() {
      if (!this.newSnapshot.isVisitable) {
        return {
          reason: "turbo_visit_control_is_reload"
        };
      }
      if (!this.trackedElementsAreIdentical) {
        return {
          reason: "tracked_element_mismatch"
        };
      }
    }
    async prepareToRender() {
      await this.mergeHead();
    }
    async render() {
      if (this.willRender) {
        await this.replaceBody();
      }
    }
    finishRendering() {
      super.finishRendering();
      if (!this.isPreview) {
        this.focusFirstAutofocusableElement();
      }
    }
    get currentHeadSnapshot() {
      return this.currentSnapshot.headSnapshot;
    }
    get newHeadSnapshot() {
      return this.newSnapshot.headSnapshot;
    }
    get newElement() {
      return this.newSnapshot.element;
    }
    async mergeHead() {
      const mergedHeadElements = this.mergeProvisionalElements();
      const newStylesheetElements = this.copyNewHeadStylesheetElements();
      this.copyNewHeadScriptElements();
      await mergedHeadElements;
      await newStylesheetElements;
    }
    async replaceBody() {
      await this.preservingPermanentElements(async () => {
        this.activateNewBody();
        await this.assignNewBody();
      });
    }
    get trackedElementsAreIdentical() {
      return this.currentHeadSnapshot.trackedElementSignature == this.newHeadSnapshot.trackedElementSignature;
    }
    async copyNewHeadStylesheetElements() {
      const loadingElements = [];
      for (const element of this.newHeadStylesheetElements) {
        loadingElements.push(waitForLoad(element));
        document.head.appendChild(element);
      }
      await Promise.all(loadingElements);
    }
    copyNewHeadScriptElements() {
      for (const element of this.newHeadScriptElements) {
        document.head.appendChild(activateScriptElement(element));
      }
    }
    async mergeProvisionalElements() {
      const newHeadElements = [...this.newHeadProvisionalElements];
      for (const element of this.currentHeadProvisionalElements) {
        if (!this.isCurrentElementInElementList(element, newHeadElements)) {
          document.head.removeChild(element);
        }
      }
      for (const element of newHeadElements) {
        document.head.appendChild(element);
      }
    }
    isCurrentElementInElementList(element, elementList) {
      for (const [index, newElement] of elementList.entries()) {
        if (element.tagName == "TITLE") {
          if (newElement.tagName != "TITLE") {
            continue;
          }
          if (element.innerHTML == newElement.innerHTML) {
            elementList.splice(index, 1);
            return true;
          }
        }
        if (newElement.isEqualNode(element)) {
          elementList.splice(index, 1);
          return true;
        }
      }
      return false;
    }
    removeCurrentHeadProvisionalElements() {
      for (const element of this.currentHeadProvisionalElements) {
        document.head.removeChild(element);
      }
    }
    copyNewHeadProvisionalElements() {
      for (const element of this.newHeadProvisionalElements) {
        document.head.appendChild(element);
      }
    }
    activateNewBody() {
      document.adoptNode(this.newElement);
      this.activateNewBodyScriptElements();
    }
    activateNewBodyScriptElements() {
      for (const inertScriptElement of this.newBodyScriptElements) {
        const activatedScriptElement = activateScriptElement(inertScriptElement);
        inertScriptElement.replaceWith(activatedScriptElement);
      }
    }
    async assignNewBody() {
      await this.renderElement(this.currentElement, this.newElement);
    }
    get newHeadStylesheetElements() {
      return this.newHeadSnapshot.getStylesheetElementsNotInSnapshot(this.currentHeadSnapshot);
    }
    get newHeadScriptElements() {
      return this.newHeadSnapshot.getScriptElementsNotInSnapshot(this.currentHeadSnapshot);
    }
    get currentHeadProvisionalElements() {
      return this.currentHeadSnapshot.provisionalElements;
    }
    get newHeadProvisionalElements() {
      return this.newHeadSnapshot.provisionalElements;
    }
    get newBodyScriptElements() {
      return this.newElement.querySelectorAll("script");
    }
  };
  var SnapshotCache = class {
    constructor(size) {
      this.keys = [];
      this.snapshots = {};
      this.size = size;
    }
    has(location2) {
      return toCacheKey(location2) in this.snapshots;
    }
    get(location2) {
      if (this.has(location2)) {
        const snapshot = this.read(location2);
        this.touch(location2);
        return snapshot;
      }
    }
    put(location2, snapshot) {
      this.write(location2, snapshot);
      this.touch(location2);
      return snapshot;
    }
    clear() {
      this.snapshots = {};
    }
    read(location2) {
      return this.snapshots[toCacheKey(location2)];
    }
    write(location2, snapshot) {
      this.snapshots[toCacheKey(location2)] = snapshot;
    }
    touch(location2) {
      const key = toCacheKey(location2);
      const index = this.keys.indexOf(key);
      if (index > -1)
        this.keys.splice(index, 1);
      this.keys.unshift(key);
      this.trim();
    }
    trim() {
      for (const key of this.keys.splice(this.size)) {
        delete this.snapshots[key];
      }
    }
  };
  var PageView = class extends View {
    constructor() {
      super(...arguments);
      this.snapshotCache = new SnapshotCache(10);
      this.lastRenderedLocation = new URL(location.href);
      this.forceReloaded = false;
    }
    renderPage(snapshot, isPreview = false, willRender = true, visit2) {
      const renderer = new PageRenderer(this.snapshot, snapshot, PageRenderer.renderElement, isPreview, willRender);
      if (!renderer.shouldRender) {
        this.forceReloaded = true;
      } else {
        visit2 === null || visit2 === void 0 ? void 0 : visit2.changeHistory();
      }
      return this.render(renderer);
    }
    renderError(snapshot, visit2) {
      visit2 === null || visit2 === void 0 ? void 0 : visit2.changeHistory();
      const renderer = new ErrorRenderer(this.snapshot, snapshot, ErrorRenderer.renderElement, false);
      return this.render(renderer);
    }
    clearSnapshotCache() {
      this.snapshotCache.clear();
    }
    async cacheSnapshot(snapshot = this.snapshot) {
      if (snapshot.isCacheable) {
        this.delegate.viewWillCacheSnapshot();
        const { lastRenderedLocation: location2 } = this;
        await nextEventLoopTick();
        const cachedSnapshot = snapshot.clone();
        this.snapshotCache.put(location2, cachedSnapshot);
        return cachedSnapshot;
      }
    }
    getCachedSnapshotForLocation(location2) {
      return this.snapshotCache.get(location2);
    }
    get snapshot() {
      return PageSnapshot.fromElement(this.element);
    }
  };
  var Preloader = class {
    constructor(delegate) {
      this.selector = "a[data-turbo-preload]";
      this.delegate = delegate;
    }
    get snapshotCache() {
      return this.delegate.navigator.view.snapshotCache;
    }
    start() {
      if (document.readyState === "loading") {
        return document.addEventListener("DOMContentLoaded", () => {
          this.preloadOnLoadLinksForView(document.body);
        });
      } else {
        this.preloadOnLoadLinksForView(document.body);
      }
    }
    preloadOnLoadLinksForView(element) {
      for (const link of element.querySelectorAll(this.selector)) {
        this.preloadURL(link);
      }
    }
    async preloadURL(link) {
      const location2 = new URL(link.href);
      if (this.snapshotCache.has(location2)) {
        return;
      }
      try {
        const response = await fetch(location2.toString(), { headers: { "VND.PREFETCH": "true", Accept: "text/html" } });
        const responseText = await response.text();
        const snapshot = PageSnapshot.fromHTMLString(responseText);
        this.snapshotCache.put(location2, snapshot);
      } catch (_) {
      }
    }
  };
  var Session = class {
    constructor() {
      this.navigator = new Navigator(this);
      this.history = new History(this);
      this.preloader = new Preloader(this);
      this.view = new PageView(this, document.documentElement);
      this.adapter = new BrowserAdapter(this);
      this.pageObserver = new PageObserver(this);
      this.cacheObserver = new CacheObserver();
      this.linkClickObserver = new LinkClickObserver(this, window);
      this.formSubmitObserver = new FormSubmitObserver(this, document);
      this.scrollObserver = new ScrollObserver(this);
      this.streamObserver = new StreamObserver(this);
      this.formLinkClickObserver = new FormLinkClickObserver(this, document.documentElement);
      this.frameRedirector = new FrameRedirector(this, document.documentElement);
      this.streamMessageRenderer = new StreamMessageRenderer();
      this.drive = true;
      this.enabled = true;
      this.progressBarDelay = 500;
      this.started = false;
      this.formMode = "on";
    }
    start() {
      if (!this.started) {
        this.pageObserver.start();
        this.cacheObserver.start();
        this.formLinkClickObserver.start();
        this.linkClickObserver.start();
        this.formSubmitObserver.start();
        this.scrollObserver.start();
        this.streamObserver.start();
        this.frameRedirector.start();
        this.history.start();
        this.preloader.start();
        this.started = true;
        this.enabled = true;
      }
    }
    disable() {
      this.enabled = false;
    }
    stop() {
      if (this.started) {
        this.pageObserver.stop();
        this.cacheObserver.stop();
        this.formLinkClickObserver.stop();
        this.linkClickObserver.stop();
        this.formSubmitObserver.stop();
        this.scrollObserver.stop();
        this.streamObserver.stop();
        this.frameRedirector.stop();
        this.history.stop();
        this.started = false;
      }
    }
    registerAdapter(adapter) {
      this.adapter = adapter;
    }
    visit(location2, options = {}) {
      const frameElement = options.frame ? document.getElementById(options.frame) : null;
      if (frameElement instanceof FrameElement) {
        frameElement.src = location2.toString();
        frameElement.loaded;
      } else {
        this.navigator.proposeVisit(expandURL(location2), options);
      }
    }
    connectStreamSource(source) {
      this.streamObserver.connectStreamSource(source);
    }
    disconnectStreamSource(source) {
      this.streamObserver.disconnectStreamSource(source);
    }
    renderStreamMessage(message) {
      this.streamMessageRenderer.render(StreamMessage.wrap(message));
    }
    clearCache() {
      this.view.clearSnapshotCache();
    }
    setProgressBarDelay(delay) {
      this.progressBarDelay = delay;
    }
    setFormMode(mode) {
      this.formMode = mode;
    }
    get location() {
      return this.history.location;
    }
    get restorationIdentifier() {
      return this.history.restorationIdentifier;
    }
    historyPoppedToLocationWithRestorationIdentifier(location2, restorationIdentifier) {
      if (this.enabled) {
        this.navigator.startVisit(location2, restorationIdentifier, {
          action: "restore",
          historyChanged: true
        });
      } else {
        this.adapter.pageInvalidated({
          reason: "turbo_disabled"
        });
      }
    }
    scrollPositionChanged(position) {
      this.history.updateRestorationData({ scrollPosition: position });
    }
    willSubmitFormLinkToLocation(link, location2) {
      return this.elementIsNavigatable(link) && locationIsVisitable(location2, this.snapshot.rootLocation);
    }
    submittedFormLinkToLocation() {
    }
    willFollowLinkToLocation(link, location2, event) {
      return this.elementIsNavigatable(link) && locationIsVisitable(location2, this.snapshot.rootLocation) && this.applicationAllowsFollowingLinkToLocation(link, location2, event);
    }
    followedLinkToLocation(link, location2) {
      const action = this.getActionForLink(link);
      const acceptsStreamResponse = link.hasAttribute("data-turbo-stream");
      this.visit(location2.href, { action, acceptsStreamResponse });
    }
    allowsVisitingLocationWithAction(location2, action) {
      return this.locationWithActionIsSamePage(location2, action) || this.applicationAllowsVisitingLocation(location2);
    }
    visitProposedToLocation(location2, options) {
      extendURLWithDeprecatedProperties(location2);
      this.adapter.visitProposedToLocation(location2, options);
    }
    visitStarted(visit2) {
      if (!visit2.acceptsStreamResponse) {
        markAsBusy(document.documentElement);
      }
      extendURLWithDeprecatedProperties(visit2.location);
      if (!visit2.silent) {
        this.notifyApplicationAfterVisitingLocation(visit2.location, visit2.action);
      }
    }
    visitCompleted(visit2) {
      clearBusyState(document.documentElement);
      this.notifyApplicationAfterPageLoad(visit2.getTimingMetrics());
    }
    locationWithActionIsSamePage(location2, action) {
      return this.navigator.locationWithActionIsSamePage(location2, action);
    }
    visitScrolledToSamePageLocation(oldURL, newURL) {
      this.notifyApplicationAfterVisitingSamePageLocation(oldURL, newURL);
    }
    willSubmitForm(form, submitter) {
      const action = getAction(form, submitter);
      return this.submissionIsNavigatable(form, submitter) && locationIsVisitable(expandURL(action), this.snapshot.rootLocation);
    }
    formSubmitted(form, submitter) {
      this.navigator.submitForm(form, submitter);
    }
    pageBecameInteractive() {
      this.view.lastRenderedLocation = this.location;
      this.notifyApplicationAfterPageLoad();
    }
    pageLoaded() {
      this.history.assumeControlOfScrollRestoration();
    }
    pageWillUnload() {
      this.history.relinquishControlOfScrollRestoration();
    }
    receivedMessageFromStream(message) {
      this.renderStreamMessage(message);
    }
    viewWillCacheSnapshot() {
      var _a;
      if (!((_a = this.navigator.currentVisit) === null || _a === void 0 ? void 0 : _a.silent)) {
        this.notifyApplicationBeforeCachingSnapshot();
      }
    }
    allowsImmediateRender({ element }, options) {
      const event = this.notifyApplicationBeforeRender(element, options);
      const { defaultPrevented, detail: { render } } = event;
      if (this.view.renderer && render) {
        this.view.renderer.renderElement = render;
      }
      return !defaultPrevented;
    }
    viewRenderedSnapshot(_snapshot, _isPreview) {
      this.view.lastRenderedLocation = this.history.location;
      this.notifyApplicationAfterRender();
    }
    preloadOnLoadLinksForView(element) {
      this.preloader.preloadOnLoadLinksForView(element);
    }
    viewInvalidated(reason) {
      this.adapter.pageInvalidated(reason);
    }
    frameLoaded(frame) {
      this.notifyApplicationAfterFrameLoad(frame);
    }
    frameRendered(fetchResponse, frame) {
      this.notifyApplicationAfterFrameRender(fetchResponse, frame);
    }
    applicationAllowsFollowingLinkToLocation(link, location2, ev) {
      const event = this.notifyApplicationAfterClickingLinkToLocation(link, location2, ev);
      return !event.defaultPrevented;
    }
    applicationAllowsVisitingLocation(location2) {
      const event = this.notifyApplicationBeforeVisitingLocation(location2);
      return !event.defaultPrevented;
    }
    notifyApplicationAfterClickingLinkToLocation(link, location2, event) {
      return dispatch("turbo:click", {
        target: link,
        detail: { url: location2.href, originalEvent: event },
        cancelable: true
      });
    }
    notifyApplicationBeforeVisitingLocation(location2) {
      return dispatch("turbo:before-visit", {
        detail: { url: location2.href },
        cancelable: true
      });
    }
    notifyApplicationAfterVisitingLocation(location2, action) {
      return dispatch("turbo:visit", { detail: { url: location2.href, action } });
    }
    notifyApplicationBeforeCachingSnapshot() {
      return dispatch("turbo:before-cache");
    }
    notifyApplicationBeforeRender(newBody, options) {
      return dispatch("turbo:before-render", {
        detail: Object.assign({ newBody }, options),
        cancelable: true
      });
    }
    notifyApplicationAfterRender() {
      return dispatch("turbo:render");
    }
    notifyApplicationAfterPageLoad(timing = {}) {
      return dispatch("turbo:load", {
        detail: { url: this.location.href, timing }
      });
    }
    notifyApplicationAfterVisitingSamePageLocation(oldURL, newURL) {
      dispatchEvent(new HashChangeEvent("hashchange", {
        oldURL: oldURL.toString(),
        newURL: newURL.toString()
      }));
    }
    notifyApplicationAfterFrameLoad(frame) {
      return dispatch("turbo:frame-load", { target: frame });
    }
    notifyApplicationAfterFrameRender(fetchResponse, frame) {
      return dispatch("turbo:frame-render", {
        detail: { fetchResponse },
        target: frame,
        cancelable: true
      });
    }
    submissionIsNavigatable(form, submitter) {
      if (this.formMode == "off") {
        return false;
      } else {
        const submitterIsNavigatable = submitter ? this.elementIsNavigatable(submitter) : true;
        if (this.formMode == "optin") {
          return submitterIsNavigatable && form.closest('[data-turbo="true"]') != null;
        } else {
          return submitterIsNavigatable && this.elementIsNavigatable(form);
        }
      }
    }
    elementIsNavigatable(element) {
      const container = findClosestRecursively(element, "[data-turbo]");
      const withinFrame = findClosestRecursively(element, "turbo-frame");
      if (this.drive || withinFrame) {
        if (container) {
          return container.getAttribute("data-turbo") != "false";
        } else {
          return true;
        }
      } else {
        if (container) {
          return container.getAttribute("data-turbo") == "true";
        } else {
          return false;
        }
      }
    }
    getActionForLink(link) {
      return getVisitAction(link) || "advance";
    }
    get snapshot() {
      return this.view.snapshot;
    }
  };
  function extendURLWithDeprecatedProperties(url) {
    Object.defineProperties(url, deprecatedLocationPropertyDescriptors);
  }
  var deprecatedLocationPropertyDescriptors = {
    absoluteURL: {
      get() {
        return this.toString();
      }
    }
  };
  var Cache = class {
    constructor(session2) {
      this.session = session2;
    }
    clear() {
      this.session.clearCache();
    }
    resetCacheControl() {
      this.setCacheControl("");
    }
    exemptPageFromCache() {
      this.setCacheControl("no-cache");
    }
    exemptPageFromPreview() {
      this.setCacheControl("no-preview");
    }
    setCacheControl(value) {
      setMetaContent("turbo-cache-control", value);
    }
  };
  var StreamActions = {
    after() {
      this.targetElements.forEach((e) => {
        var _a;
        return (_a = e.parentElement) === null || _a === void 0 ? void 0 : _a.insertBefore(this.templateContent, e.nextSibling);
      });
    },
    append() {
      this.removeDuplicateTargetChildren();
      this.targetElements.forEach((e) => e.append(this.templateContent));
    },
    before() {
      this.targetElements.forEach((e) => {
        var _a;
        return (_a = e.parentElement) === null || _a === void 0 ? void 0 : _a.insertBefore(this.templateContent, e);
      });
    },
    prepend() {
      this.removeDuplicateTargetChildren();
      this.targetElements.forEach((e) => e.prepend(this.templateContent));
    },
    remove() {
      this.targetElements.forEach((e) => e.remove());
    },
    replace() {
      this.targetElements.forEach((e) => e.replaceWith(this.templateContent));
    },
    update() {
      this.targetElements.forEach((targetElement) => {
        targetElement.innerHTML = "";
        targetElement.append(this.templateContent);
      });
    }
  };
  var session = new Session();
  var cache = new Cache(session);
  var { navigator: navigator$1 } = session;
  function start() {
    session.start();
  }
  function registerAdapter(adapter) {
    session.registerAdapter(adapter);
  }
  function visit(location2, options) {
    session.visit(location2, options);
  }
  function connectStreamSource(source) {
    session.connectStreamSource(source);
  }
  function disconnectStreamSource(source) {
    session.disconnectStreamSource(source);
  }
  function renderStreamMessage(message) {
    session.renderStreamMessage(message);
  }
  function clearCache() {
    console.warn("Please replace `Turbo.clearCache()` with `Turbo.cache.clear()`. The top-level function is deprecated and will be removed in a future version of Turbo.`");
    session.clearCache();
  }
  function setProgressBarDelay(delay) {
    session.setProgressBarDelay(delay);
  }
  function setConfirmMethod(confirmMethod) {
    FormSubmission.confirmMethod = confirmMethod;
  }
  function setFormMode(mode) {
    session.setFormMode(mode);
  }
  var Turbo = /* @__PURE__ */ Object.freeze({
    __proto__: null,
    navigator: navigator$1,
    session,
    cache,
    PageRenderer,
    PageSnapshot,
    FrameRenderer,
    start,
    registerAdapter,
    visit,
    connectStreamSource,
    disconnectStreamSource,
    renderStreamMessage,
    clearCache,
    setProgressBarDelay,
    setConfirmMethod,
    setFormMode,
    StreamActions
  });
  var TurboFrameMissingError = class extends Error {
  };
  var FrameController = class {
    constructor(element) {
      this.fetchResponseLoaded = (_fetchResponse) => {
      };
      this.currentFetchRequest = null;
      this.resolveVisitPromise = () => {
      };
      this.connected = false;
      this.hasBeenLoaded = false;
      this.ignoredAttributes = /* @__PURE__ */ new Set();
      this.action = null;
      this.visitCachedSnapshot = ({ element: element2 }) => {
        const frame = element2.querySelector("#" + this.element.id);
        if (frame && this.previousFrameElement) {
          frame.replaceChildren(...this.previousFrameElement.children);
        }
        delete this.previousFrameElement;
      };
      this.element = element;
      this.view = new FrameView(this, this.element);
      this.appearanceObserver = new AppearanceObserver(this, this.element);
      this.formLinkClickObserver = new FormLinkClickObserver(this, this.element);
      this.linkInterceptor = new LinkInterceptor(this, this.element);
      this.restorationIdentifier = uuid();
      this.formSubmitObserver = new FormSubmitObserver(this, this.element);
    }
    connect() {
      if (!this.connected) {
        this.connected = true;
        if (this.loadingStyle == FrameLoadingStyle.lazy) {
          this.appearanceObserver.start();
        } else {
          this.loadSourceURL();
        }
        this.formLinkClickObserver.start();
        this.linkInterceptor.start();
        this.formSubmitObserver.start();
      }
    }
    disconnect() {
      if (this.connected) {
        this.connected = false;
        this.appearanceObserver.stop();
        this.formLinkClickObserver.stop();
        this.linkInterceptor.stop();
        this.formSubmitObserver.stop();
      }
    }
    disabledChanged() {
      if (this.loadingStyle == FrameLoadingStyle.eager) {
        this.loadSourceURL();
      }
    }
    sourceURLChanged() {
      if (this.isIgnoringChangesTo("src"))
        return;
      if (this.element.isConnected) {
        this.complete = false;
      }
      if (this.loadingStyle == FrameLoadingStyle.eager || this.hasBeenLoaded) {
        this.loadSourceURL();
      }
    }
    sourceURLReloaded() {
      const { src } = this.element;
      this.ignoringChangesToAttribute("complete", () => {
        this.element.removeAttribute("complete");
      });
      this.element.src = null;
      this.element.src = src;
      return this.element.loaded;
    }
    completeChanged() {
      if (this.isIgnoringChangesTo("complete"))
        return;
      this.loadSourceURL();
    }
    loadingStyleChanged() {
      if (this.loadingStyle == FrameLoadingStyle.lazy) {
        this.appearanceObserver.start();
      } else {
        this.appearanceObserver.stop();
        this.loadSourceURL();
      }
    }
    async loadSourceURL() {
      if (this.enabled && this.isActive && !this.complete && this.sourceURL) {
        this.element.loaded = this.visit(expandURL(this.sourceURL));
        this.appearanceObserver.stop();
        await this.element.loaded;
        this.hasBeenLoaded = true;
      }
    }
    async loadResponse(fetchResponse) {
      if (fetchResponse.redirected || fetchResponse.succeeded && fetchResponse.isHTML) {
        this.sourceURL = fetchResponse.response.url;
      }
      try {
        const html = await fetchResponse.responseHTML;
        if (html) {
          const document2 = parseHTMLDocument(html);
          const pageSnapshot = PageSnapshot.fromDocument(document2);
          if (pageSnapshot.isVisitable) {
            await this.loadFrameResponse(fetchResponse, document2);
          } else {
            await this.handleUnvisitableFrameResponse(fetchResponse);
          }
        }
      } finally {
        this.fetchResponseLoaded = () => {
        };
      }
    }
    elementAppearedInViewport(element) {
      this.proposeVisitIfNavigatedWithAction(element, element);
      this.loadSourceURL();
    }
    willSubmitFormLinkToLocation(link) {
      return this.shouldInterceptNavigation(link);
    }
    submittedFormLinkToLocation(link, _location, form) {
      const frame = this.findFrameElement(link);
      if (frame)
        form.setAttribute("data-turbo-frame", frame.id);
    }
    shouldInterceptLinkClick(element, _location, _event) {
      return this.shouldInterceptNavigation(element);
    }
    linkClickIntercepted(element, location2) {
      this.navigateFrame(element, location2);
    }
    willSubmitForm(element, submitter) {
      return element.closest("turbo-frame") == this.element && this.shouldInterceptNavigation(element, submitter);
    }
    formSubmitted(element, submitter) {
      if (this.formSubmission) {
        this.formSubmission.stop();
      }
      this.formSubmission = new FormSubmission(this, element, submitter);
      const { fetchRequest } = this.formSubmission;
      this.prepareRequest(fetchRequest);
      this.formSubmission.start();
    }
    prepareRequest(request) {
      var _a;
      request.headers["Turbo-Frame"] = this.id;
      if ((_a = this.currentNavigationElement) === null || _a === void 0 ? void 0 : _a.hasAttribute("data-turbo-stream")) {
        request.acceptResponseType(StreamMessage.contentType);
      }
    }
    requestStarted(_request) {
      markAsBusy(this.element);
    }
    requestPreventedHandlingResponse(_request, _response) {
      this.resolveVisitPromise();
    }
    async requestSucceededWithResponse(request, response) {
      await this.loadResponse(response);
      this.resolveVisitPromise();
    }
    async requestFailedWithResponse(request, response) {
      await this.loadResponse(response);
      this.resolveVisitPromise();
    }
    requestErrored(request, error2) {
      console.error(error2);
      this.resolveVisitPromise();
    }
    requestFinished(_request) {
      clearBusyState(this.element);
    }
    formSubmissionStarted({ formElement }) {
      markAsBusy(formElement, this.findFrameElement(formElement));
    }
    formSubmissionSucceededWithResponse(formSubmission, response) {
      const frame = this.findFrameElement(formSubmission.formElement, formSubmission.submitter);
      frame.delegate.proposeVisitIfNavigatedWithAction(frame, formSubmission.formElement, formSubmission.submitter);
      frame.delegate.loadResponse(response);
      if (!formSubmission.isSafe) {
        session.clearCache();
      }
    }
    formSubmissionFailedWithResponse(formSubmission, fetchResponse) {
      this.element.delegate.loadResponse(fetchResponse);
      session.clearCache();
    }
    formSubmissionErrored(formSubmission, error2) {
      console.error(error2);
    }
    formSubmissionFinished({ formElement }) {
      clearBusyState(formElement, this.findFrameElement(formElement));
    }
    allowsImmediateRender({ element: newFrame }, options) {
      const event = dispatch("turbo:before-frame-render", {
        target: this.element,
        detail: Object.assign({ newFrame }, options),
        cancelable: true
      });
      const { defaultPrevented, detail: { render } } = event;
      if (this.view.renderer && render) {
        this.view.renderer.renderElement = render;
      }
      return !defaultPrevented;
    }
    viewRenderedSnapshot(_snapshot, _isPreview) {
    }
    preloadOnLoadLinksForView(element) {
      session.preloadOnLoadLinksForView(element);
    }
    viewInvalidated() {
    }
    willRenderFrame(currentElement, _newElement) {
      this.previousFrameElement = currentElement.cloneNode(true);
    }
    async loadFrameResponse(fetchResponse, document2) {
      const newFrameElement = await this.extractForeignFrameElement(document2.body);
      if (newFrameElement) {
        const snapshot = new Snapshot(newFrameElement);
        const renderer = new FrameRenderer(this, this.view.snapshot, snapshot, FrameRenderer.renderElement, false, false);
        if (this.view.renderPromise)
          await this.view.renderPromise;
        this.changeHistory();
        await this.view.render(renderer);
        this.complete = true;
        session.frameRendered(fetchResponse, this.element);
        session.frameLoaded(this.element);
        this.fetchResponseLoaded(fetchResponse);
      } else if (this.willHandleFrameMissingFromResponse(fetchResponse)) {
        this.handleFrameMissingFromResponse(fetchResponse);
      }
    }
    async visit(url) {
      var _a;
      const request = new FetchRequest(this, FetchMethod.get, url, new URLSearchParams(), this.element);
      (_a = this.currentFetchRequest) === null || _a === void 0 ? void 0 : _a.cancel();
      this.currentFetchRequest = request;
      return new Promise((resolve) => {
        this.resolveVisitPromise = () => {
          this.resolveVisitPromise = () => {
          };
          this.currentFetchRequest = null;
          resolve();
        };
        request.perform();
      });
    }
    navigateFrame(element, url, submitter) {
      const frame = this.findFrameElement(element, submitter);
      frame.delegate.proposeVisitIfNavigatedWithAction(frame, element, submitter);
      this.withCurrentNavigationElement(element, () => {
        frame.src = url;
      });
    }
    proposeVisitIfNavigatedWithAction(frame, element, submitter) {
      this.action = getVisitAction(submitter, element, frame);
      if (this.action) {
        const pageSnapshot = PageSnapshot.fromElement(frame).clone();
        const { visitCachedSnapshot } = frame.delegate;
        frame.delegate.fetchResponseLoaded = (fetchResponse) => {
          if (frame.src) {
            const { statusCode, redirected } = fetchResponse;
            const responseHTML = frame.ownerDocument.documentElement.outerHTML;
            const response = { statusCode, redirected, responseHTML };
            const options = {
              response,
              visitCachedSnapshot,
              willRender: false,
              updateHistory: false,
              restorationIdentifier: this.restorationIdentifier,
              snapshot: pageSnapshot
            };
            if (this.action)
              options.action = this.action;
            session.visit(frame.src, options);
          }
        };
      }
    }
    changeHistory() {
      if (this.action) {
        const method = getHistoryMethodForAction(this.action);
        session.history.update(method, expandURL(this.element.src || ""), this.restorationIdentifier);
      }
    }
    async handleUnvisitableFrameResponse(fetchResponse) {
      console.warn(`The response (${fetchResponse.statusCode}) from <turbo-frame id="${this.element.id}"> is performing a full page visit due to turbo-visit-control.`);
      await this.visitResponse(fetchResponse.response);
    }
    willHandleFrameMissingFromResponse(fetchResponse) {
      this.element.setAttribute("complete", "");
      const response = fetchResponse.response;
      const visit2 = async (url, options = {}) => {
        if (url instanceof Response) {
          this.visitResponse(url);
        } else {
          session.visit(url, options);
        }
      };
      const event = dispatch("turbo:frame-missing", {
        target: this.element,
        detail: { response, visit: visit2 },
        cancelable: true
      });
      return !event.defaultPrevented;
    }
    handleFrameMissingFromResponse(fetchResponse) {
      this.view.missing();
      this.throwFrameMissingError(fetchResponse);
    }
    throwFrameMissingError(fetchResponse) {
      const message = `The response (${fetchResponse.statusCode}) did not contain the expected <turbo-frame id="${this.element.id}"> and will be ignored. To perform a full page visit instead, set turbo-visit-control to reload.`;
      throw new TurboFrameMissingError(message);
    }
    async visitResponse(response) {
      const wrapped = new FetchResponse(response);
      const responseHTML = await wrapped.responseHTML;
      const { location: location2, redirected, statusCode } = wrapped;
      return session.visit(location2, { response: { redirected, statusCode, responseHTML } });
    }
    findFrameElement(element, submitter) {
      var _a;
      const id = getAttribute("data-turbo-frame", submitter, element) || this.element.getAttribute("target");
      return (_a = getFrameElementById(id)) !== null && _a !== void 0 ? _a : this.element;
    }
    async extractForeignFrameElement(container) {
      let element;
      const id = CSS.escape(this.id);
      try {
        element = activateElement(container.querySelector(`turbo-frame#${id}`), this.sourceURL);
        if (element) {
          return element;
        }
        element = activateElement(container.querySelector(`turbo-frame[src][recurse~=${id}]`), this.sourceURL);
        if (element) {
          await element.loaded;
          return await this.extractForeignFrameElement(element);
        }
      } catch (error2) {
        console.error(error2);
        return new FrameElement();
      }
      return null;
    }
    formActionIsVisitable(form, submitter) {
      const action = getAction(form, submitter);
      return locationIsVisitable(expandURL(action), this.rootLocation);
    }
    shouldInterceptNavigation(element, submitter) {
      const id = getAttribute("data-turbo-frame", submitter, element) || this.element.getAttribute("target");
      if (element instanceof HTMLFormElement && !this.formActionIsVisitable(element, submitter)) {
        return false;
      }
      if (!this.enabled || id == "_top") {
        return false;
      }
      if (id) {
        const frameElement = getFrameElementById(id);
        if (frameElement) {
          return !frameElement.disabled;
        }
      }
      if (!session.elementIsNavigatable(element)) {
        return false;
      }
      if (submitter && !session.elementIsNavigatable(submitter)) {
        return false;
      }
      return true;
    }
    get id() {
      return this.element.id;
    }
    get enabled() {
      return !this.element.disabled;
    }
    get sourceURL() {
      if (this.element.src) {
        return this.element.src;
      }
    }
    set sourceURL(sourceURL) {
      this.ignoringChangesToAttribute("src", () => {
        this.element.src = sourceURL !== null && sourceURL !== void 0 ? sourceURL : null;
      });
    }
    get loadingStyle() {
      return this.element.loading;
    }
    get isLoading() {
      return this.formSubmission !== void 0 || this.resolveVisitPromise() !== void 0;
    }
    get complete() {
      return this.element.hasAttribute("complete");
    }
    set complete(value) {
      this.ignoringChangesToAttribute("complete", () => {
        if (value) {
          this.element.setAttribute("complete", "");
        } else {
          this.element.removeAttribute("complete");
        }
      });
    }
    get isActive() {
      return this.element.isActive && this.connected;
    }
    get rootLocation() {
      var _a;
      const meta = this.element.ownerDocument.querySelector(`meta[name="turbo-root"]`);
      const root = (_a = meta === null || meta === void 0 ? void 0 : meta.content) !== null && _a !== void 0 ? _a : "/";
      return expandURL(root);
    }
    isIgnoringChangesTo(attributeName) {
      return this.ignoredAttributes.has(attributeName);
    }
    ignoringChangesToAttribute(attributeName, callback) {
      this.ignoredAttributes.add(attributeName);
      callback();
      this.ignoredAttributes.delete(attributeName);
    }
    withCurrentNavigationElement(element, callback) {
      this.currentNavigationElement = element;
      callback();
      delete this.currentNavigationElement;
    }
  };
  function getFrameElementById(id) {
    if (id != null) {
      const element = document.getElementById(id);
      if (element instanceof FrameElement) {
        return element;
      }
    }
  }
  function activateElement(element, currentURL) {
    if (element) {
      const src = element.getAttribute("src");
      if (src != null && currentURL != null && urlsAreEqual(src, currentURL)) {
        throw new Error(`Matching <turbo-frame id="${element.id}"> element has a source URL which references itself`);
      }
      if (element.ownerDocument !== document) {
        element = document.importNode(element, true);
      }
      if (element instanceof FrameElement) {
        element.connectedCallback();
        element.disconnectedCallback();
        return element;
      }
    }
  }
  var StreamElement = class extends HTMLElement {
    static async renderElement(newElement) {
      await newElement.performAction();
    }
    async connectedCallback() {
      try {
        await this.render();
      } catch (error2) {
        console.error(error2);
      } finally {
        this.disconnect();
      }
    }
    async render() {
      var _a;
      return (_a = this.renderPromise) !== null && _a !== void 0 ? _a : this.renderPromise = (async () => {
        const event = this.beforeRenderEvent;
        if (this.dispatchEvent(event)) {
          await nextAnimationFrame();
          await event.detail.render(this);
        }
      })();
    }
    disconnect() {
      try {
        this.remove();
      } catch (_a) {
      }
    }
    removeDuplicateTargetChildren() {
      this.duplicateChildren.forEach((c) => c.remove());
    }
    get duplicateChildren() {
      var _a;
      const existingChildren = this.targetElements.flatMap((e) => [...e.children]).filter((c) => !!c.id);
      const newChildrenIds = [...((_a = this.templateContent) === null || _a === void 0 ? void 0 : _a.children) || []].filter((c) => !!c.id).map((c) => c.id);
      return existingChildren.filter((c) => newChildrenIds.includes(c.id));
    }
    get performAction() {
      if (this.action) {
        const actionFunction = StreamActions[this.action];
        if (actionFunction) {
          return actionFunction;
        }
        this.raise("unknown action");
      }
      this.raise("action attribute is missing");
    }
    get targetElements() {
      if (this.target) {
        return this.targetElementsById;
      } else if (this.targets) {
        return this.targetElementsByQuery;
      } else {
        this.raise("target or targets attribute is missing");
      }
    }
    get templateContent() {
      return this.templateElement.content.cloneNode(true);
    }
    get templateElement() {
      if (this.firstElementChild === null) {
        const template = this.ownerDocument.createElement("template");
        this.appendChild(template);
        return template;
      } else if (this.firstElementChild instanceof HTMLTemplateElement) {
        return this.firstElementChild;
      }
      this.raise("first child element must be a <template> element");
    }
    get action() {
      return this.getAttribute("action");
    }
    get target() {
      return this.getAttribute("target");
    }
    get targets() {
      return this.getAttribute("targets");
    }
    raise(message) {
      throw new Error(`${this.description}: ${message}`);
    }
    get description() {
      var _a, _b;
      return (_b = ((_a = this.outerHTML.match(/<[^>]+>/)) !== null && _a !== void 0 ? _a : [])[0]) !== null && _b !== void 0 ? _b : "<turbo-stream>";
    }
    get beforeRenderEvent() {
      return new CustomEvent("turbo:before-stream-render", {
        bubbles: true,
        cancelable: true,
        detail: { newStream: this, render: StreamElement.renderElement }
      });
    }
    get targetElementsById() {
      var _a;
      const element = (_a = this.ownerDocument) === null || _a === void 0 ? void 0 : _a.getElementById(this.target);
      if (element !== null) {
        return [element];
      } else {
        return [];
      }
    }
    get targetElementsByQuery() {
      var _a;
      const elements = (_a = this.ownerDocument) === null || _a === void 0 ? void 0 : _a.querySelectorAll(this.targets);
      if (elements.length !== 0) {
        return Array.prototype.slice.call(elements);
      } else {
        return [];
      }
    }
  };
  var StreamSourceElement = class extends HTMLElement {
    constructor() {
      super(...arguments);
      this.streamSource = null;
    }
    connectedCallback() {
      this.streamSource = this.src.match(/^ws{1,2}:/) ? new WebSocket(this.src) : new EventSource(this.src);
      connectStreamSource(this.streamSource);
    }
    disconnectedCallback() {
      if (this.streamSource) {
        disconnectStreamSource(this.streamSource);
      }
    }
    get src() {
      return this.getAttribute("src") || "";
    }
  };
  FrameElement.delegateConstructor = FrameController;
  if (customElements.get("turbo-frame") === void 0) {
    customElements.define("turbo-frame", FrameElement);
  }
  if (customElements.get("turbo-stream") === void 0) {
    customElements.define("turbo-stream", StreamElement);
  }
  if (customElements.get("turbo-stream-source") === void 0) {
    customElements.define("turbo-stream-source", StreamSourceElement);
  }
  (() => {
    let element = document.currentScript;
    if (!element)
      return;
    if (element.hasAttribute("data-turbo-suppress-warning"))
      return;
    element = element.parentElement;
    while (element) {
      if (element == document.body) {
        return console.warn(unindent`
        You are loading Turbo from a <script> element inside the <body> element. This is probably not what you meant to do!

        Load your application’s JavaScript bundle inside the <head> element instead. <script> elements in <body> are evaluated with each page change.

        For more information, see: https://turbo.hotwired.dev/handbook/building#working-with-script-elements

        ——
        Suppress this warning by adding a "data-turbo-suppress-warning" attribute to: %s
      `, element.outerHTML);
      }
      element = element.parentElement;
    }
  })();
  window.Turbo = Turbo;
  start();

  // node_modules/@hotwired/turbo-rails/app/javascript/turbo/cable.js
  var consumer;
  async function getConsumer() {
    return consumer || setConsumer(createConsumer2().then(setConsumer));
  }
  function setConsumer(newConsumer) {
    return consumer = newConsumer;
  }
  async function createConsumer2() {
    const { createConsumer: createConsumer3 } = await Promise.resolve().then(() => (init_src(), src_exports));
    return createConsumer3();
  }
  async function subscribeTo(channel, mixin) {
    const { subscriptions } = await getConsumer();
    return subscriptions.create(channel, mixin);
  }

  // node_modules/@hotwired/turbo-rails/app/javascript/turbo/snakeize.js
  function walk(obj) {
    if (!obj || typeof obj !== "object")
      return obj;
    if (obj instanceof Date || obj instanceof RegExp)
      return obj;
    if (Array.isArray(obj))
      return obj.map(walk);
    return Object.keys(obj).reduce(function(acc, key) {
      var camel = key[0].toLowerCase() + key.slice(1).replace(/([A-Z]+)/g, function(m, x) {
        return "_" + x.toLowerCase();
      });
      acc[camel] = walk(obj[key]);
      return acc;
    }, {});
  }

  // node_modules/@hotwired/turbo-rails/app/javascript/turbo/cable_stream_source_element.js
  var TurboCableStreamSourceElement = class extends HTMLElement {
    async connectedCallback() {
      connectStreamSource(this);
      this.subscription = await subscribeTo(this.channel, {
        received: this.dispatchMessageEvent.bind(this),
        connected: this.subscriptionConnected.bind(this),
        disconnected: this.subscriptionDisconnected.bind(this)
      });
    }
    disconnectedCallback() {
      disconnectStreamSource(this);
      if (this.subscription)
        this.subscription.unsubscribe();
    }
    dispatchMessageEvent(data) {
      const event = new MessageEvent("message", { data });
      return this.dispatchEvent(event);
    }
    subscriptionConnected() {
      this.setAttribute("connected", "");
    }
    subscriptionDisconnected() {
      this.removeAttribute("connected");
    }
    get channel() {
      const channel = this.getAttribute("channel");
      const signed_stream_name = this.getAttribute("signed-stream-name");
      return { channel, signed_stream_name, ...walk({ ...this.dataset }) };
    }
  };
  if (customElements.get("turbo-cable-stream-source") === void 0) {
    customElements.define("turbo-cable-stream-source", TurboCableStreamSourceElement);
  }

  // node_modules/@hotwired/turbo-rails/app/javascript/turbo/fetch_requests.js
  function encodeMethodIntoRequestBody(event) {
    if (event.target instanceof HTMLFormElement) {
      const { target: form, detail: { fetchOptions } } = event;
      form.addEventListener("turbo:submit-start", ({ detail: { formSubmission: { submitter } } }) => {
        const body = isBodyInit(fetchOptions.body) ? fetchOptions.body : new URLSearchParams();
        const method = determineFetchMethod(submitter, body, form);
        if (!/get/i.test(method)) {
          if (/post/i.test(method)) {
            body.delete("_method");
          } else {
            body.set("_method", method);
          }
          fetchOptions.method = "post";
        }
      }, { once: true });
    }
  }
  function determineFetchMethod(submitter, body, form) {
    const formMethod = determineFormMethod(submitter);
    const overrideMethod = body.get("_method");
    const method = form.getAttribute("method") || "get";
    if (typeof formMethod == "string") {
      return formMethod;
    } else if (typeof overrideMethod == "string") {
      return overrideMethod;
    } else {
      return method;
    }
  }
  function determineFormMethod(submitter) {
    if (submitter instanceof HTMLButtonElement || submitter instanceof HTMLInputElement) {
      if (submitter.hasAttribute("formmethod")) {
        return submitter.formMethod;
      } else {
        return null;
      }
    } else {
      return null;
    }
  }
  function isBodyInit(body) {
    return body instanceof FormData || body instanceof URLSearchParams;
  }

  // node_modules/@hotwired/turbo-rails/app/javascript/turbo/index.js
  addEventListener("turbo:before-fetch-request", encodeMethodIntoRequestBody);

  // app/javascript/application.js
  var import_bootstrap2 = __toESM(require_bootstrap_min());

  // node_modules/@hotwired/stimulus/dist/stimulus.js
  var EventListener = class {
    constructor(eventTarget, eventName, eventOptions) {
      this.eventTarget = eventTarget;
      this.eventName = eventName;
      this.eventOptions = eventOptions;
      this.unorderedBindings = /* @__PURE__ */ new Set();
    }
    connect() {
      this.eventTarget.addEventListener(this.eventName, this, this.eventOptions);
    }
    disconnect() {
      this.eventTarget.removeEventListener(this.eventName, this, this.eventOptions);
    }
    bindingConnected(binding) {
      this.unorderedBindings.add(binding);
    }
    bindingDisconnected(binding) {
      this.unorderedBindings.delete(binding);
    }
    handleEvent(event) {
      const extendedEvent = extendEvent(event);
      for (const binding of this.bindings) {
        if (extendedEvent.immediatePropagationStopped) {
          break;
        } else {
          binding.handleEvent(extendedEvent);
        }
      }
    }
    hasBindings() {
      return this.unorderedBindings.size > 0;
    }
    get bindings() {
      return Array.from(this.unorderedBindings).sort((left2, right2) => {
        const leftIndex = left2.index, rightIndex = right2.index;
        return leftIndex < rightIndex ? -1 : leftIndex > rightIndex ? 1 : 0;
      });
    }
  };
  function extendEvent(event) {
    if ("immediatePropagationStopped" in event) {
      return event;
    } else {
      const { stopImmediatePropagation } = event;
      return Object.assign(event, {
        immediatePropagationStopped: false,
        stopImmediatePropagation() {
          this.immediatePropagationStopped = true;
          stopImmediatePropagation.call(this);
        }
      });
    }
  }
  var Dispatcher = class {
    constructor(application2) {
      this.application = application2;
      this.eventListenerMaps = /* @__PURE__ */ new Map();
      this.started = false;
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.eventListeners.forEach((eventListener) => eventListener.connect());
      }
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.eventListeners.forEach((eventListener) => eventListener.disconnect());
      }
    }
    get eventListeners() {
      return Array.from(this.eventListenerMaps.values()).reduce((listeners, map) => listeners.concat(Array.from(map.values())), []);
    }
    bindingConnected(binding) {
      this.fetchEventListenerForBinding(binding).bindingConnected(binding);
    }
    bindingDisconnected(binding, clearEventListeners = false) {
      this.fetchEventListenerForBinding(binding).bindingDisconnected(binding);
      if (clearEventListeners)
        this.clearEventListenersForBinding(binding);
    }
    handleError(error2, message, detail = {}) {
      this.application.handleError(error2, `Error ${message}`, detail);
    }
    clearEventListenersForBinding(binding) {
      const eventListener = this.fetchEventListenerForBinding(binding);
      if (!eventListener.hasBindings()) {
        eventListener.disconnect();
        this.removeMappedEventListenerFor(binding);
      }
    }
    removeMappedEventListenerFor(binding) {
      const { eventTarget, eventName, eventOptions } = binding;
      const eventListenerMap = this.fetchEventListenerMapForEventTarget(eventTarget);
      const cacheKey = this.cacheKey(eventName, eventOptions);
      eventListenerMap.delete(cacheKey);
      if (eventListenerMap.size == 0)
        this.eventListenerMaps.delete(eventTarget);
    }
    fetchEventListenerForBinding(binding) {
      const { eventTarget, eventName, eventOptions } = binding;
      return this.fetchEventListener(eventTarget, eventName, eventOptions);
    }
    fetchEventListener(eventTarget, eventName, eventOptions) {
      const eventListenerMap = this.fetchEventListenerMapForEventTarget(eventTarget);
      const cacheKey = this.cacheKey(eventName, eventOptions);
      let eventListener = eventListenerMap.get(cacheKey);
      if (!eventListener) {
        eventListener = this.createEventListener(eventTarget, eventName, eventOptions);
        eventListenerMap.set(cacheKey, eventListener);
      }
      return eventListener;
    }
    createEventListener(eventTarget, eventName, eventOptions) {
      const eventListener = new EventListener(eventTarget, eventName, eventOptions);
      if (this.started) {
        eventListener.connect();
      }
      return eventListener;
    }
    fetchEventListenerMapForEventTarget(eventTarget) {
      let eventListenerMap = this.eventListenerMaps.get(eventTarget);
      if (!eventListenerMap) {
        eventListenerMap = /* @__PURE__ */ new Map();
        this.eventListenerMaps.set(eventTarget, eventListenerMap);
      }
      return eventListenerMap;
    }
    cacheKey(eventName, eventOptions) {
      const parts = [eventName];
      Object.keys(eventOptions).sort().forEach((key) => {
        parts.push(`${eventOptions[key] ? "" : "!"}${key}`);
      });
      return parts.join(":");
    }
  };
  var defaultActionDescriptorFilters = {
    stop({ event, value }) {
      if (value)
        event.stopPropagation();
      return true;
    },
    prevent({ event, value }) {
      if (value)
        event.preventDefault();
      return true;
    },
    self({ event, value, element }) {
      if (value) {
        return element === event.target;
      } else {
        return true;
      }
    }
  };
  var descriptorPattern = /^(?:(?:([^.]+?)\+)?(.+?)(?:\.(.+?))?(?:@(window|document))?->)?(.+?)(?:#([^:]+?))(?::(.+))?$/;
  function parseActionDescriptorString(descriptorString) {
    const source = descriptorString.trim();
    const matches = source.match(descriptorPattern) || [];
    let eventName = matches[2];
    let keyFilter = matches[3];
    if (keyFilter && !["keydown", "keyup", "keypress"].includes(eventName)) {
      eventName += `.${keyFilter}`;
      keyFilter = "";
    }
    return {
      eventTarget: parseEventTarget(matches[4]),
      eventName,
      eventOptions: matches[7] ? parseEventOptions(matches[7]) : {},
      identifier: matches[5],
      methodName: matches[6],
      keyFilter: matches[1] || keyFilter
    };
  }
  function parseEventTarget(eventTargetName) {
    if (eventTargetName == "window") {
      return window;
    } else if (eventTargetName == "document") {
      return document;
    }
  }
  function parseEventOptions(eventOptions) {
    return eventOptions.split(":").reduce((options, token) => Object.assign(options, { [token.replace(/^!/, "")]: !/^!/.test(token) }), {});
  }
  function stringifyEventTarget(eventTarget) {
    if (eventTarget == window) {
      return "window";
    } else if (eventTarget == document) {
      return "document";
    }
  }
  function camelize(value) {
    return value.replace(/(?:[_-])([a-z0-9])/g, (_, char) => char.toUpperCase());
  }
  function namespaceCamelize(value) {
    return camelize(value.replace(/--/g, "-").replace(/__/g, "_"));
  }
  function capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }
  function dasherize(value) {
    return value.replace(/([A-Z])/g, (_, char) => `-${char.toLowerCase()}`);
  }
  function tokenize(value) {
    return value.match(/[^\s]+/g) || [];
  }
  function isSomething(object) {
    return object !== null && object !== void 0;
  }
  function hasProperty(object, property) {
    return Object.prototype.hasOwnProperty.call(object, property);
  }
  var allModifiers = ["meta", "ctrl", "alt", "shift"];
  var Action = class {
    constructor(element, index, descriptor, schema) {
      this.element = element;
      this.index = index;
      this.eventTarget = descriptor.eventTarget || element;
      this.eventName = descriptor.eventName || getDefaultEventNameForElement(element) || error("missing event name");
      this.eventOptions = descriptor.eventOptions || {};
      this.identifier = descriptor.identifier || error("missing identifier");
      this.methodName = descriptor.methodName || error("missing method name");
      this.keyFilter = descriptor.keyFilter || "";
      this.schema = schema;
    }
    static forToken(token, schema) {
      return new this(token.element, token.index, parseActionDescriptorString(token.content), schema);
    }
    toString() {
      const eventFilter = this.keyFilter ? `.${this.keyFilter}` : "";
      const eventTarget = this.eventTargetName ? `@${this.eventTargetName}` : "";
      return `${this.eventName}${eventFilter}${eventTarget}->${this.identifier}#${this.methodName}`;
    }
    shouldIgnoreKeyboardEvent(event) {
      if (!this.keyFilter) {
        return false;
      }
      const filters = this.keyFilter.split("+");
      if (this.keyFilterDissatisfied(event, filters)) {
        return true;
      }
      const standardFilter = filters.filter((key) => !allModifiers.includes(key))[0];
      if (!standardFilter) {
        return false;
      }
      if (!hasProperty(this.keyMappings, standardFilter)) {
        error(`contains unknown key filter: ${this.keyFilter}`);
      }
      return this.keyMappings[standardFilter].toLowerCase() !== event.key.toLowerCase();
    }
    shouldIgnoreMouseEvent(event) {
      if (!this.keyFilter) {
        return false;
      }
      const filters = [this.keyFilter];
      if (this.keyFilterDissatisfied(event, filters)) {
        return true;
      }
      return false;
    }
    get params() {
      const params = {};
      const pattern = new RegExp(`^data-${this.identifier}-(.+)-param$`, "i");
      for (const { name, value } of Array.from(this.element.attributes)) {
        const match = name.match(pattern);
        const key = match && match[1];
        if (key) {
          params[camelize(key)] = typecast(value);
        }
      }
      return params;
    }
    get eventTargetName() {
      return stringifyEventTarget(this.eventTarget);
    }
    get keyMappings() {
      return this.schema.keyMappings;
    }
    keyFilterDissatisfied(event, filters) {
      const [meta, ctrl, alt, shift] = allModifiers.map((modifier) => filters.includes(modifier));
      return event.metaKey !== meta || event.ctrlKey !== ctrl || event.altKey !== alt || event.shiftKey !== shift;
    }
  };
  var defaultEventNames = {
    a: () => "click",
    button: () => "click",
    form: () => "submit",
    details: () => "toggle",
    input: (e) => e.getAttribute("type") == "submit" ? "click" : "input",
    select: () => "change",
    textarea: () => "input"
  };
  function getDefaultEventNameForElement(element) {
    const tagName = element.tagName.toLowerCase();
    if (tagName in defaultEventNames) {
      return defaultEventNames[tagName](element);
    }
  }
  function error(message) {
    throw new Error(message);
  }
  function typecast(value) {
    try {
      return JSON.parse(value);
    } catch (o_O) {
      return value;
    }
  }
  var Binding = class {
    constructor(context, action) {
      this.context = context;
      this.action = action;
    }
    get index() {
      return this.action.index;
    }
    get eventTarget() {
      return this.action.eventTarget;
    }
    get eventOptions() {
      return this.action.eventOptions;
    }
    get identifier() {
      return this.context.identifier;
    }
    handleEvent(event) {
      const actionEvent = this.prepareActionEvent(event);
      if (this.willBeInvokedByEvent(event) && this.applyEventModifiers(actionEvent)) {
        this.invokeWithEvent(actionEvent);
      }
    }
    get eventName() {
      return this.action.eventName;
    }
    get method() {
      const method = this.controller[this.methodName];
      if (typeof method == "function") {
        return method;
      }
      throw new Error(`Action "${this.action}" references undefined method "${this.methodName}"`);
    }
    applyEventModifiers(event) {
      const { element } = this.action;
      const { actionDescriptorFilters } = this.context.application;
      const { controller } = this.context;
      let passes = true;
      for (const [name, value] of Object.entries(this.eventOptions)) {
        if (name in actionDescriptorFilters) {
          const filter = actionDescriptorFilters[name];
          passes = passes && filter({ name, value, event, element, controller });
        } else {
          continue;
        }
      }
      return passes;
    }
    prepareActionEvent(event) {
      return Object.assign(event, { params: this.action.params });
    }
    invokeWithEvent(event) {
      const { target, currentTarget } = event;
      try {
        this.method.call(this.controller, event);
        this.context.logDebugActivity(this.methodName, { event, target, currentTarget, action: this.methodName });
      } catch (error2) {
        const { identifier, controller, element, index } = this;
        const detail = { identifier, controller, element, index, event };
        this.context.handleError(error2, `invoking action "${this.action}"`, detail);
      }
    }
    willBeInvokedByEvent(event) {
      const eventTarget = event.target;
      if (event instanceof KeyboardEvent && this.action.shouldIgnoreKeyboardEvent(event)) {
        return false;
      }
      if (event instanceof MouseEvent && this.action.shouldIgnoreMouseEvent(event)) {
        return false;
      }
      if (this.element === eventTarget) {
        return true;
      } else if (eventTarget instanceof Element && this.element.contains(eventTarget)) {
        return this.scope.containsElement(eventTarget);
      } else {
        return this.scope.containsElement(this.action.element);
      }
    }
    get controller() {
      return this.context.controller;
    }
    get methodName() {
      return this.action.methodName;
    }
    get element() {
      return this.scope.element;
    }
    get scope() {
      return this.context.scope;
    }
  };
  var ElementObserver = class {
    constructor(element, delegate) {
      this.mutationObserverInit = { attributes: true, childList: true, subtree: true };
      this.element = element;
      this.started = false;
      this.delegate = delegate;
      this.elements = /* @__PURE__ */ new Set();
      this.mutationObserver = new MutationObserver((mutations) => this.processMutations(mutations));
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.mutationObserver.observe(this.element, this.mutationObserverInit);
        this.refresh();
      }
    }
    pause(callback) {
      if (this.started) {
        this.mutationObserver.disconnect();
        this.started = false;
      }
      callback();
      if (!this.started) {
        this.mutationObserver.observe(this.element, this.mutationObserverInit);
        this.started = true;
      }
    }
    stop() {
      if (this.started) {
        this.mutationObserver.takeRecords();
        this.mutationObserver.disconnect();
        this.started = false;
      }
    }
    refresh() {
      if (this.started) {
        const matches = new Set(this.matchElementsInTree());
        for (const element of Array.from(this.elements)) {
          if (!matches.has(element)) {
            this.removeElement(element);
          }
        }
        for (const element of Array.from(matches)) {
          this.addElement(element);
        }
      }
    }
    processMutations(mutations) {
      if (this.started) {
        for (const mutation of mutations) {
          this.processMutation(mutation);
        }
      }
    }
    processMutation(mutation) {
      if (mutation.type == "attributes") {
        this.processAttributeChange(mutation.target, mutation.attributeName);
      } else if (mutation.type == "childList") {
        this.processRemovedNodes(mutation.removedNodes);
        this.processAddedNodes(mutation.addedNodes);
      }
    }
    processAttributeChange(element, attributeName) {
      if (this.elements.has(element)) {
        if (this.delegate.elementAttributeChanged && this.matchElement(element)) {
          this.delegate.elementAttributeChanged(element, attributeName);
        } else {
          this.removeElement(element);
        }
      } else if (this.matchElement(element)) {
        this.addElement(element);
      }
    }
    processRemovedNodes(nodes) {
      for (const node of Array.from(nodes)) {
        const element = this.elementFromNode(node);
        if (element) {
          this.processTree(element, this.removeElement);
        }
      }
    }
    processAddedNodes(nodes) {
      for (const node of Array.from(nodes)) {
        const element = this.elementFromNode(node);
        if (element && this.elementIsActive(element)) {
          this.processTree(element, this.addElement);
        }
      }
    }
    matchElement(element) {
      return this.delegate.matchElement(element);
    }
    matchElementsInTree(tree = this.element) {
      return this.delegate.matchElementsInTree(tree);
    }
    processTree(tree, processor) {
      for (const element of this.matchElementsInTree(tree)) {
        processor.call(this, element);
      }
    }
    elementFromNode(node) {
      if (node.nodeType == Node.ELEMENT_NODE) {
        return node;
      }
    }
    elementIsActive(element) {
      if (element.isConnected != this.element.isConnected) {
        return false;
      } else {
        return this.element.contains(element);
      }
    }
    addElement(element) {
      if (!this.elements.has(element)) {
        if (this.elementIsActive(element)) {
          this.elements.add(element);
          if (this.delegate.elementMatched) {
            this.delegate.elementMatched(element);
          }
        }
      }
    }
    removeElement(element) {
      if (this.elements.has(element)) {
        this.elements.delete(element);
        if (this.delegate.elementUnmatched) {
          this.delegate.elementUnmatched(element);
        }
      }
    }
  };
  var AttributeObserver = class {
    constructor(element, attributeName, delegate) {
      this.attributeName = attributeName;
      this.delegate = delegate;
      this.elementObserver = new ElementObserver(element, this);
    }
    get element() {
      return this.elementObserver.element;
    }
    get selector() {
      return `[${this.attributeName}]`;
    }
    start() {
      this.elementObserver.start();
    }
    pause(callback) {
      this.elementObserver.pause(callback);
    }
    stop() {
      this.elementObserver.stop();
    }
    refresh() {
      this.elementObserver.refresh();
    }
    get started() {
      return this.elementObserver.started;
    }
    matchElement(element) {
      return element.hasAttribute(this.attributeName);
    }
    matchElementsInTree(tree) {
      const match = this.matchElement(tree) ? [tree] : [];
      const matches = Array.from(tree.querySelectorAll(this.selector));
      return match.concat(matches);
    }
    elementMatched(element) {
      if (this.delegate.elementMatchedAttribute) {
        this.delegate.elementMatchedAttribute(element, this.attributeName);
      }
    }
    elementUnmatched(element) {
      if (this.delegate.elementUnmatchedAttribute) {
        this.delegate.elementUnmatchedAttribute(element, this.attributeName);
      }
    }
    elementAttributeChanged(element, attributeName) {
      if (this.delegate.elementAttributeValueChanged && this.attributeName == attributeName) {
        this.delegate.elementAttributeValueChanged(element, attributeName);
      }
    }
  };
  function add(map, key, value) {
    fetch2(map, key).add(value);
  }
  function del(map, key, value) {
    fetch2(map, key).delete(value);
    prune(map, key);
  }
  function fetch2(map, key) {
    let values = map.get(key);
    if (!values) {
      values = /* @__PURE__ */ new Set();
      map.set(key, values);
    }
    return values;
  }
  function prune(map, key) {
    const values = map.get(key);
    if (values != null && values.size == 0) {
      map.delete(key);
    }
  }
  var Multimap = class {
    constructor() {
      this.valuesByKey = /* @__PURE__ */ new Map();
    }
    get keys() {
      return Array.from(this.valuesByKey.keys());
    }
    get values() {
      const sets = Array.from(this.valuesByKey.values());
      return sets.reduce((values, set) => values.concat(Array.from(set)), []);
    }
    get size() {
      const sets = Array.from(this.valuesByKey.values());
      return sets.reduce((size, set) => size + set.size, 0);
    }
    add(key, value) {
      add(this.valuesByKey, key, value);
    }
    delete(key, value) {
      del(this.valuesByKey, key, value);
    }
    has(key, value) {
      const values = this.valuesByKey.get(key);
      return values != null && values.has(value);
    }
    hasKey(key) {
      return this.valuesByKey.has(key);
    }
    hasValue(value) {
      const sets = Array.from(this.valuesByKey.values());
      return sets.some((set) => set.has(value));
    }
    getValuesForKey(key) {
      const values = this.valuesByKey.get(key);
      return values ? Array.from(values) : [];
    }
    getKeysForValue(value) {
      return Array.from(this.valuesByKey).filter(([_key, values]) => values.has(value)).map(([key, _values]) => key);
    }
  };
  var SelectorObserver = class {
    constructor(element, selector, delegate, details) {
      this._selector = selector;
      this.details = details;
      this.elementObserver = new ElementObserver(element, this);
      this.delegate = delegate;
      this.matchesByElement = new Multimap();
    }
    get started() {
      return this.elementObserver.started;
    }
    get selector() {
      return this._selector;
    }
    set selector(selector) {
      this._selector = selector;
      this.refresh();
    }
    start() {
      this.elementObserver.start();
    }
    pause(callback) {
      this.elementObserver.pause(callback);
    }
    stop() {
      this.elementObserver.stop();
    }
    refresh() {
      this.elementObserver.refresh();
    }
    get element() {
      return this.elementObserver.element;
    }
    matchElement(element) {
      const { selector } = this;
      if (selector) {
        const matches = element.matches(selector);
        if (this.delegate.selectorMatchElement) {
          return matches && this.delegate.selectorMatchElement(element, this.details);
        }
        return matches;
      } else {
        return false;
      }
    }
    matchElementsInTree(tree) {
      const { selector } = this;
      if (selector) {
        const match = this.matchElement(tree) ? [tree] : [];
        const matches = Array.from(tree.querySelectorAll(selector)).filter((match2) => this.matchElement(match2));
        return match.concat(matches);
      } else {
        return [];
      }
    }
    elementMatched(element) {
      const { selector } = this;
      if (selector) {
        this.selectorMatched(element, selector);
      }
    }
    elementUnmatched(element) {
      const selectors = this.matchesByElement.getKeysForValue(element);
      for (const selector of selectors) {
        this.selectorUnmatched(element, selector);
      }
    }
    elementAttributeChanged(element, _attributeName) {
      const { selector } = this;
      if (selector) {
        const matches = this.matchElement(element);
        const matchedBefore = this.matchesByElement.has(selector, element);
        if (matches && !matchedBefore) {
          this.selectorMatched(element, selector);
        } else if (!matches && matchedBefore) {
          this.selectorUnmatched(element, selector);
        }
      }
    }
    selectorMatched(element, selector) {
      this.delegate.selectorMatched(element, selector, this.details);
      this.matchesByElement.add(selector, element);
    }
    selectorUnmatched(element, selector) {
      this.delegate.selectorUnmatched(element, selector, this.details);
      this.matchesByElement.delete(selector, element);
    }
  };
  var StringMapObserver = class {
    constructor(element, delegate) {
      this.element = element;
      this.delegate = delegate;
      this.started = false;
      this.stringMap = /* @__PURE__ */ new Map();
      this.mutationObserver = new MutationObserver((mutations) => this.processMutations(mutations));
    }
    start() {
      if (!this.started) {
        this.started = true;
        this.mutationObserver.observe(this.element, { attributes: true, attributeOldValue: true });
        this.refresh();
      }
    }
    stop() {
      if (this.started) {
        this.mutationObserver.takeRecords();
        this.mutationObserver.disconnect();
        this.started = false;
      }
    }
    refresh() {
      if (this.started) {
        for (const attributeName of this.knownAttributeNames) {
          this.refreshAttribute(attributeName, null);
        }
      }
    }
    processMutations(mutations) {
      if (this.started) {
        for (const mutation of mutations) {
          this.processMutation(mutation);
        }
      }
    }
    processMutation(mutation) {
      const attributeName = mutation.attributeName;
      if (attributeName) {
        this.refreshAttribute(attributeName, mutation.oldValue);
      }
    }
    refreshAttribute(attributeName, oldValue) {
      const key = this.delegate.getStringMapKeyForAttribute(attributeName);
      if (key != null) {
        if (!this.stringMap.has(attributeName)) {
          this.stringMapKeyAdded(key, attributeName);
        }
        const value = this.element.getAttribute(attributeName);
        if (this.stringMap.get(attributeName) != value) {
          this.stringMapValueChanged(value, key, oldValue);
        }
        if (value == null) {
          const oldValue2 = this.stringMap.get(attributeName);
          this.stringMap.delete(attributeName);
          if (oldValue2)
            this.stringMapKeyRemoved(key, attributeName, oldValue2);
        } else {
          this.stringMap.set(attributeName, value);
        }
      }
    }
    stringMapKeyAdded(key, attributeName) {
      if (this.delegate.stringMapKeyAdded) {
        this.delegate.stringMapKeyAdded(key, attributeName);
      }
    }
    stringMapValueChanged(value, key, oldValue) {
      if (this.delegate.stringMapValueChanged) {
        this.delegate.stringMapValueChanged(value, key, oldValue);
      }
    }
    stringMapKeyRemoved(key, attributeName, oldValue) {
      if (this.delegate.stringMapKeyRemoved) {
        this.delegate.stringMapKeyRemoved(key, attributeName, oldValue);
      }
    }
    get knownAttributeNames() {
      return Array.from(new Set(this.currentAttributeNames.concat(this.recordedAttributeNames)));
    }
    get currentAttributeNames() {
      return Array.from(this.element.attributes).map((attribute) => attribute.name);
    }
    get recordedAttributeNames() {
      return Array.from(this.stringMap.keys());
    }
  };
  var TokenListObserver = class {
    constructor(element, attributeName, delegate) {
      this.attributeObserver = new AttributeObserver(element, attributeName, this);
      this.delegate = delegate;
      this.tokensByElement = new Multimap();
    }
    get started() {
      return this.attributeObserver.started;
    }
    start() {
      this.attributeObserver.start();
    }
    pause(callback) {
      this.attributeObserver.pause(callback);
    }
    stop() {
      this.attributeObserver.stop();
    }
    refresh() {
      this.attributeObserver.refresh();
    }
    get element() {
      return this.attributeObserver.element;
    }
    get attributeName() {
      return this.attributeObserver.attributeName;
    }
    elementMatchedAttribute(element) {
      this.tokensMatched(this.readTokensForElement(element));
    }
    elementAttributeValueChanged(element) {
      const [unmatchedTokens, matchedTokens] = this.refreshTokensForElement(element);
      this.tokensUnmatched(unmatchedTokens);
      this.tokensMatched(matchedTokens);
    }
    elementUnmatchedAttribute(element) {
      this.tokensUnmatched(this.tokensByElement.getValuesForKey(element));
    }
    tokensMatched(tokens) {
      tokens.forEach((token) => this.tokenMatched(token));
    }
    tokensUnmatched(tokens) {
      tokens.forEach((token) => this.tokenUnmatched(token));
    }
    tokenMatched(token) {
      this.delegate.tokenMatched(token);
      this.tokensByElement.add(token.element, token);
    }
    tokenUnmatched(token) {
      this.delegate.tokenUnmatched(token);
      this.tokensByElement.delete(token.element, token);
    }
    refreshTokensForElement(element) {
      const previousTokens = this.tokensByElement.getValuesForKey(element);
      const currentTokens = this.readTokensForElement(element);
      const firstDifferingIndex = zip(previousTokens, currentTokens).findIndex(([previousToken, currentToken]) => !tokensAreEqual(previousToken, currentToken));
      if (firstDifferingIndex == -1) {
        return [[], []];
      } else {
        return [previousTokens.slice(firstDifferingIndex), currentTokens.slice(firstDifferingIndex)];
      }
    }
    readTokensForElement(element) {
      const attributeName = this.attributeName;
      const tokenString = element.getAttribute(attributeName) || "";
      return parseTokenString(tokenString, element, attributeName);
    }
  };
  function parseTokenString(tokenString, element, attributeName) {
    return tokenString.trim().split(/\s+/).filter((content) => content.length).map((content, index) => ({ element, attributeName, content, index }));
  }
  function zip(left2, right2) {
    const length = Math.max(left2.length, right2.length);
    return Array.from({ length }, (_, index) => [left2[index], right2[index]]);
  }
  function tokensAreEqual(left2, right2) {
    return left2 && right2 && left2.index == right2.index && left2.content == right2.content;
  }
  var ValueListObserver = class {
    constructor(element, attributeName, delegate) {
      this.tokenListObserver = new TokenListObserver(element, attributeName, this);
      this.delegate = delegate;
      this.parseResultsByToken = /* @__PURE__ */ new WeakMap();
      this.valuesByTokenByElement = /* @__PURE__ */ new WeakMap();
    }
    get started() {
      return this.tokenListObserver.started;
    }
    start() {
      this.tokenListObserver.start();
    }
    stop() {
      this.tokenListObserver.stop();
    }
    refresh() {
      this.tokenListObserver.refresh();
    }
    get element() {
      return this.tokenListObserver.element;
    }
    get attributeName() {
      return this.tokenListObserver.attributeName;
    }
    tokenMatched(token) {
      const { element } = token;
      const { value } = this.fetchParseResultForToken(token);
      if (value) {
        this.fetchValuesByTokenForElement(element).set(token, value);
        this.delegate.elementMatchedValue(element, value);
      }
    }
    tokenUnmatched(token) {
      const { element } = token;
      const { value } = this.fetchParseResultForToken(token);
      if (value) {
        this.fetchValuesByTokenForElement(element).delete(token);
        this.delegate.elementUnmatchedValue(element, value);
      }
    }
    fetchParseResultForToken(token) {
      let parseResult = this.parseResultsByToken.get(token);
      if (!parseResult) {
        parseResult = this.parseToken(token);
        this.parseResultsByToken.set(token, parseResult);
      }
      return parseResult;
    }
    fetchValuesByTokenForElement(element) {
      let valuesByToken = this.valuesByTokenByElement.get(element);
      if (!valuesByToken) {
        valuesByToken = /* @__PURE__ */ new Map();
        this.valuesByTokenByElement.set(element, valuesByToken);
      }
      return valuesByToken;
    }
    parseToken(token) {
      try {
        const value = this.delegate.parseValueForToken(token);
        return { value };
      } catch (error2) {
        return { error: error2 };
      }
    }
  };
  var BindingObserver = class {
    constructor(context, delegate) {
      this.context = context;
      this.delegate = delegate;
      this.bindingsByAction = /* @__PURE__ */ new Map();
    }
    start() {
      if (!this.valueListObserver) {
        this.valueListObserver = new ValueListObserver(this.element, this.actionAttribute, this);
        this.valueListObserver.start();
      }
    }
    stop() {
      if (this.valueListObserver) {
        this.valueListObserver.stop();
        delete this.valueListObserver;
        this.disconnectAllActions();
      }
    }
    get element() {
      return this.context.element;
    }
    get identifier() {
      return this.context.identifier;
    }
    get actionAttribute() {
      return this.schema.actionAttribute;
    }
    get schema() {
      return this.context.schema;
    }
    get bindings() {
      return Array.from(this.bindingsByAction.values());
    }
    connectAction(action) {
      const binding = new Binding(this.context, action);
      this.bindingsByAction.set(action, binding);
      this.delegate.bindingConnected(binding);
    }
    disconnectAction(action) {
      const binding = this.bindingsByAction.get(action);
      if (binding) {
        this.bindingsByAction.delete(action);
        this.delegate.bindingDisconnected(binding);
      }
    }
    disconnectAllActions() {
      this.bindings.forEach((binding) => this.delegate.bindingDisconnected(binding, true));
      this.bindingsByAction.clear();
    }
    parseValueForToken(token) {
      const action = Action.forToken(token, this.schema);
      if (action.identifier == this.identifier) {
        return action;
      }
    }
    elementMatchedValue(element, action) {
      this.connectAction(action);
    }
    elementUnmatchedValue(element, action) {
      this.disconnectAction(action);
    }
  };
  var ValueObserver = class {
    constructor(context, receiver) {
      this.context = context;
      this.receiver = receiver;
      this.stringMapObserver = new StringMapObserver(this.element, this);
      this.valueDescriptorMap = this.controller.valueDescriptorMap;
    }
    start() {
      this.stringMapObserver.start();
      this.invokeChangedCallbacksForDefaultValues();
    }
    stop() {
      this.stringMapObserver.stop();
    }
    get element() {
      return this.context.element;
    }
    get controller() {
      return this.context.controller;
    }
    getStringMapKeyForAttribute(attributeName) {
      if (attributeName in this.valueDescriptorMap) {
        return this.valueDescriptorMap[attributeName].name;
      }
    }
    stringMapKeyAdded(key, attributeName) {
      const descriptor = this.valueDescriptorMap[attributeName];
      if (!this.hasValue(key)) {
        this.invokeChangedCallback(key, descriptor.writer(this.receiver[key]), descriptor.writer(descriptor.defaultValue));
      }
    }
    stringMapValueChanged(value, name, oldValue) {
      const descriptor = this.valueDescriptorNameMap[name];
      if (value === null)
        return;
      if (oldValue === null) {
        oldValue = descriptor.writer(descriptor.defaultValue);
      }
      this.invokeChangedCallback(name, value, oldValue);
    }
    stringMapKeyRemoved(key, attributeName, oldValue) {
      const descriptor = this.valueDescriptorNameMap[key];
      if (this.hasValue(key)) {
        this.invokeChangedCallback(key, descriptor.writer(this.receiver[key]), oldValue);
      } else {
        this.invokeChangedCallback(key, descriptor.writer(descriptor.defaultValue), oldValue);
      }
    }
    invokeChangedCallbacksForDefaultValues() {
      for (const { key, name, defaultValue, writer } of this.valueDescriptors) {
        if (defaultValue != void 0 && !this.controller.data.has(key)) {
          this.invokeChangedCallback(name, writer(defaultValue), void 0);
        }
      }
    }
    invokeChangedCallback(name, rawValue, rawOldValue) {
      const changedMethodName = `${name}Changed`;
      const changedMethod = this.receiver[changedMethodName];
      if (typeof changedMethod == "function") {
        const descriptor = this.valueDescriptorNameMap[name];
        try {
          const value = descriptor.reader(rawValue);
          let oldValue = rawOldValue;
          if (rawOldValue) {
            oldValue = descriptor.reader(rawOldValue);
          }
          changedMethod.call(this.receiver, value, oldValue);
        } catch (error2) {
          if (error2 instanceof TypeError) {
            error2.message = `Stimulus Value "${this.context.identifier}.${descriptor.name}" - ${error2.message}`;
          }
          throw error2;
        }
      }
    }
    get valueDescriptors() {
      const { valueDescriptorMap } = this;
      return Object.keys(valueDescriptorMap).map((key) => valueDescriptorMap[key]);
    }
    get valueDescriptorNameMap() {
      const descriptors = {};
      Object.keys(this.valueDescriptorMap).forEach((key) => {
        const descriptor = this.valueDescriptorMap[key];
        descriptors[descriptor.name] = descriptor;
      });
      return descriptors;
    }
    hasValue(attributeName) {
      const descriptor = this.valueDescriptorNameMap[attributeName];
      const hasMethodName = `has${capitalize(descriptor.name)}`;
      return this.receiver[hasMethodName];
    }
  };
  var TargetObserver = class {
    constructor(context, delegate) {
      this.context = context;
      this.delegate = delegate;
      this.targetsByName = new Multimap();
    }
    start() {
      if (!this.tokenListObserver) {
        this.tokenListObserver = new TokenListObserver(this.element, this.attributeName, this);
        this.tokenListObserver.start();
      }
    }
    stop() {
      if (this.tokenListObserver) {
        this.disconnectAllTargets();
        this.tokenListObserver.stop();
        delete this.tokenListObserver;
      }
    }
    tokenMatched({ element, content: name }) {
      if (this.scope.containsElement(element)) {
        this.connectTarget(element, name);
      }
    }
    tokenUnmatched({ element, content: name }) {
      this.disconnectTarget(element, name);
    }
    connectTarget(element, name) {
      var _a;
      if (!this.targetsByName.has(name, element)) {
        this.targetsByName.add(name, element);
        (_a = this.tokenListObserver) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.targetConnected(element, name));
      }
    }
    disconnectTarget(element, name) {
      var _a;
      if (this.targetsByName.has(name, element)) {
        this.targetsByName.delete(name, element);
        (_a = this.tokenListObserver) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.targetDisconnected(element, name));
      }
    }
    disconnectAllTargets() {
      for (const name of this.targetsByName.keys) {
        for (const element of this.targetsByName.getValuesForKey(name)) {
          this.disconnectTarget(element, name);
        }
      }
    }
    get attributeName() {
      return `data-${this.context.identifier}-target`;
    }
    get element() {
      return this.context.element;
    }
    get scope() {
      return this.context.scope;
    }
  };
  function readInheritableStaticArrayValues(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return Array.from(ancestors.reduce((values, constructor2) => {
      getOwnStaticArrayValues(constructor2, propertyName).forEach((name) => values.add(name));
      return values;
    }, /* @__PURE__ */ new Set()));
  }
  function readInheritableStaticObjectPairs(constructor, propertyName) {
    const ancestors = getAncestorsForConstructor(constructor);
    return ancestors.reduce((pairs, constructor2) => {
      pairs.push(...getOwnStaticObjectPairs(constructor2, propertyName));
      return pairs;
    }, []);
  }
  function getAncestorsForConstructor(constructor) {
    const ancestors = [];
    while (constructor) {
      ancestors.push(constructor);
      constructor = Object.getPrototypeOf(constructor);
    }
    return ancestors.reverse();
  }
  function getOwnStaticArrayValues(constructor, propertyName) {
    const definition = constructor[propertyName];
    return Array.isArray(definition) ? definition : [];
  }
  function getOwnStaticObjectPairs(constructor, propertyName) {
    const definition = constructor[propertyName];
    return definition ? Object.keys(definition).map((key) => [key, definition[key]]) : [];
  }
  var OutletObserver = class {
    constructor(context, delegate) {
      this.started = false;
      this.context = context;
      this.delegate = delegate;
      this.outletsByName = new Multimap();
      this.outletElementsByName = new Multimap();
      this.selectorObserverMap = /* @__PURE__ */ new Map();
      this.attributeObserverMap = /* @__PURE__ */ new Map();
    }
    start() {
      if (!this.started) {
        this.outletDefinitions.forEach((outletName) => {
          this.setupSelectorObserverForOutlet(outletName);
          this.setupAttributeObserverForOutlet(outletName);
        });
        this.started = true;
        this.dependentContexts.forEach((context) => context.refresh());
      }
    }
    refresh() {
      this.selectorObserverMap.forEach((observer) => observer.refresh());
      this.attributeObserverMap.forEach((observer) => observer.refresh());
    }
    stop() {
      if (this.started) {
        this.started = false;
        this.disconnectAllOutlets();
        this.stopSelectorObservers();
        this.stopAttributeObservers();
      }
    }
    stopSelectorObservers() {
      if (this.selectorObserverMap.size > 0) {
        this.selectorObserverMap.forEach((observer) => observer.stop());
        this.selectorObserverMap.clear();
      }
    }
    stopAttributeObservers() {
      if (this.attributeObserverMap.size > 0) {
        this.attributeObserverMap.forEach((observer) => observer.stop());
        this.attributeObserverMap.clear();
      }
    }
    selectorMatched(element, _selector, { outletName }) {
      const outlet = this.getOutlet(element, outletName);
      if (outlet) {
        this.connectOutlet(outlet, element, outletName);
      }
    }
    selectorUnmatched(element, _selector, { outletName }) {
      const outlet = this.getOutletFromMap(element, outletName);
      if (outlet) {
        this.disconnectOutlet(outlet, element, outletName);
      }
    }
    selectorMatchElement(element, { outletName }) {
      const selector = this.selector(outletName);
      const hasOutlet = this.hasOutlet(element, outletName);
      const hasOutletController = element.matches(`[${this.schema.controllerAttribute}~=${outletName}]`);
      if (selector) {
        return hasOutlet && hasOutletController && element.matches(selector);
      } else {
        return false;
      }
    }
    elementMatchedAttribute(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    elementAttributeValueChanged(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    elementUnmatchedAttribute(_element, attributeName) {
      const outletName = this.getOutletNameFromOutletAttributeName(attributeName);
      if (outletName) {
        this.updateSelectorObserverForOutlet(outletName);
      }
    }
    connectOutlet(outlet, element, outletName) {
      var _a;
      if (!this.outletElementsByName.has(outletName, element)) {
        this.outletsByName.add(outletName, outlet);
        this.outletElementsByName.add(outletName, element);
        (_a = this.selectorObserverMap.get(outletName)) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.outletConnected(outlet, element, outletName));
      }
    }
    disconnectOutlet(outlet, element, outletName) {
      var _a;
      if (this.outletElementsByName.has(outletName, element)) {
        this.outletsByName.delete(outletName, outlet);
        this.outletElementsByName.delete(outletName, element);
        (_a = this.selectorObserverMap.get(outletName)) === null || _a === void 0 ? void 0 : _a.pause(() => this.delegate.outletDisconnected(outlet, element, outletName));
      }
    }
    disconnectAllOutlets() {
      for (const outletName of this.outletElementsByName.keys) {
        for (const element of this.outletElementsByName.getValuesForKey(outletName)) {
          for (const outlet of this.outletsByName.getValuesForKey(outletName)) {
            this.disconnectOutlet(outlet, element, outletName);
          }
        }
      }
    }
    updateSelectorObserverForOutlet(outletName) {
      const observer = this.selectorObserverMap.get(outletName);
      if (observer) {
        observer.selector = this.selector(outletName);
      }
    }
    setupSelectorObserverForOutlet(outletName) {
      const selector = this.selector(outletName);
      const selectorObserver = new SelectorObserver(document.body, selector, this, { outletName });
      this.selectorObserverMap.set(outletName, selectorObserver);
      selectorObserver.start();
    }
    setupAttributeObserverForOutlet(outletName) {
      const attributeName = this.attributeNameForOutletName(outletName);
      const attributeObserver = new AttributeObserver(this.scope.element, attributeName, this);
      this.attributeObserverMap.set(outletName, attributeObserver);
      attributeObserver.start();
    }
    selector(outletName) {
      return this.scope.outlets.getSelectorForOutletName(outletName);
    }
    attributeNameForOutletName(outletName) {
      return this.scope.schema.outletAttributeForScope(this.identifier, outletName);
    }
    getOutletNameFromOutletAttributeName(attributeName) {
      return this.outletDefinitions.find((outletName) => this.attributeNameForOutletName(outletName) === attributeName);
    }
    get outletDependencies() {
      const dependencies = new Multimap();
      this.router.modules.forEach((module) => {
        const constructor = module.definition.controllerConstructor;
        const outlets = readInheritableStaticArrayValues(constructor, "outlets");
        outlets.forEach((outlet) => dependencies.add(outlet, module.identifier));
      });
      return dependencies;
    }
    get outletDefinitions() {
      return this.outletDependencies.getKeysForValue(this.identifier);
    }
    get dependentControllerIdentifiers() {
      return this.outletDependencies.getValuesForKey(this.identifier);
    }
    get dependentContexts() {
      const identifiers = this.dependentControllerIdentifiers;
      return this.router.contexts.filter((context) => identifiers.includes(context.identifier));
    }
    hasOutlet(element, outletName) {
      return !!this.getOutlet(element, outletName) || !!this.getOutletFromMap(element, outletName);
    }
    getOutlet(element, outletName) {
      return this.application.getControllerForElementAndIdentifier(element, outletName);
    }
    getOutletFromMap(element, outletName) {
      return this.outletsByName.getValuesForKey(outletName).find((outlet) => outlet.element === element);
    }
    get scope() {
      return this.context.scope;
    }
    get schema() {
      return this.context.schema;
    }
    get identifier() {
      return this.context.identifier;
    }
    get application() {
      return this.context.application;
    }
    get router() {
      return this.application.router;
    }
  };
  var Context = class {
    constructor(module, scope) {
      this.logDebugActivity = (functionName, detail = {}) => {
        const { identifier, controller, element } = this;
        detail = Object.assign({ identifier, controller, element }, detail);
        this.application.logDebugActivity(this.identifier, functionName, detail);
      };
      this.module = module;
      this.scope = scope;
      this.controller = new module.controllerConstructor(this);
      this.bindingObserver = new BindingObserver(this, this.dispatcher);
      this.valueObserver = new ValueObserver(this, this.controller);
      this.targetObserver = new TargetObserver(this, this);
      this.outletObserver = new OutletObserver(this, this);
      try {
        this.controller.initialize();
        this.logDebugActivity("initialize");
      } catch (error2) {
        this.handleError(error2, "initializing controller");
      }
    }
    connect() {
      this.bindingObserver.start();
      this.valueObserver.start();
      this.targetObserver.start();
      this.outletObserver.start();
      try {
        this.controller.connect();
        this.logDebugActivity("connect");
      } catch (error2) {
        this.handleError(error2, "connecting controller");
      }
    }
    refresh() {
      this.outletObserver.refresh();
    }
    disconnect() {
      try {
        this.controller.disconnect();
        this.logDebugActivity("disconnect");
      } catch (error2) {
        this.handleError(error2, "disconnecting controller");
      }
      this.outletObserver.stop();
      this.targetObserver.stop();
      this.valueObserver.stop();
      this.bindingObserver.stop();
    }
    get application() {
      return this.module.application;
    }
    get identifier() {
      return this.module.identifier;
    }
    get schema() {
      return this.application.schema;
    }
    get dispatcher() {
      return this.application.dispatcher;
    }
    get element() {
      return this.scope.element;
    }
    get parentElement() {
      return this.element.parentElement;
    }
    handleError(error2, message, detail = {}) {
      const { identifier, controller, element } = this;
      detail = Object.assign({ identifier, controller, element }, detail);
      this.application.handleError(error2, `Error ${message}`, detail);
    }
    targetConnected(element, name) {
      this.invokeControllerMethod(`${name}TargetConnected`, element);
    }
    targetDisconnected(element, name) {
      this.invokeControllerMethod(`${name}TargetDisconnected`, element);
    }
    outletConnected(outlet, element, name) {
      this.invokeControllerMethod(`${namespaceCamelize(name)}OutletConnected`, outlet, element);
    }
    outletDisconnected(outlet, element, name) {
      this.invokeControllerMethod(`${namespaceCamelize(name)}OutletDisconnected`, outlet, element);
    }
    invokeControllerMethod(methodName, ...args) {
      const controller = this.controller;
      if (typeof controller[methodName] == "function") {
        controller[methodName](...args);
      }
    }
  };
  function bless(constructor) {
    return shadow(constructor, getBlessedProperties(constructor));
  }
  function shadow(constructor, properties) {
    const shadowConstructor = extend2(constructor);
    const shadowProperties = getShadowProperties(constructor.prototype, properties);
    Object.defineProperties(shadowConstructor.prototype, shadowProperties);
    return shadowConstructor;
  }
  function getBlessedProperties(constructor) {
    const blessings = readInheritableStaticArrayValues(constructor, "blessings");
    return blessings.reduce((blessedProperties, blessing) => {
      const properties = blessing(constructor);
      for (const key in properties) {
        const descriptor = blessedProperties[key] || {};
        blessedProperties[key] = Object.assign(descriptor, properties[key]);
      }
      return blessedProperties;
    }, {});
  }
  function getShadowProperties(prototype, properties) {
    return getOwnKeys(properties).reduce((shadowProperties, key) => {
      const descriptor = getShadowedDescriptor(prototype, properties, key);
      if (descriptor) {
        Object.assign(shadowProperties, { [key]: descriptor });
      }
      return shadowProperties;
    }, {});
  }
  function getShadowedDescriptor(prototype, properties, key) {
    const shadowingDescriptor = Object.getOwnPropertyDescriptor(prototype, key);
    const shadowedByValue = shadowingDescriptor && "value" in shadowingDescriptor;
    if (!shadowedByValue) {
      const descriptor = Object.getOwnPropertyDescriptor(properties, key).value;
      if (shadowingDescriptor) {
        descriptor.get = shadowingDescriptor.get || descriptor.get;
        descriptor.set = shadowingDescriptor.set || descriptor.set;
      }
      return descriptor;
    }
  }
  var getOwnKeys = (() => {
    if (typeof Object.getOwnPropertySymbols == "function") {
      return (object) => [...Object.getOwnPropertyNames(object), ...Object.getOwnPropertySymbols(object)];
    } else {
      return Object.getOwnPropertyNames;
    }
  })();
  var extend2 = (() => {
    function extendWithReflect(constructor) {
      function extended() {
        return Reflect.construct(constructor, arguments, new.target);
      }
      extended.prototype = Object.create(constructor.prototype, {
        constructor: { value: extended }
      });
      Reflect.setPrototypeOf(extended, constructor);
      return extended;
    }
    function testReflectExtension() {
      const a = function() {
        this.a.call(this);
      };
      const b = extendWithReflect(a);
      b.prototype.a = function() {
      };
      return new b();
    }
    try {
      testReflectExtension();
      return extendWithReflect;
    } catch (error2) {
      return (constructor) => class extended extends constructor {
      };
    }
  })();
  function blessDefinition(definition) {
    return {
      identifier: definition.identifier,
      controllerConstructor: bless(definition.controllerConstructor)
    };
  }
  var Module = class {
    constructor(application2, definition) {
      this.application = application2;
      this.definition = blessDefinition(definition);
      this.contextsByScope = /* @__PURE__ */ new WeakMap();
      this.connectedContexts = /* @__PURE__ */ new Set();
    }
    get identifier() {
      return this.definition.identifier;
    }
    get controllerConstructor() {
      return this.definition.controllerConstructor;
    }
    get contexts() {
      return Array.from(this.connectedContexts);
    }
    connectContextForScope(scope) {
      const context = this.fetchContextForScope(scope);
      this.connectedContexts.add(context);
      context.connect();
    }
    disconnectContextForScope(scope) {
      const context = this.contextsByScope.get(scope);
      if (context) {
        this.connectedContexts.delete(context);
        context.disconnect();
      }
    }
    fetchContextForScope(scope) {
      let context = this.contextsByScope.get(scope);
      if (!context) {
        context = new Context(this, scope);
        this.contextsByScope.set(scope, context);
      }
      return context;
    }
  };
  var ClassMap = class {
    constructor(scope) {
      this.scope = scope;
    }
    has(name) {
      return this.data.has(this.getDataKey(name));
    }
    get(name) {
      return this.getAll(name)[0];
    }
    getAll(name) {
      const tokenString = this.data.get(this.getDataKey(name)) || "";
      return tokenize(tokenString);
    }
    getAttributeName(name) {
      return this.data.getAttributeNameForKey(this.getDataKey(name));
    }
    getDataKey(name) {
      return `${name}-class`;
    }
    get data() {
      return this.scope.data;
    }
  };
  var DataMap = class {
    constructor(scope) {
      this.scope = scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get(key) {
      const name = this.getAttributeNameForKey(key);
      return this.element.getAttribute(name);
    }
    set(key, value) {
      const name = this.getAttributeNameForKey(key);
      this.element.setAttribute(name, value);
      return this.get(key);
    }
    has(key) {
      const name = this.getAttributeNameForKey(key);
      return this.element.hasAttribute(name);
    }
    delete(key) {
      if (this.has(key)) {
        const name = this.getAttributeNameForKey(key);
        this.element.removeAttribute(name);
        return true;
      } else {
        return false;
      }
    }
    getAttributeNameForKey(key) {
      return `data-${this.identifier}-${dasherize(key)}`;
    }
  };
  var Guide = class {
    constructor(logger) {
      this.warnedKeysByObject = /* @__PURE__ */ new WeakMap();
      this.logger = logger;
    }
    warn(object, key, message) {
      let warnedKeys = this.warnedKeysByObject.get(object);
      if (!warnedKeys) {
        warnedKeys = /* @__PURE__ */ new Set();
        this.warnedKeysByObject.set(object, warnedKeys);
      }
      if (!warnedKeys.has(key)) {
        warnedKeys.add(key);
        this.logger.warn(message, object);
      }
    }
  };
  function attributeValueContainsToken(attributeName, token) {
    return `[${attributeName}~="${token}"]`;
  }
  var TargetSet = class {
    constructor(scope) {
      this.scope = scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get schema() {
      return this.scope.schema;
    }
    has(targetName) {
      return this.find(targetName) != null;
    }
    find(...targetNames) {
      return targetNames.reduce((target, targetName) => target || this.findTarget(targetName) || this.findLegacyTarget(targetName), void 0);
    }
    findAll(...targetNames) {
      return targetNames.reduce((targets, targetName) => [
        ...targets,
        ...this.findAllTargets(targetName),
        ...this.findAllLegacyTargets(targetName)
      ], []);
    }
    findTarget(targetName) {
      const selector = this.getSelectorForTargetName(targetName);
      return this.scope.findElement(selector);
    }
    findAllTargets(targetName) {
      const selector = this.getSelectorForTargetName(targetName);
      return this.scope.findAllElements(selector);
    }
    getSelectorForTargetName(targetName) {
      const attributeName = this.schema.targetAttributeForScope(this.identifier);
      return attributeValueContainsToken(attributeName, targetName);
    }
    findLegacyTarget(targetName) {
      const selector = this.getLegacySelectorForTargetName(targetName);
      return this.deprecate(this.scope.findElement(selector), targetName);
    }
    findAllLegacyTargets(targetName) {
      const selector = this.getLegacySelectorForTargetName(targetName);
      return this.scope.findAllElements(selector).map((element) => this.deprecate(element, targetName));
    }
    getLegacySelectorForTargetName(targetName) {
      const targetDescriptor = `${this.identifier}.${targetName}`;
      return attributeValueContainsToken(this.schema.targetAttribute, targetDescriptor);
    }
    deprecate(element, targetName) {
      if (element) {
        const { identifier } = this;
        const attributeName = this.schema.targetAttribute;
        const revisedAttributeName = this.schema.targetAttributeForScope(identifier);
        this.guide.warn(element, `target:${targetName}`, `Please replace ${attributeName}="${identifier}.${targetName}" with ${revisedAttributeName}="${targetName}". The ${attributeName} attribute is deprecated and will be removed in a future version of Stimulus.`);
      }
      return element;
    }
    get guide() {
      return this.scope.guide;
    }
  };
  var OutletSet = class {
    constructor(scope, controllerElement) {
      this.scope = scope;
      this.controllerElement = controllerElement;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get schema() {
      return this.scope.schema;
    }
    has(outletName) {
      return this.find(outletName) != null;
    }
    find(...outletNames) {
      return outletNames.reduce((outlet, outletName) => outlet || this.findOutlet(outletName), void 0);
    }
    findAll(...outletNames) {
      return outletNames.reduce((outlets, outletName) => [...outlets, ...this.findAllOutlets(outletName)], []);
    }
    getSelectorForOutletName(outletName) {
      const attributeName = this.schema.outletAttributeForScope(this.identifier, outletName);
      return this.controllerElement.getAttribute(attributeName);
    }
    findOutlet(outletName) {
      const selector = this.getSelectorForOutletName(outletName);
      if (selector)
        return this.findElement(selector, outletName);
    }
    findAllOutlets(outletName) {
      const selector = this.getSelectorForOutletName(outletName);
      return selector ? this.findAllElements(selector, outletName) : [];
    }
    findElement(selector, outletName) {
      const elements = this.scope.queryElements(selector);
      return elements.filter((element) => this.matchesElement(element, selector, outletName))[0];
    }
    findAllElements(selector, outletName) {
      const elements = this.scope.queryElements(selector);
      return elements.filter((element) => this.matchesElement(element, selector, outletName));
    }
    matchesElement(element, selector, outletName) {
      const controllerAttribute = element.getAttribute(this.scope.schema.controllerAttribute) || "";
      return element.matches(selector) && controllerAttribute.split(" ").includes(outletName);
    }
  };
  var Scope = class {
    constructor(schema, element, identifier, logger) {
      this.targets = new TargetSet(this);
      this.classes = new ClassMap(this);
      this.data = new DataMap(this);
      this.containsElement = (element2) => {
        return element2.closest(this.controllerSelector) === this.element;
      };
      this.schema = schema;
      this.element = element;
      this.identifier = identifier;
      this.guide = new Guide(logger);
      this.outlets = new OutletSet(this.documentScope, element);
    }
    findElement(selector) {
      return this.element.matches(selector) ? this.element : this.queryElements(selector).find(this.containsElement);
    }
    findAllElements(selector) {
      return [
        ...this.element.matches(selector) ? [this.element] : [],
        ...this.queryElements(selector).filter(this.containsElement)
      ];
    }
    queryElements(selector) {
      return Array.from(this.element.querySelectorAll(selector));
    }
    get controllerSelector() {
      return attributeValueContainsToken(this.schema.controllerAttribute, this.identifier);
    }
    get isDocumentScope() {
      return this.element === document.documentElement;
    }
    get documentScope() {
      return this.isDocumentScope ? this : new Scope(this.schema, document.documentElement, this.identifier, this.guide.logger);
    }
  };
  var ScopeObserver = class {
    constructor(element, schema, delegate) {
      this.element = element;
      this.schema = schema;
      this.delegate = delegate;
      this.valueListObserver = new ValueListObserver(this.element, this.controllerAttribute, this);
      this.scopesByIdentifierByElement = /* @__PURE__ */ new WeakMap();
      this.scopeReferenceCounts = /* @__PURE__ */ new WeakMap();
    }
    start() {
      this.valueListObserver.start();
    }
    stop() {
      this.valueListObserver.stop();
    }
    get controllerAttribute() {
      return this.schema.controllerAttribute;
    }
    parseValueForToken(token) {
      const { element, content: identifier } = token;
      return this.parseValueForElementAndIdentifier(element, identifier);
    }
    parseValueForElementAndIdentifier(element, identifier) {
      const scopesByIdentifier = this.fetchScopesByIdentifierForElement(element);
      let scope = scopesByIdentifier.get(identifier);
      if (!scope) {
        scope = this.delegate.createScopeForElementAndIdentifier(element, identifier);
        scopesByIdentifier.set(identifier, scope);
      }
      return scope;
    }
    elementMatchedValue(element, value) {
      const referenceCount = (this.scopeReferenceCounts.get(value) || 0) + 1;
      this.scopeReferenceCounts.set(value, referenceCount);
      if (referenceCount == 1) {
        this.delegate.scopeConnected(value);
      }
    }
    elementUnmatchedValue(element, value) {
      const referenceCount = this.scopeReferenceCounts.get(value);
      if (referenceCount) {
        this.scopeReferenceCounts.set(value, referenceCount - 1);
        if (referenceCount == 1) {
          this.delegate.scopeDisconnected(value);
        }
      }
    }
    fetchScopesByIdentifierForElement(element) {
      let scopesByIdentifier = this.scopesByIdentifierByElement.get(element);
      if (!scopesByIdentifier) {
        scopesByIdentifier = /* @__PURE__ */ new Map();
        this.scopesByIdentifierByElement.set(element, scopesByIdentifier);
      }
      return scopesByIdentifier;
    }
  };
  var Router = class {
    constructor(application2) {
      this.application = application2;
      this.scopeObserver = new ScopeObserver(this.element, this.schema, this);
      this.scopesByIdentifier = new Multimap();
      this.modulesByIdentifier = /* @__PURE__ */ new Map();
    }
    get element() {
      return this.application.element;
    }
    get schema() {
      return this.application.schema;
    }
    get logger() {
      return this.application.logger;
    }
    get controllerAttribute() {
      return this.schema.controllerAttribute;
    }
    get modules() {
      return Array.from(this.modulesByIdentifier.values());
    }
    get contexts() {
      return this.modules.reduce((contexts, module) => contexts.concat(module.contexts), []);
    }
    start() {
      this.scopeObserver.start();
    }
    stop() {
      this.scopeObserver.stop();
    }
    loadDefinition(definition) {
      this.unloadIdentifier(definition.identifier);
      const module = new Module(this.application, definition);
      this.connectModule(module);
      const afterLoad = definition.controllerConstructor.afterLoad;
      if (afterLoad) {
        afterLoad.call(definition.controllerConstructor, definition.identifier, this.application);
      }
    }
    unloadIdentifier(identifier) {
      const module = this.modulesByIdentifier.get(identifier);
      if (module) {
        this.disconnectModule(module);
      }
    }
    getContextForElementAndIdentifier(element, identifier) {
      const module = this.modulesByIdentifier.get(identifier);
      if (module) {
        return module.contexts.find((context) => context.element == element);
      }
    }
    proposeToConnectScopeForElementAndIdentifier(element, identifier) {
      const scope = this.scopeObserver.parseValueForElementAndIdentifier(element, identifier);
      if (scope) {
        this.scopeObserver.elementMatchedValue(scope.element, scope);
      } else {
        console.error(`Couldn't find or create scope for identifier: "${identifier}" and element:`, element);
      }
    }
    handleError(error2, message, detail) {
      this.application.handleError(error2, message, detail);
    }
    createScopeForElementAndIdentifier(element, identifier) {
      return new Scope(this.schema, element, identifier, this.logger);
    }
    scopeConnected(scope) {
      this.scopesByIdentifier.add(scope.identifier, scope);
      const module = this.modulesByIdentifier.get(scope.identifier);
      if (module) {
        module.connectContextForScope(scope);
      }
    }
    scopeDisconnected(scope) {
      this.scopesByIdentifier.delete(scope.identifier, scope);
      const module = this.modulesByIdentifier.get(scope.identifier);
      if (module) {
        module.disconnectContextForScope(scope);
      }
    }
    connectModule(module) {
      this.modulesByIdentifier.set(module.identifier, module);
      const scopes = this.scopesByIdentifier.getValuesForKey(module.identifier);
      scopes.forEach((scope) => module.connectContextForScope(scope));
    }
    disconnectModule(module) {
      this.modulesByIdentifier.delete(module.identifier);
      const scopes = this.scopesByIdentifier.getValuesForKey(module.identifier);
      scopes.forEach((scope) => module.disconnectContextForScope(scope));
    }
  };
  var defaultSchema = {
    controllerAttribute: "data-controller",
    actionAttribute: "data-action",
    targetAttribute: "data-target",
    targetAttributeForScope: (identifier) => `data-${identifier}-target`,
    outletAttributeForScope: (identifier, outlet) => `data-${identifier}-${outlet}-outlet`,
    keyMappings: Object.assign(Object.assign({ enter: "Enter", tab: "Tab", esc: "Escape", space: " ", up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight", home: "Home", end: "End", page_up: "PageUp", page_down: "PageDown" }, objectFromEntries("abcdefghijklmnopqrstuvwxyz".split("").map((c) => [c, c]))), objectFromEntries("0123456789".split("").map((n) => [n, n])))
  };
  function objectFromEntries(array) {
    return array.reduce((memo, [k, v]) => Object.assign(Object.assign({}, memo), { [k]: v }), {});
  }
  var Application = class {
    constructor(element = document.documentElement, schema = defaultSchema) {
      this.logger = console;
      this.debug = false;
      this.logDebugActivity = (identifier, functionName, detail = {}) => {
        if (this.debug) {
          this.logFormattedMessage(identifier, functionName, detail);
        }
      };
      this.element = element;
      this.schema = schema;
      this.dispatcher = new Dispatcher(this);
      this.router = new Router(this);
      this.actionDescriptorFilters = Object.assign({}, defaultActionDescriptorFilters);
    }
    static start(element, schema) {
      const application2 = new this(element, schema);
      application2.start();
      return application2;
    }
    async start() {
      await domReady();
      this.logDebugActivity("application", "starting");
      this.dispatcher.start();
      this.router.start();
      this.logDebugActivity("application", "start");
    }
    stop() {
      this.logDebugActivity("application", "stopping");
      this.dispatcher.stop();
      this.router.stop();
      this.logDebugActivity("application", "stop");
    }
    register(identifier, controllerConstructor) {
      this.load({ identifier, controllerConstructor });
    }
    registerActionOption(name, filter) {
      this.actionDescriptorFilters[name] = filter;
    }
    load(head, ...rest) {
      const definitions = Array.isArray(head) ? head : [head, ...rest];
      definitions.forEach((definition) => {
        if (definition.controllerConstructor.shouldLoad) {
          this.router.loadDefinition(definition);
        }
      });
    }
    unload(head, ...rest) {
      const identifiers = Array.isArray(head) ? head : [head, ...rest];
      identifiers.forEach((identifier) => this.router.unloadIdentifier(identifier));
    }
    get controllers() {
      return this.router.contexts.map((context) => context.controller);
    }
    getControllerForElementAndIdentifier(element, identifier) {
      const context = this.router.getContextForElementAndIdentifier(element, identifier);
      return context ? context.controller : null;
    }
    handleError(error2, message, detail) {
      var _a;
      this.logger.error(`%s

%o

%o`, message, error2, detail);
      (_a = window.onerror) === null || _a === void 0 ? void 0 : _a.call(window, message, "", 0, 0, error2);
    }
    logFormattedMessage(identifier, functionName, detail = {}) {
      detail = Object.assign({ application: this }, detail);
      this.logger.groupCollapsed(`${identifier} #${functionName}`);
      this.logger.log("details:", Object.assign({}, detail));
      this.logger.groupEnd();
    }
  };
  function domReady() {
    return new Promise((resolve) => {
      if (document.readyState == "loading") {
        document.addEventListener("DOMContentLoaded", () => resolve());
      } else {
        resolve();
      }
    });
  }
  function ClassPropertiesBlessing(constructor) {
    const classes = readInheritableStaticArrayValues(constructor, "classes");
    return classes.reduce((properties, classDefinition) => {
      return Object.assign(properties, propertiesForClassDefinition(classDefinition));
    }, {});
  }
  function propertiesForClassDefinition(key) {
    return {
      [`${key}Class`]: {
        get() {
          const { classes } = this;
          if (classes.has(key)) {
            return classes.get(key);
          } else {
            const attribute = classes.getAttributeName(key);
            throw new Error(`Missing attribute "${attribute}"`);
          }
        }
      },
      [`${key}Classes`]: {
        get() {
          return this.classes.getAll(key);
        }
      },
      [`has${capitalize(key)}Class`]: {
        get() {
          return this.classes.has(key);
        }
      }
    };
  }
  function OutletPropertiesBlessing(constructor) {
    const outlets = readInheritableStaticArrayValues(constructor, "outlets");
    return outlets.reduce((properties, outletDefinition) => {
      return Object.assign(properties, propertiesForOutletDefinition(outletDefinition));
    }, {});
  }
  function getOutletController(controller, element, identifier) {
    return controller.application.getControllerForElementAndIdentifier(element, identifier);
  }
  function getControllerAndEnsureConnectedScope(controller, element, outletName) {
    let outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
    controller.application.router.proposeToConnectScopeForElementAndIdentifier(element, outletName);
    outletController = getOutletController(controller, element, outletName);
    if (outletController)
      return outletController;
  }
  function propertiesForOutletDefinition(name) {
    const camelizedName = namespaceCamelize(name);
    return {
      [`${camelizedName}Outlet`]: {
        get() {
          const outletElement = this.outlets.find(name);
          const selector = this.outlets.getSelectorForOutletName(name);
          if (outletElement) {
            const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name);
            if (outletController)
              return outletController;
            throw new Error(`The provided outlet element is missing an outlet controller "${name}" instance for host controller "${this.identifier}"`);
          }
          throw new Error(`Missing outlet element "${name}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
        }
      },
      [`${camelizedName}Outlets`]: {
        get() {
          const outlets = this.outlets.findAll(name);
          if (outlets.length > 0) {
            return outlets.map((outletElement) => {
              const outletController = getControllerAndEnsureConnectedScope(this, outletElement, name);
              if (outletController)
                return outletController;
              console.warn(`The provided outlet element is missing an outlet controller "${name}" instance for host controller "${this.identifier}"`, outletElement);
            }).filter((controller) => controller);
          }
          return [];
        }
      },
      [`${camelizedName}OutletElement`]: {
        get() {
          const outletElement = this.outlets.find(name);
          const selector = this.outlets.getSelectorForOutletName(name);
          if (outletElement) {
            return outletElement;
          } else {
            throw new Error(`Missing outlet element "${name}" for host controller "${this.identifier}". Stimulus couldn't find a matching outlet element using selector "${selector}".`);
          }
        }
      },
      [`${camelizedName}OutletElements`]: {
        get() {
          return this.outlets.findAll(name);
        }
      },
      [`has${capitalize(camelizedName)}Outlet`]: {
        get() {
          return this.outlets.has(name);
        }
      }
    };
  }
  function TargetPropertiesBlessing(constructor) {
    const targets = readInheritableStaticArrayValues(constructor, "targets");
    return targets.reduce((properties, targetDefinition) => {
      return Object.assign(properties, propertiesForTargetDefinition(targetDefinition));
    }, {});
  }
  function propertiesForTargetDefinition(name) {
    return {
      [`${name}Target`]: {
        get() {
          const target = this.targets.find(name);
          if (target) {
            return target;
          } else {
            throw new Error(`Missing target element "${name}" for "${this.identifier}" controller`);
          }
        }
      },
      [`${name}Targets`]: {
        get() {
          return this.targets.findAll(name);
        }
      },
      [`has${capitalize(name)}Target`]: {
        get() {
          return this.targets.has(name);
        }
      }
    };
  }
  function ValuePropertiesBlessing(constructor) {
    const valueDefinitionPairs = readInheritableStaticObjectPairs(constructor, "values");
    const propertyDescriptorMap = {
      valueDescriptorMap: {
        get() {
          return valueDefinitionPairs.reduce((result, valueDefinitionPair) => {
            const valueDescriptor = parseValueDefinitionPair(valueDefinitionPair, this.identifier);
            const attributeName = this.data.getAttributeNameForKey(valueDescriptor.key);
            return Object.assign(result, { [attributeName]: valueDescriptor });
          }, {});
        }
      }
    };
    return valueDefinitionPairs.reduce((properties, valueDefinitionPair) => {
      return Object.assign(properties, propertiesForValueDefinitionPair(valueDefinitionPair));
    }, propertyDescriptorMap);
  }
  function propertiesForValueDefinitionPair(valueDefinitionPair, controller) {
    const definition = parseValueDefinitionPair(valueDefinitionPair, controller);
    const { key, name, reader: read2, writer: write2 } = definition;
    return {
      [name]: {
        get() {
          const value = this.data.get(key);
          if (value !== null) {
            return read2(value);
          } else {
            return definition.defaultValue;
          }
        },
        set(value) {
          if (value === void 0) {
            this.data.delete(key);
          } else {
            this.data.set(key, write2(value));
          }
        }
      },
      [`has${capitalize(name)}`]: {
        get() {
          return this.data.has(key) || definition.hasCustomDefaultValue;
        }
      }
    };
  }
  function parseValueDefinitionPair([token, typeDefinition], controller) {
    return valueDescriptorForTokenAndTypeDefinition({
      controller,
      token,
      typeDefinition
    });
  }
  function parseValueTypeConstant(constant) {
    switch (constant) {
      case Array:
        return "array";
      case Boolean:
        return "boolean";
      case Number:
        return "number";
      case Object:
        return "object";
      case String:
        return "string";
    }
  }
  function parseValueTypeDefault(defaultValue) {
    switch (typeof defaultValue) {
      case "boolean":
        return "boolean";
      case "number":
        return "number";
      case "string":
        return "string";
    }
    if (Array.isArray(defaultValue))
      return "array";
    if (Object.prototype.toString.call(defaultValue) === "[object Object]")
      return "object";
  }
  function parseValueTypeObject(payload) {
    const { controller, token, typeObject } = payload;
    const hasType = isSomething(typeObject.type);
    const hasDefault = isSomething(typeObject.default);
    const fullObject = hasType && hasDefault;
    const onlyType = hasType && !hasDefault;
    const onlyDefault = !hasType && hasDefault;
    const typeFromObject = parseValueTypeConstant(typeObject.type);
    const typeFromDefaultValue = parseValueTypeDefault(payload.typeObject.default);
    if (onlyType)
      return typeFromObject;
    if (onlyDefault)
      return typeFromDefaultValue;
    if (typeFromObject !== typeFromDefaultValue) {
      const propertyPath = controller ? `${controller}.${token}` : token;
      throw new Error(`The specified default value for the Stimulus Value "${propertyPath}" must match the defined type "${typeFromObject}". The provided default value of "${typeObject.default}" is of type "${typeFromDefaultValue}".`);
    }
    if (fullObject)
      return typeFromObject;
  }
  function parseValueTypeDefinition(payload) {
    const { controller, token, typeDefinition } = payload;
    const typeObject = { controller, token, typeObject: typeDefinition };
    const typeFromObject = parseValueTypeObject(typeObject);
    const typeFromDefaultValue = parseValueTypeDefault(typeDefinition);
    const typeFromConstant = parseValueTypeConstant(typeDefinition);
    const type = typeFromObject || typeFromDefaultValue || typeFromConstant;
    if (type)
      return type;
    const propertyPath = controller ? `${controller}.${typeDefinition}` : token;
    throw new Error(`Unknown value type "${propertyPath}" for "${token}" value`);
  }
  function defaultValueForDefinition(typeDefinition) {
    const constant = parseValueTypeConstant(typeDefinition);
    if (constant)
      return defaultValuesByType[constant];
    const hasDefault = hasProperty(typeDefinition, "default");
    const hasType = hasProperty(typeDefinition, "type");
    const typeObject = typeDefinition;
    if (hasDefault)
      return typeObject.default;
    if (hasType) {
      const { type } = typeObject;
      const constantFromType = parseValueTypeConstant(type);
      if (constantFromType)
        return defaultValuesByType[constantFromType];
    }
    return typeDefinition;
  }
  function valueDescriptorForTokenAndTypeDefinition(payload) {
    const { token, typeDefinition } = payload;
    const key = `${dasherize(token)}-value`;
    const type = parseValueTypeDefinition(payload);
    return {
      type,
      key,
      name: camelize(key),
      get defaultValue() {
        return defaultValueForDefinition(typeDefinition);
      },
      get hasCustomDefaultValue() {
        return parseValueTypeDefault(typeDefinition) !== void 0;
      },
      reader: readers[type],
      writer: writers[type] || writers.default
    };
  }
  var defaultValuesByType = {
    get array() {
      return [];
    },
    boolean: false,
    number: 0,
    get object() {
      return {};
    },
    string: ""
  };
  var readers = {
    array(value) {
      const array = JSON.parse(value);
      if (!Array.isArray(array)) {
        throw new TypeError(`expected value of type "array" but instead got value "${value}" of type "${parseValueTypeDefault(array)}"`);
      }
      return array;
    },
    boolean(value) {
      return !(value == "0" || String(value).toLowerCase() == "false");
    },
    number(value) {
      return Number(value.replace(/_/g, ""));
    },
    object(value) {
      const object = JSON.parse(value);
      if (object === null || typeof object != "object" || Array.isArray(object)) {
        throw new TypeError(`expected value of type "object" but instead got value "${value}" of type "${parseValueTypeDefault(object)}"`);
      }
      return object;
    },
    string(value) {
      return value;
    }
  };
  var writers = {
    default: writeString,
    array: writeJSON,
    object: writeJSON
  };
  function writeJSON(value) {
    return JSON.stringify(value);
  }
  function writeString(value) {
    return `${value}`;
  }
  var Controller = class {
    constructor(context) {
      this.context = context;
    }
    static get shouldLoad() {
      return true;
    }
    static afterLoad(_identifier, _application) {
      return;
    }
    get application() {
      return this.context.application;
    }
    get scope() {
      return this.context.scope;
    }
    get element() {
      return this.scope.element;
    }
    get identifier() {
      return this.scope.identifier;
    }
    get targets() {
      return this.scope.targets;
    }
    get outlets() {
      return this.scope.outlets;
    }
    get classes() {
      return this.scope.classes;
    }
    get data() {
      return this.scope.data;
    }
    initialize() {
    }
    connect() {
    }
    disconnect() {
    }
    dispatch(eventName, { target = this.element, detail = {}, prefix = this.identifier, bubbles = true, cancelable = true } = {}) {
      const type = prefix ? `${prefix}:${eventName}` : eventName;
      const event = new CustomEvent(type, { detail, bubbles, cancelable });
      target.dispatchEvent(event);
      return event;
    }
  };
  Controller.blessings = [
    ClassPropertiesBlessing,
    TargetPropertiesBlessing,
    ValuePropertiesBlessing,
    OutletPropertiesBlessing
  ];
  Controller.targets = [];
  Controller.outlets = [];
  Controller.values = {};

  // app/javascript/controllers/application.js
  var application = Application.start();
  application.debug = false;
  window.Stimulus = application;

  // node_modules/@rails/request.js/src/fetch_response.js
  var FetchResponse2 = class {
    constructor(response) {
      this.response = response;
    }
    get statusCode() {
      return this.response.status;
    }
    get redirected() {
      return this.response.redirected;
    }
    get ok() {
      return this.response.ok;
    }
    get unauthenticated() {
      return this.statusCode === 401;
    }
    get unprocessableEntity() {
      return this.statusCode === 422;
    }
    get authenticationURL() {
      return this.response.headers.get("WWW-Authenticate");
    }
    get contentType() {
      const contentType = this.response.headers.get("Content-Type") || "";
      return contentType.replace(/;.*$/, "");
    }
    get headers() {
      return this.response.headers;
    }
    get html() {
      if (this.contentType.match(/^(application|text)\/(html|xhtml\+xml)$/)) {
        return this.text;
      }
      return Promise.reject(new Error(`Expected an HTML response but got "${this.contentType}" instead`));
    }
    get json() {
      if (this.contentType.match(/^application\/.*json$/)) {
        return this.responseJson || (this.responseJson = this.response.json());
      }
      return Promise.reject(new Error(`Expected a JSON response but got "${this.contentType}" instead`));
    }
    get text() {
      return this.responseText || (this.responseText = this.response.text());
    }
    get isTurboStream() {
      return this.contentType.match(/^text\/vnd\.turbo-stream\.html/);
    }
    async renderTurboStream() {
      if (this.isTurboStream) {
        if (window.Turbo) {
          await window.Turbo.renderStreamMessage(await this.text);
        } else {
          console.warn("You must set `window.Turbo = Turbo` to automatically process Turbo Stream events with request.js");
        }
      } else {
        return Promise.reject(new Error(`Expected a Turbo Stream response but got "${this.contentType}" instead`));
      }
    }
  };

  // node_modules/@rails/request.js/src/request_interceptor.js
  var RequestInterceptor = class {
    static register(interceptor) {
      this.interceptor = interceptor;
    }
    static get() {
      return this.interceptor;
    }
    static reset() {
      this.interceptor = void 0;
    }
  };

  // node_modules/@rails/request.js/src/lib/utils.js
  function getCookie(name) {
    const cookies = document.cookie ? document.cookie.split("; ") : [];
    const prefix = `${encodeURIComponent(name)}=`;
    const cookie = cookies.find((cookie2) => cookie2.startsWith(prefix));
    if (cookie) {
      const value = cookie.split("=").slice(1).join("=");
      if (value) {
        return decodeURIComponent(value);
      }
    }
  }
  function compact(object) {
    const result = {};
    for (const key in object) {
      const value = object[key];
      if (value !== void 0) {
        result[key] = value;
      }
    }
    return result;
  }
  function metaContent(name) {
    const element = document.head.querySelector(`meta[name="${name}"]`);
    return element && element.content;
  }
  function stringEntriesFromFormData(formData) {
    return [...formData].reduce((entries, [name, value]) => {
      return entries.concat(typeof value === "string" ? [[name, value]] : []);
    }, []);
  }
  function mergeEntries(searchParams, entries) {
    for (const [name, value] of entries) {
      if (value instanceof window.File)
        continue;
      if (searchParams.has(name) && !name.includes("[]")) {
        searchParams.delete(name);
        searchParams.set(name, value);
      } else {
        searchParams.append(name, value);
      }
    }
  }

  // node_modules/@rails/request.js/src/fetch_request.js
  var FetchRequest2 = class {
    constructor(method, url, options = {}) {
      this.method = method;
      this.options = options;
      this.originalUrl = url.toString();
    }
    async perform() {
      try {
        const requestInterceptor = RequestInterceptor.get();
        if (requestInterceptor) {
          await requestInterceptor(this);
        }
      } catch (error2) {
        console.error(error2);
      }
      const response = new FetchResponse2(await window.fetch(this.url, this.fetchOptions));
      if (response.unauthenticated && response.authenticationURL) {
        return Promise.reject(window.location.href = response.authenticationURL);
      }
      if (response.ok && response.isTurboStream) {
        await response.renderTurboStream();
      }
      return response;
    }
    addHeader(key, value) {
      const headers = this.additionalHeaders;
      headers[key] = value;
      this.options.headers = headers;
    }
    sameHostname() {
      if (!this.originalUrl.startsWith("http:")) {
        return true;
      }
      try {
        return new URL(this.originalUrl).hostname === window.location.hostname;
      } catch (_) {
        return true;
      }
    }
    get fetchOptions() {
      return {
        method: this.method.toUpperCase(),
        headers: this.headers,
        body: this.formattedBody,
        signal: this.signal,
        credentials: "same-origin",
        redirect: this.redirect
      };
    }
    get headers() {
      const baseHeaders = {
        "X-Requested-With": "XMLHttpRequest",
        "Content-Type": this.contentType,
        Accept: this.accept
      };
      if (this.sameHostname()) {
        baseHeaders["X-CSRF-Token"] = this.csrfToken;
      }
      return compact(
        Object.assign(baseHeaders, this.additionalHeaders)
      );
    }
    get csrfToken() {
      return getCookie(metaContent("csrf-param")) || metaContent("csrf-token");
    }
    get contentType() {
      if (this.options.contentType) {
        return this.options.contentType;
      } else if (this.body == null || this.body instanceof window.FormData) {
        return void 0;
      } else if (this.body instanceof window.File) {
        return this.body.type;
      }
      return "application/json";
    }
    get accept() {
      switch (this.responseKind) {
        case "html":
          return "text/html, application/xhtml+xml";
        case "turbo-stream":
          return "text/vnd.turbo-stream.html, text/html, application/xhtml+xml";
        case "json":
          return "application/json, application/vnd.api+json";
        default:
          return "*/*";
      }
    }
    get body() {
      return this.options.body;
    }
    get query() {
      const originalQuery = (this.originalUrl.split("?")[1] || "").split("#")[0];
      const params = new URLSearchParams(originalQuery);
      let requestQuery = this.options.query;
      if (requestQuery instanceof window.FormData) {
        requestQuery = stringEntriesFromFormData(requestQuery);
      } else if (requestQuery instanceof window.URLSearchParams) {
        requestQuery = requestQuery.entries();
      } else {
        requestQuery = Object.entries(requestQuery || {});
      }
      mergeEntries(params, requestQuery);
      const query = params.toString();
      return query.length > 0 ? `?${query}` : "";
    }
    get url() {
      return this.originalUrl.split("?")[0].split("#")[0] + this.query;
    }
    get responseKind() {
      return this.options.responseKind || "html";
    }
    get signal() {
      return this.options.signal;
    }
    get redirect() {
      return this.options.redirect || "follow";
    }
    get additionalHeaders() {
      return this.options.headers || {};
    }
    get formattedBody() {
      const bodyIsAString = Object.prototype.toString.call(this.body) === "[object String]";
      const contentTypeIsJson = this.headers["Content-Type"] === "application/json";
      if (contentTypeIsJson && !bodyIsAString) {
        return JSON.stringify(this.body);
      }
      return this.body;
    }
  };

  // node_modules/@rails/request.js/src/verbs.js
  async function get(url, options) {
    const request = new FetchRequest2("get", url, options);
    return request.perform();
  }
  async function post(url, options) {
    const request = new FetchRequest2("post", url, options);
    return request.perform();
  }

  // app/javascript/controllers/app_controller.js
  var app_controller_default = class extends Controller {
    connect() {
      this.update_mefile_stats();
    }
    loadNewPage() {
      console.log("new page loaded");
      this.toggleBottomMenu();
      this.hideLoader();
      window.scrollTo(0, 0);
      this.update_mefile_stats();
    }
    showLoader() {
      console.log("showing loader");
      this.loaderTarget.style.display = "";
      this.loaderTarget.style.visibility = "visible";
    }
    hideLoader() {
      console.log("hiding loader");
      this.loaderTarget.style.display = "none";
      this.loaderTarget.style.visibility = "hidden";
    }
    clearSession() {
      console.log("clearing session");
      localStorage.removeItem("psg_auth_token");
      localStorage.removeItem("psg_refresh_token");
    }
    openModal() {
      document.body.style.overflow = "hidden";
      this.modalTarget.style.display = "block";
      this.backdropTarget.classList.remove("d-none");
      setTimeout(() => {
        this.modalTarget.classList.add("show");
        this.backdropTarget.classList.add("show");
      }, 100);
    }
    closeModal() {
      this.modalTarget.classList.remove("show");
      document.body.removeAttribute("style");
      setTimeout(() => {
        this.modalTarget.style.display = "none";
        this.backdropTarget.classList.remove("show");
      }, 400);
      setTimeout(() => {
        this.backdropTarget.classList.add("d-none");
      }, 800);
    }
    toggleBottomMenu() {
      const whichItem = this.appPageTarget.dataset.appPageAppPageValue;
      this.bmLinkTargets.forEach((item) => {
        item.classList.remove("active");
        if (item.dataset.bottomMenuItem === whichItem) {
          item.classList.add("active");
        }
      });
    }
    openSidebar() {
      document.body.style.overflow = "hidden";
      this.sidebarTarget.style.visibility = "visible";
      this.backdropTarget.classList.remove("d-none");
      setTimeout(() => {
        this.sidebarTarget.classList.add("show");
        this.backdropTarget.classList.add("show");
      }, 100);
    }
    closeSidebar() {
      this.sidebarTarget.classList.remove("show");
      this.backdropTarget.classList.remove("show");
      document.body.removeAttribute("style");
      setTimeout(() => {
        this.backdropTarget.classList.add("d-none");
      }, 100);
    }
    openPanelRight() {
      document.body.style.overflow = "hidden";
      this.panelRightTarget.style.visibility = "visible";
      this.backdropTarget.classList.remove("d-none");
      setTimeout(() => {
        this.panelRightTarget.classList.add("show");
        this.backdropTarget.classList.add("show");
      }, 100);
    }
    closePanelRight() {
      this.panelRightTarget.classList.remove("show");
      this.backdropTarget.classList.remove("show");
      document.body.removeAttribute("style");
      setTimeout(() => {
        this.backdropTarget.classList.add("d-none");
      }, 100);
    }
    openLogoutDialog() {
      document.body.style.overflow = "hidden";
      this.logoutDialogTarget.style.display = "block";
      this.backdropTarget.classList.remove("d-none");
      setTimeout(() => {
        this.logoutDialogTarget.classList.add("show");
        this.backdropTarget.classList.add("show");
        this.backdropTarget.classList.remove("d-none");
      }, 100);
    }
    closeLogoutDialog() {
      this.logoutDialogTarget.classList.remove("show");
      document.body.removeAttribute("style");
      setTimeout(() => {
        this.logoutDialogTarget.style.display = "none";
        this.backdropTarget.classList.remove("show");
      }, 400);
      setTimeout(() => {
        this.backdropTarget.classList.add("d-none");
      }, 800);
    }
    loadSelectedPage() {
      console.log("load selected page");
      this.showLoader();
      this.update_mefile_stats;
    }
    async update_mefile_stats() {
      const response = await get("/api/v1/stats/user_stats", { responseKind: "json" });
      const json = await response.json;
      this.mobileNumberTargets.forEach((element) => {
        element.innerHTML = json.user_alias;
      });
      this.homeZipTargets.forEach((element) => {
        element.innerHTML = json.home_zip;
      });
      this.tagCountTargets.forEach((element) => {
        if (json.response_code == "200" && json.trait_tag_count > 0) {
          element.innerHTML = json.trait_tag_count;
          element.style.display = "";
        } else {
          element.style.display = "none";
        }
      });
      this.offerCountTargets.forEach((element) => {
        if (json.response_code == "200" && json.current_offer_count > 0) {
          element.innerHTML = json.current_offer_count;
          element.style.display = "";
        } else {
          element.style.display = "none";
        }
      });
      const formatter = new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: "USD"
      });
      this.balanceTargets.forEach((element) => {
        if (json.response_code == "200" && json.ledger_balance > 0) {
          element.innerHTML = formatter.format(json.ledger_balance);
          element.style.display = "";
        } else {
          element.style.display = "none";
        }
      });
      if (json.response_code == "200") {
        this.logoutButtonTarget.style.display = "";
      } else {
        this.logoutButtonTarget.style.display = "none";
      }
    }
    hideStats() {
      console.log("hide stats");
      this.mobileNumberTargets.forEach((element) => {
        element.innerHTML = "";
      });
      this.homeZipTargets.forEach((element) => {
        element.innerHTML = "";
      });
      this.tagCountTargets.forEach((element) => {
        element.style.display = "none";
      });
      this.offerCountTargets.forEach((element) => {
        element.style.display = "none";
      });
      this.balanceTargets.forEach((element) => {
        element.style.display = "none";
      });
    }
  };
  __publicField(app_controller_default, "targets", [
    "mobileNumber",
    "homeZip",
    "tagCount",
    "offerCount",
    "balance",
    "modal",
    "sidebar",
    "panelRight",
    "backdrop",
    "backdropStatic",
    "appPage",
    "bmLink",
    "login",
    "loader",
    "logoutButton",
    "logoutDialog"
  ]);
  __publicField(app_controller_default, "values", {
    session: Boolean
  });

  // app/javascript/controllers/app_page_controller.js
  var app_page_controller_default = class extends Controller {
    connect() {
      this.dispatch("newPageLoad");
      if (this.refreshRequired()) {
        this.refreshFrame();
      }
    }
    refreshRequired() {
      const frameElement = window.document.getElementById("app_window");
      const src = frameElement.getAttribute("src");
      if (!src.includes("knock") && this.getCookie("from_knock") === "true" && this.getCookie("return_to") !== "") {
        return true;
      } else {
        return false;
      }
    }
    refreshFrame() {
      const frameElement = window.document.getElementById("app_window");
      console.log(frameElement);
      const return_to = "/" + this.getCookie("return_to");
      frameElement.attributeChangedCallback("src", null, return_to);
      const src = frameElement.getAttribute("src");
      if (src) {
        frameElement.setAttribute("src", return_to);
      }
      window.document.cookie = "from_knock=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/";
      window.document.cookie = "return_to=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/";
    }
    setCookie(cname, cvalue, exdays) {
      const d = new Date();
      d.setTime(d.getTime() + exdays * 24 * 60 * 60 * 1e3);
      let expires = "expires=" + d.toUTCString();
      document.cookie = cname + "=" + cvalue + ";" + expires + ";path=/";
    }
    getCookie(cname) {
      let name = cname + "=";
      let ca = document.cookie.split(";");
      for (let i = 0; i < ca.length; i++) {
        let c = ca[i];
        while (c.charAt(0) == " ") {
          c = c.substring(1);
        }
        if (c.indexOf(name) == 0) {
          return c.substring(name.length, c.length);
        }
      }
      return "";
    }
  };
  __publicField(app_page_controller_default, "values", {
    appPage: String
  });

  // node_modules/@popperjs/core/lib/index.js
  var lib_exports = {};
  __export(lib_exports, {
    afterMain: () => afterMain,
    afterRead: () => afterRead,
    afterWrite: () => afterWrite,
    applyStyles: () => applyStyles_default,
    arrow: () => arrow_default,
    auto: () => auto,
    basePlacements: () => basePlacements,
    beforeMain: () => beforeMain,
    beforeRead: () => beforeRead,
    beforeWrite: () => beforeWrite,
    bottom: () => bottom,
    clippingParents: () => clippingParents,
    computeStyles: () => computeStyles_default,
    createPopper: () => createPopper3,
    createPopperBase: () => createPopper,
    createPopperLite: () => createPopper2,
    detectOverflow: () => detectOverflow,
    end: () => end,
    eventListeners: () => eventListeners_default,
    flip: () => flip_default,
    hide: () => hide_default,
    left: () => left,
    main: () => main,
    modifierPhases: () => modifierPhases,
    offset: () => offset_default,
    placements: () => placements,
    popper: () => popper,
    popperGenerator: () => popperGenerator,
    popperOffsets: () => popperOffsets_default,
    preventOverflow: () => preventOverflow_default,
    read: () => read,
    reference: () => reference,
    right: () => right,
    start: () => start2,
    top: () => top,
    variationPlacements: () => variationPlacements,
    viewport: () => viewport,
    write: () => write
  });

  // node_modules/@popperjs/core/lib/enums.js
  var top = "top";
  var bottom = "bottom";
  var right = "right";
  var left = "left";
  var auto = "auto";
  var basePlacements = [top, bottom, right, left];
  var start2 = "start";
  var end = "end";
  var clippingParents = "clippingParents";
  var viewport = "viewport";
  var popper = "popper";
  var reference = "reference";
  var variationPlacements = /* @__PURE__ */ basePlacements.reduce(function(acc, placement) {
    return acc.concat([placement + "-" + start2, placement + "-" + end]);
  }, []);
  var placements = /* @__PURE__ */ [].concat(basePlacements, [auto]).reduce(function(acc, placement) {
    return acc.concat([placement, placement + "-" + start2, placement + "-" + end]);
  }, []);
  var beforeRead = "beforeRead";
  var read = "read";
  var afterRead = "afterRead";
  var beforeMain = "beforeMain";
  var main = "main";
  var afterMain = "afterMain";
  var beforeWrite = "beforeWrite";
  var write = "write";
  var afterWrite = "afterWrite";
  var modifierPhases = [beforeRead, read, afterRead, beforeMain, main, afterMain, beforeWrite, write, afterWrite];

  // node_modules/@popperjs/core/lib/dom-utils/getNodeName.js
  function getNodeName(element) {
    return element ? (element.nodeName || "").toLowerCase() : null;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getWindow.js
  function getWindow(node) {
    if (node == null) {
      return window;
    }
    if (node.toString() !== "[object Window]") {
      var ownerDocument = node.ownerDocument;
      return ownerDocument ? ownerDocument.defaultView || window : window;
    }
    return node;
  }

  // node_modules/@popperjs/core/lib/dom-utils/instanceOf.js
  function isElement(node) {
    var OwnElement = getWindow(node).Element;
    return node instanceof OwnElement || node instanceof Element;
  }
  function isHTMLElement(node) {
    var OwnElement = getWindow(node).HTMLElement;
    return node instanceof OwnElement || node instanceof HTMLElement;
  }
  function isShadowRoot(node) {
    if (typeof ShadowRoot === "undefined") {
      return false;
    }
    var OwnElement = getWindow(node).ShadowRoot;
    return node instanceof OwnElement || node instanceof ShadowRoot;
  }

  // node_modules/@popperjs/core/lib/modifiers/applyStyles.js
  function applyStyles(_ref) {
    var state = _ref.state;
    Object.keys(state.elements).forEach(function(name) {
      var style = state.styles[name] || {};
      var attributes = state.attributes[name] || {};
      var element = state.elements[name];
      if (!isHTMLElement(element) || !getNodeName(element)) {
        return;
      }
      Object.assign(element.style, style);
      Object.keys(attributes).forEach(function(name2) {
        var value = attributes[name2];
        if (value === false) {
          element.removeAttribute(name2);
        } else {
          element.setAttribute(name2, value === true ? "" : value);
        }
      });
    });
  }
  function effect(_ref2) {
    var state = _ref2.state;
    var initialStyles = {
      popper: {
        position: state.options.strategy,
        left: "0",
        top: "0",
        margin: "0"
      },
      arrow: {
        position: "absolute"
      },
      reference: {}
    };
    Object.assign(state.elements.popper.style, initialStyles.popper);
    state.styles = initialStyles;
    if (state.elements.arrow) {
      Object.assign(state.elements.arrow.style, initialStyles.arrow);
    }
    return function() {
      Object.keys(state.elements).forEach(function(name) {
        var element = state.elements[name];
        var attributes = state.attributes[name] || {};
        var styleProperties = Object.keys(state.styles.hasOwnProperty(name) ? state.styles[name] : initialStyles[name]);
        var style = styleProperties.reduce(function(style2, property) {
          style2[property] = "";
          return style2;
        }, {});
        if (!isHTMLElement(element) || !getNodeName(element)) {
          return;
        }
        Object.assign(element.style, style);
        Object.keys(attributes).forEach(function(attribute) {
          element.removeAttribute(attribute);
        });
      });
    };
  }
  var applyStyles_default = {
    name: "applyStyles",
    enabled: true,
    phase: "write",
    fn: applyStyles,
    effect,
    requires: ["computeStyles"]
  };

  // node_modules/@popperjs/core/lib/utils/getBasePlacement.js
  function getBasePlacement(placement) {
    return placement.split("-")[0];
  }

  // node_modules/@popperjs/core/lib/utils/math.js
  var max = Math.max;
  var min = Math.min;
  var round = Math.round;

  // node_modules/@popperjs/core/lib/utils/userAgent.js
  function getUAString() {
    var uaData = navigator.userAgentData;
    if (uaData != null && uaData.brands && Array.isArray(uaData.brands)) {
      return uaData.brands.map(function(item) {
        return item.brand + "/" + item.version;
      }).join(" ");
    }
    return navigator.userAgent;
  }

  // node_modules/@popperjs/core/lib/dom-utils/isLayoutViewport.js
  function isLayoutViewport() {
    return !/^((?!chrome|android).)*safari/i.test(getUAString());
  }

  // node_modules/@popperjs/core/lib/dom-utils/getBoundingClientRect.js
  function getBoundingClientRect(element, includeScale, isFixedStrategy) {
    if (includeScale === void 0) {
      includeScale = false;
    }
    if (isFixedStrategy === void 0) {
      isFixedStrategy = false;
    }
    var clientRect = element.getBoundingClientRect();
    var scaleX = 1;
    var scaleY = 1;
    if (includeScale && isHTMLElement(element)) {
      scaleX = element.offsetWidth > 0 ? round(clientRect.width) / element.offsetWidth || 1 : 1;
      scaleY = element.offsetHeight > 0 ? round(clientRect.height) / element.offsetHeight || 1 : 1;
    }
    var _ref = isElement(element) ? getWindow(element) : window, visualViewport = _ref.visualViewport;
    var addVisualOffsets = !isLayoutViewport() && isFixedStrategy;
    var x = (clientRect.left + (addVisualOffsets && visualViewport ? visualViewport.offsetLeft : 0)) / scaleX;
    var y = (clientRect.top + (addVisualOffsets && visualViewport ? visualViewport.offsetTop : 0)) / scaleY;
    var width = clientRect.width / scaleX;
    var height = clientRect.height / scaleY;
    return {
      width,
      height,
      top: y,
      right: x + width,
      bottom: y + height,
      left: x,
      x,
      y
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getLayoutRect.js
  function getLayoutRect(element) {
    var clientRect = getBoundingClientRect(element);
    var width = element.offsetWidth;
    var height = element.offsetHeight;
    if (Math.abs(clientRect.width - width) <= 1) {
      width = clientRect.width;
    }
    if (Math.abs(clientRect.height - height) <= 1) {
      height = clientRect.height;
    }
    return {
      x: element.offsetLeft,
      y: element.offsetTop,
      width,
      height
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/contains.js
  function contains(parent, child) {
    var rootNode = child.getRootNode && child.getRootNode();
    if (parent.contains(child)) {
      return true;
    } else if (rootNode && isShadowRoot(rootNode)) {
      var next = child;
      do {
        if (next && parent.isSameNode(next)) {
          return true;
        }
        next = next.parentNode || next.host;
      } while (next);
    }
    return false;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getComputedStyle.js
  function getComputedStyle2(element) {
    return getWindow(element).getComputedStyle(element);
  }

  // node_modules/@popperjs/core/lib/dom-utils/isTableElement.js
  function isTableElement(element) {
    return ["table", "td", "th"].indexOf(getNodeName(element)) >= 0;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getDocumentElement.js
  function getDocumentElement(element) {
    return ((isElement(element) ? element.ownerDocument : element.document) || window.document).documentElement;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getParentNode.js
  function getParentNode(element) {
    if (getNodeName(element) === "html") {
      return element;
    }
    return element.assignedSlot || element.parentNode || (isShadowRoot(element) ? element.host : null) || getDocumentElement(element);
  }

  // node_modules/@popperjs/core/lib/dom-utils/getOffsetParent.js
  function getTrueOffsetParent(element) {
    if (!isHTMLElement(element) || getComputedStyle2(element).position === "fixed") {
      return null;
    }
    return element.offsetParent;
  }
  function getContainingBlock(element) {
    var isFirefox = /firefox/i.test(getUAString());
    var isIE = /Trident/i.test(getUAString());
    if (isIE && isHTMLElement(element)) {
      var elementCss = getComputedStyle2(element);
      if (elementCss.position === "fixed") {
        return null;
      }
    }
    var currentNode = getParentNode(element);
    if (isShadowRoot(currentNode)) {
      currentNode = currentNode.host;
    }
    while (isHTMLElement(currentNode) && ["html", "body"].indexOf(getNodeName(currentNode)) < 0) {
      var css = getComputedStyle2(currentNode);
      if (css.transform !== "none" || css.perspective !== "none" || css.contain === "paint" || ["transform", "perspective"].indexOf(css.willChange) !== -1 || isFirefox && css.willChange === "filter" || isFirefox && css.filter && css.filter !== "none") {
        return currentNode;
      } else {
        currentNode = currentNode.parentNode;
      }
    }
    return null;
  }
  function getOffsetParent(element) {
    var window2 = getWindow(element);
    var offsetParent = getTrueOffsetParent(element);
    while (offsetParent && isTableElement(offsetParent) && getComputedStyle2(offsetParent).position === "static") {
      offsetParent = getTrueOffsetParent(offsetParent);
    }
    if (offsetParent && (getNodeName(offsetParent) === "html" || getNodeName(offsetParent) === "body" && getComputedStyle2(offsetParent).position === "static")) {
      return window2;
    }
    return offsetParent || getContainingBlock(element) || window2;
  }

  // node_modules/@popperjs/core/lib/utils/getMainAxisFromPlacement.js
  function getMainAxisFromPlacement(placement) {
    return ["top", "bottom"].indexOf(placement) >= 0 ? "x" : "y";
  }

  // node_modules/@popperjs/core/lib/utils/within.js
  function within(min2, value, max2) {
    return max(min2, min(value, max2));
  }
  function withinMaxClamp(min2, value, max2) {
    var v = within(min2, value, max2);
    return v > max2 ? max2 : v;
  }

  // node_modules/@popperjs/core/lib/utils/getFreshSideObject.js
  function getFreshSideObject() {
    return {
      top: 0,
      right: 0,
      bottom: 0,
      left: 0
    };
  }

  // node_modules/@popperjs/core/lib/utils/mergePaddingObject.js
  function mergePaddingObject(paddingObject) {
    return Object.assign({}, getFreshSideObject(), paddingObject);
  }

  // node_modules/@popperjs/core/lib/utils/expandToHashMap.js
  function expandToHashMap(value, keys) {
    return keys.reduce(function(hashMap, key) {
      hashMap[key] = value;
      return hashMap;
    }, {});
  }

  // node_modules/@popperjs/core/lib/modifiers/arrow.js
  var toPaddingObject = function toPaddingObject2(padding, state) {
    padding = typeof padding === "function" ? padding(Object.assign({}, state.rects, {
      placement: state.placement
    })) : padding;
    return mergePaddingObject(typeof padding !== "number" ? padding : expandToHashMap(padding, basePlacements));
  };
  function arrow(_ref) {
    var _state$modifiersData$;
    var state = _ref.state, name = _ref.name, options = _ref.options;
    var arrowElement = state.elements.arrow;
    var popperOffsets2 = state.modifiersData.popperOffsets;
    var basePlacement = getBasePlacement(state.placement);
    var axis = getMainAxisFromPlacement(basePlacement);
    var isVertical = [left, right].indexOf(basePlacement) >= 0;
    var len = isVertical ? "height" : "width";
    if (!arrowElement || !popperOffsets2) {
      return;
    }
    var paddingObject = toPaddingObject(options.padding, state);
    var arrowRect = getLayoutRect(arrowElement);
    var minProp = axis === "y" ? top : left;
    var maxProp = axis === "y" ? bottom : right;
    var endDiff = state.rects.reference[len] + state.rects.reference[axis] - popperOffsets2[axis] - state.rects.popper[len];
    var startDiff = popperOffsets2[axis] - state.rects.reference[axis];
    var arrowOffsetParent = getOffsetParent(arrowElement);
    var clientSize = arrowOffsetParent ? axis === "y" ? arrowOffsetParent.clientHeight || 0 : arrowOffsetParent.clientWidth || 0 : 0;
    var centerToReference = endDiff / 2 - startDiff / 2;
    var min2 = paddingObject[minProp];
    var max2 = clientSize - arrowRect[len] - paddingObject[maxProp];
    var center = clientSize / 2 - arrowRect[len] / 2 + centerToReference;
    var offset2 = within(min2, center, max2);
    var axisProp = axis;
    state.modifiersData[name] = (_state$modifiersData$ = {}, _state$modifiersData$[axisProp] = offset2, _state$modifiersData$.centerOffset = offset2 - center, _state$modifiersData$);
  }
  function effect2(_ref2) {
    var state = _ref2.state, options = _ref2.options;
    var _options$element = options.element, arrowElement = _options$element === void 0 ? "[data-popper-arrow]" : _options$element;
    if (arrowElement == null) {
      return;
    }
    if (typeof arrowElement === "string") {
      arrowElement = state.elements.popper.querySelector(arrowElement);
      if (!arrowElement) {
        return;
      }
    }
    if (!contains(state.elements.popper, arrowElement)) {
      return;
    }
    state.elements.arrow = arrowElement;
  }
  var arrow_default = {
    name: "arrow",
    enabled: true,
    phase: "main",
    fn: arrow,
    effect: effect2,
    requires: ["popperOffsets"],
    requiresIfExists: ["preventOverflow"]
  };

  // node_modules/@popperjs/core/lib/utils/getVariation.js
  function getVariation(placement) {
    return placement.split("-")[1];
  }

  // node_modules/@popperjs/core/lib/modifiers/computeStyles.js
  var unsetSides = {
    top: "auto",
    right: "auto",
    bottom: "auto",
    left: "auto"
  };
  function roundOffsetsByDPR(_ref, win) {
    var x = _ref.x, y = _ref.y;
    var dpr = win.devicePixelRatio || 1;
    return {
      x: round(x * dpr) / dpr || 0,
      y: round(y * dpr) / dpr || 0
    };
  }
  function mapToStyles(_ref2) {
    var _Object$assign2;
    var popper2 = _ref2.popper, popperRect = _ref2.popperRect, placement = _ref2.placement, variation = _ref2.variation, offsets = _ref2.offsets, position = _ref2.position, gpuAcceleration = _ref2.gpuAcceleration, adaptive = _ref2.adaptive, roundOffsets = _ref2.roundOffsets, isFixed = _ref2.isFixed;
    var _offsets$x = offsets.x, x = _offsets$x === void 0 ? 0 : _offsets$x, _offsets$y = offsets.y, y = _offsets$y === void 0 ? 0 : _offsets$y;
    var _ref3 = typeof roundOffsets === "function" ? roundOffsets({
      x,
      y
    }) : {
      x,
      y
    };
    x = _ref3.x;
    y = _ref3.y;
    var hasX = offsets.hasOwnProperty("x");
    var hasY = offsets.hasOwnProperty("y");
    var sideX = left;
    var sideY = top;
    var win = window;
    if (adaptive) {
      var offsetParent = getOffsetParent(popper2);
      var heightProp = "clientHeight";
      var widthProp = "clientWidth";
      if (offsetParent === getWindow(popper2)) {
        offsetParent = getDocumentElement(popper2);
        if (getComputedStyle2(offsetParent).position !== "static" && position === "absolute") {
          heightProp = "scrollHeight";
          widthProp = "scrollWidth";
        }
      }
      offsetParent = offsetParent;
      if (placement === top || (placement === left || placement === right) && variation === end) {
        sideY = bottom;
        var offsetY = isFixed && offsetParent === win && win.visualViewport ? win.visualViewport.height : offsetParent[heightProp];
        y -= offsetY - popperRect.height;
        y *= gpuAcceleration ? 1 : -1;
      }
      if (placement === left || (placement === top || placement === bottom) && variation === end) {
        sideX = right;
        var offsetX = isFixed && offsetParent === win && win.visualViewport ? win.visualViewport.width : offsetParent[widthProp];
        x -= offsetX - popperRect.width;
        x *= gpuAcceleration ? 1 : -1;
      }
    }
    var commonStyles = Object.assign({
      position
    }, adaptive && unsetSides);
    var _ref4 = roundOffsets === true ? roundOffsetsByDPR({
      x,
      y
    }, getWindow(popper2)) : {
      x,
      y
    };
    x = _ref4.x;
    y = _ref4.y;
    if (gpuAcceleration) {
      var _Object$assign;
      return Object.assign({}, commonStyles, (_Object$assign = {}, _Object$assign[sideY] = hasY ? "0" : "", _Object$assign[sideX] = hasX ? "0" : "", _Object$assign.transform = (win.devicePixelRatio || 1) <= 1 ? "translate(" + x + "px, " + y + "px)" : "translate3d(" + x + "px, " + y + "px, 0)", _Object$assign));
    }
    return Object.assign({}, commonStyles, (_Object$assign2 = {}, _Object$assign2[sideY] = hasY ? y + "px" : "", _Object$assign2[sideX] = hasX ? x + "px" : "", _Object$assign2.transform = "", _Object$assign2));
  }
  function computeStyles(_ref5) {
    var state = _ref5.state, options = _ref5.options;
    var _options$gpuAccelerat = options.gpuAcceleration, gpuAcceleration = _options$gpuAccelerat === void 0 ? true : _options$gpuAccelerat, _options$adaptive = options.adaptive, adaptive = _options$adaptive === void 0 ? true : _options$adaptive, _options$roundOffsets = options.roundOffsets, roundOffsets = _options$roundOffsets === void 0 ? true : _options$roundOffsets;
    var commonStyles = {
      placement: getBasePlacement(state.placement),
      variation: getVariation(state.placement),
      popper: state.elements.popper,
      popperRect: state.rects.popper,
      gpuAcceleration,
      isFixed: state.options.strategy === "fixed"
    };
    if (state.modifiersData.popperOffsets != null) {
      state.styles.popper = Object.assign({}, state.styles.popper, mapToStyles(Object.assign({}, commonStyles, {
        offsets: state.modifiersData.popperOffsets,
        position: state.options.strategy,
        adaptive,
        roundOffsets
      })));
    }
    if (state.modifiersData.arrow != null) {
      state.styles.arrow = Object.assign({}, state.styles.arrow, mapToStyles(Object.assign({}, commonStyles, {
        offsets: state.modifiersData.arrow,
        position: "absolute",
        adaptive: false,
        roundOffsets
      })));
    }
    state.attributes.popper = Object.assign({}, state.attributes.popper, {
      "data-popper-placement": state.placement
    });
  }
  var computeStyles_default = {
    name: "computeStyles",
    enabled: true,
    phase: "beforeWrite",
    fn: computeStyles,
    data: {}
  };

  // node_modules/@popperjs/core/lib/modifiers/eventListeners.js
  var passive = {
    passive: true
  };
  function effect3(_ref) {
    var state = _ref.state, instance = _ref.instance, options = _ref.options;
    var _options$scroll = options.scroll, scroll = _options$scroll === void 0 ? true : _options$scroll, _options$resize = options.resize, resize = _options$resize === void 0 ? true : _options$resize;
    var window2 = getWindow(state.elements.popper);
    var scrollParents = [].concat(state.scrollParents.reference, state.scrollParents.popper);
    if (scroll) {
      scrollParents.forEach(function(scrollParent) {
        scrollParent.addEventListener("scroll", instance.update, passive);
      });
    }
    if (resize) {
      window2.addEventListener("resize", instance.update, passive);
    }
    return function() {
      if (scroll) {
        scrollParents.forEach(function(scrollParent) {
          scrollParent.removeEventListener("scroll", instance.update, passive);
        });
      }
      if (resize) {
        window2.removeEventListener("resize", instance.update, passive);
      }
    };
  }
  var eventListeners_default = {
    name: "eventListeners",
    enabled: true,
    phase: "write",
    fn: function fn() {
    },
    effect: effect3,
    data: {}
  };

  // node_modules/@popperjs/core/lib/utils/getOppositePlacement.js
  var hash = {
    left: "right",
    right: "left",
    bottom: "top",
    top: "bottom"
  };
  function getOppositePlacement(placement) {
    return placement.replace(/left|right|bottom|top/g, function(matched) {
      return hash[matched];
    });
  }

  // node_modules/@popperjs/core/lib/utils/getOppositeVariationPlacement.js
  var hash2 = {
    start: "end",
    end: "start"
  };
  function getOppositeVariationPlacement(placement) {
    return placement.replace(/start|end/g, function(matched) {
      return hash2[matched];
    });
  }

  // node_modules/@popperjs/core/lib/dom-utils/getWindowScroll.js
  function getWindowScroll(node) {
    var win = getWindow(node);
    var scrollLeft = win.pageXOffset;
    var scrollTop = win.pageYOffset;
    return {
      scrollLeft,
      scrollTop
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getWindowScrollBarX.js
  function getWindowScrollBarX(element) {
    return getBoundingClientRect(getDocumentElement(element)).left + getWindowScroll(element).scrollLeft;
  }

  // node_modules/@popperjs/core/lib/dom-utils/getViewportRect.js
  function getViewportRect(element, strategy) {
    var win = getWindow(element);
    var html = getDocumentElement(element);
    var visualViewport = win.visualViewport;
    var width = html.clientWidth;
    var height = html.clientHeight;
    var x = 0;
    var y = 0;
    if (visualViewport) {
      width = visualViewport.width;
      height = visualViewport.height;
      var layoutViewport = isLayoutViewport();
      if (layoutViewport || !layoutViewport && strategy === "fixed") {
        x = visualViewport.offsetLeft;
        y = visualViewport.offsetTop;
      }
    }
    return {
      width,
      height,
      x: x + getWindowScrollBarX(element),
      y
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getDocumentRect.js
  function getDocumentRect(element) {
    var _element$ownerDocumen;
    var html = getDocumentElement(element);
    var winScroll = getWindowScroll(element);
    var body = (_element$ownerDocumen = element.ownerDocument) == null ? void 0 : _element$ownerDocumen.body;
    var width = max(html.scrollWidth, html.clientWidth, body ? body.scrollWidth : 0, body ? body.clientWidth : 0);
    var height = max(html.scrollHeight, html.clientHeight, body ? body.scrollHeight : 0, body ? body.clientHeight : 0);
    var x = -winScroll.scrollLeft + getWindowScrollBarX(element);
    var y = -winScroll.scrollTop;
    if (getComputedStyle2(body || html).direction === "rtl") {
      x += max(html.clientWidth, body ? body.clientWidth : 0) - width;
    }
    return {
      width,
      height,
      x,
      y
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/isScrollParent.js
  function isScrollParent(element) {
    var _getComputedStyle = getComputedStyle2(element), overflow = _getComputedStyle.overflow, overflowX = _getComputedStyle.overflowX, overflowY = _getComputedStyle.overflowY;
    return /auto|scroll|overlay|hidden/.test(overflow + overflowY + overflowX);
  }

  // node_modules/@popperjs/core/lib/dom-utils/getScrollParent.js
  function getScrollParent(node) {
    if (["html", "body", "#document"].indexOf(getNodeName(node)) >= 0) {
      return node.ownerDocument.body;
    }
    if (isHTMLElement(node) && isScrollParent(node)) {
      return node;
    }
    return getScrollParent(getParentNode(node));
  }

  // node_modules/@popperjs/core/lib/dom-utils/listScrollParents.js
  function listScrollParents(element, list) {
    var _element$ownerDocumen;
    if (list === void 0) {
      list = [];
    }
    var scrollParent = getScrollParent(element);
    var isBody = scrollParent === ((_element$ownerDocumen = element.ownerDocument) == null ? void 0 : _element$ownerDocumen.body);
    var win = getWindow(scrollParent);
    var target = isBody ? [win].concat(win.visualViewport || [], isScrollParent(scrollParent) ? scrollParent : []) : scrollParent;
    var updatedList = list.concat(target);
    return isBody ? updatedList : updatedList.concat(listScrollParents(getParentNode(target)));
  }

  // node_modules/@popperjs/core/lib/utils/rectToClientRect.js
  function rectToClientRect(rect) {
    return Object.assign({}, rect, {
      left: rect.x,
      top: rect.y,
      right: rect.x + rect.width,
      bottom: rect.y + rect.height
    });
  }

  // node_modules/@popperjs/core/lib/dom-utils/getClippingRect.js
  function getInnerBoundingClientRect(element, strategy) {
    var rect = getBoundingClientRect(element, false, strategy === "fixed");
    rect.top = rect.top + element.clientTop;
    rect.left = rect.left + element.clientLeft;
    rect.bottom = rect.top + element.clientHeight;
    rect.right = rect.left + element.clientWidth;
    rect.width = element.clientWidth;
    rect.height = element.clientHeight;
    rect.x = rect.left;
    rect.y = rect.top;
    return rect;
  }
  function getClientRectFromMixedType(element, clippingParent, strategy) {
    return clippingParent === viewport ? rectToClientRect(getViewportRect(element, strategy)) : isElement(clippingParent) ? getInnerBoundingClientRect(clippingParent, strategy) : rectToClientRect(getDocumentRect(getDocumentElement(element)));
  }
  function getClippingParents(element) {
    var clippingParents2 = listScrollParents(getParentNode(element));
    var canEscapeClipping = ["absolute", "fixed"].indexOf(getComputedStyle2(element).position) >= 0;
    var clipperElement = canEscapeClipping && isHTMLElement(element) ? getOffsetParent(element) : element;
    if (!isElement(clipperElement)) {
      return [];
    }
    return clippingParents2.filter(function(clippingParent) {
      return isElement(clippingParent) && contains(clippingParent, clipperElement) && getNodeName(clippingParent) !== "body";
    });
  }
  function getClippingRect(element, boundary, rootBoundary, strategy) {
    var mainClippingParents = boundary === "clippingParents" ? getClippingParents(element) : [].concat(boundary);
    var clippingParents2 = [].concat(mainClippingParents, [rootBoundary]);
    var firstClippingParent = clippingParents2[0];
    var clippingRect = clippingParents2.reduce(function(accRect, clippingParent) {
      var rect = getClientRectFromMixedType(element, clippingParent, strategy);
      accRect.top = max(rect.top, accRect.top);
      accRect.right = min(rect.right, accRect.right);
      accRect.bottom = min(rect.bottom, accRect.bottom);
      accRect.left = max(rect.left, accRect.left);
      return accRect;
    }, getClientRectFromMixedType(element, firstClippingParent, strategy));
    clippingRect.width = clippingRect.right - clippingRect.left;
    clippingRect.height = clippingRect.bottom - clippingRect.top;
    clippingRect.x = clippingRect.left;
    clippingRect.y = clippingRect.top;
    return clippingRect;
  }

  // node_modules/@popperjs/core/lib/utils/computeOffsets.js
  function computeOffsets(_ref) {
    var reference2 = _ref.reference, element = _ref.element, placement = _ref.placement;
    var basePlacement = placement ? getBasePlacement(placement) : null;
    var variation = placement ? getVariation(placement) : null;
    var commonX = reference2.x + reference2.width / 2 - element.width / 2;
    var commonY = reference2.y + reference2.height / 2 - element.height / 2;
    var offsets;
    switch (basePlacement) {
      case top:
        offsets = {
          x: commonX,
          y: reference2.y - element.height
        };
        break;
      case bottom:
        offsets = {
          x: commonX,
          y: reference2.y + reference2.height
        };
        break;
      case right:
        offsets = {
          x: reference2.x + reference2.width,
          y: commonY
        };
        break;
      case left:
        offsets = {
          x: reference2.x - element.width,
          y: commonY
        };
        break;
      default:
        offsets = {
          x: reference2.x,
          y: reference2.y
        };
    }
    var mainAxis = basePlacement ? getMainAxisFromPlacement(basePlacement) : null;
    if (mainAxis != null) {
      var len = mainAxis === "y" ? "height" : "width";
      switch (variation) {
        case start2:
          offsets[mainAxis] = offsets[mainAxis] - (reference2[len] / 2 - element[len] / 2);
          break;
        case end:
          offsets[mainAxis] = offsets[mainAxis] + (reference2[len] / 2 - element[len] / 2);
          break;
        default:
      }
    }
    return offsets;
  }

  // node_modules/@popperjs/core/lib/utils/detectOverflow.js
  function detectOverflow(state, options) {
    if (options === void 0) {
      options = {};
    }
    var _options = options, _options$placement = _options.placement, placement = _options$placement === void 0 ? state.placement : _options$placement, _options$strategy = _options.strategy, strategy = _options$strategy === void 0 ? state.strategy : _options$strategy, _options$boundary = _options.boundary, boundary = _options$boundary === void 0 ? clippingParents : _options$boundary, _options$rootBoundary = _options.rootBoundary, rootBoundary = _options$rootBoundary === void 0 ? viewport : _options$rootBoundary, _options$elementConte = _options.elementContext, elementContext = _options$elementConte === void 0 ? popper : _options$elementConte, _options$altBoundary = _options.altBoundary, altBoundary = _options$altBoundary === void 0 ? false : _options$altBoundary, _options$padding = _options.padding, padding = _options$padding === void 0 ? 0 : _options$padding;
    var paddingObject = mergePaddingObject(typeof padding !== "number" ? padding : expandToHashMap(padding, basePlacements));
    var altContext = elementContext === popper ? reference : popper;
    var popperRect = state.rects.popper;
    var element = state.elements[altBoundary ? altContext : elementContext];
    var clippingClientRect = getClippingRect(isElement(element) ? element : element.contextElement || getDocumentElement(state.elements.popper), boundary, rootBoundary, strategy);
    var referenceClientRect = getBoundingClientRect(state.elements.reference);
    var popperOffsets2 = computeOffsets({
      reference: referenceClientRect,
      element: popperRect,
      strategy: "absolute",
      placement
    });
    var popperClientRect = rectToClientRect(Object.assign({}, popperRect, popperOffsets2));
    var elementClientRect = elementContext === popper ? popperClientRect : referenceClientRect;
    var overflowOffsets = {
      top: clippingClientRect.top - elementClientRect.top + paddingObject.top,
      bottom: elementClientRect.bottom - clippingClientRect.bottom + paddingObject.bottom,
      left: clippingClientRect.left - elementClientRect.left + paddingObject.left,
      right: elementClientRect.right - clippingClientRect.right + paddingObject.right
    };
    var offsetData = state.modifiersData.offset;
    if (elementContext === popper && offsetData) {
      var offset2 = offsetData[placement];
      Object.keys(overflowOffsets).forEach(function(key) {
        var multiply = [right, bottom].indexOf(key) >= 0 ? 1 : -1;
        var axis = [top, bottom].indexOf(key) >= 0 ? "y" : "x";
        overflowOffsets[key] += offset2[axis] * multiply;
      });
    }
    return overflowOffsets;
  }

  // node_modules/@popperjs/core/lib/utils/computeAutoPlacement.js
  function computeAutoPlacement(state, options) {
    if (options === void 0) {
      options = {};
    }
    var _options = options, placement = _options.placement, boundary = _options.boundary, rootBoundary = _options.rootBoundary, padding = _options.padding, flipVariations = _options.flipVariations, _options$allowedAutoP = _options.allowedAutoPlacements, allowedAutoPlacements = _options$allowedAutoP === void 0 ? placements : _options$allowedAutoP;
    var variation = getVariation(placement);
    var placements2 = variation ? flipVariations ? variationPlacements : variationPlacements.filter(function(placement2) {
      return getVariation(placement2) === variation;
    }) : basePlacements;
    var allowedPlacements = placements2.filter(function(placement2) {
      return allowedAutoPlacements.indexOf(placement2) >= 0;
    });
    if (allowedPlacements.length === 0) {
      allowedPlacements = placements2;
    }
    var overflows = allowedPlacements.reduce(function(acc, placement2) {
      acc[placement2] = detectOverflow(state, {
        placement: placement2,
        boundary,
        rootBoundary,
        padding
      })[getBasePlacement(placement2)];
      return acc;
    }, {});
    return Object.keys(overflows).sort(function(a, b) {
      return overflows[a] - overflows[b];
    });
  }

  // node_modules/@popperjs/core/lib/modifiers/flip.js
  function getExpandedFallbackPlacements(placement) {
    if (getBasePlacement(placement) === auto) {
      return [];
    }
    var oppositePlacement = getOppositePlacement(placement);
    return [getOppositeVariationPlacement(placement), oppositePlacement, getOppositeVariationPlacement(oppositePlacement)];
  }
  function flip(_ref) {
    var state = _ref.state, options = _ref.options, name = _ref.name;
    if (state.modifiersData[name]._skip) {
      return;
    }
    var _options$mainAxis = options.mainAxis, checkMainAxis = _options$mainAxis === void 0 ? true : _options$mainAxis, _options$altAxis = options.altAxis, checkAltAxis = _options$altAxis === void 0 ? true : _options$altAxis, specifiedFallbackPlacements = options.fallbackPlacements, padding = options.padding, boundary = options.boundary, rootBoundary = options.rootBoundary, altBoundary = options.altBoundary, _options$flipVariatio = options.flipVariations, flipVariations = _options$flipVariatio === void 0 ? true : _options$flipVariatio, allowedAutoPlacements = options.allowedAutoPlacements;
    var preferredPlacement = state.options.placement;
    var basePlacement = getBasePlacement(preferredPlacement);
    var isBasePlacement = basePlacement === preferredPlacement;
    var fallbackPlacements = specifiedFallbackPlacements || (isBasePlacement || !flipVariations ? [getOppositePlacement(preferredPlacement)] : getExpandedFallbackPlacements(preferredPlacement));
    var placements2 = [preferredPlacement].concat(fallbackPlacements).reduce(function(acc, placement2) {
      return acc.concat(getBasePlacement(placement2) === auto ? computeAutoPlacement(state, {
        placement: placement2,
        boundary,
        rootBoundary,
        padding,
        flipVariations,
        allowedAutoPlacements
      }) : placement2);
    }, []);
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var checksMap = /* @__PURE__ */ new Map();
    var makeFallbackChecks = true;
    var firstFittingPlacement = placements2[0];
    for (var i = 0; i < placements2.length; i++) {
      var placement = placements2[i];
      var _basePlacement = getBasePlacement(placement);
      var isStartVariation = getVariation(placement) === start2;
      var isVertical = [top, bottom].indexOf(_basePlacement) >= 0;
      var len = isVertical ? "width" : "height";
      var overflow = detectOverflow(state, {
        placement,
        boundary,
        rootBoundary,
        altBoundary,
        padding
      });
      var mainVariationSide = isVertical ? isStartVariation ? right : left : isStartVariation ? bottom : top;
      if (referenceRect[len] > popperRect[len]) {
        mainVariationSide = getOppositePlacement(mainVariationSide);
      }
      var altVariationSide = getOppositePlacement(mainVariationSide);
      var checks = [];
      if (checkMainAxis) {
        checks.push(overflow[_basePlacement] <= 0);
      }
      if (checkAltAxis) {
        checks.push(overflow[mainVariationSide] <= 0, overflow[altVariationSide] <= 0);
      }
      if (checks.every(function(check) {
        return check;
      })) {
        firstFittingPlacement = placement;
        makeFallbackChecks = false;
        break;
      }
      checksMap.set(placement, checks);
    }
    if (makeFallbackChecks) {
      var numberOfChecks = flipVariations ? 3 : 1;
      var _loop = function _loop2(_i2) {
        var fittingPlacement = placements2.find(function(placement2) {
          var checks2 = checksMap.get(placement2);
          if (checks2) {
            return checks2.slice(0, _i2).every(function(check) {
              return check;
            });
          }
        });
        if (fittingPlacement) {
          firstFittingPlacement = fittingPlacement;
          return "break";
        }
      };
      for (var _i = numberOfChecks; _i > 0; _i--) {
        var _ret = _loop(_i);
        if (_ret === "break")
          break;
      }
    }
    if (state.placement !== firstFittingPlacement) {
      state.modifiersData[name]._skip = true;
      state.placement = firstFittingPlacement;
      state.reset = true;
    }
  }
  var flip_default = {
    name: "flip",
    enabled: true,
    phase: "main",
    fn: flip,
    requiresIfExists: ["offset"],
    data: {
      _skip: false
    }
  };

  // node_modules/@popperjs/core/lib/modifiers/hide.js
  function getSideOffsets(overflow, rect, preventedOffsets) {
    if (preventedOffsets === void 0) {
      preventedOffsets = {
        x: 0,
        y: 0
      };
    }
    return {
      top: overflow.top - rect.height - preventedOffsets.y,
      right: overflow.right - rect.width + preventedOffsets.x,
      bottom: overflow.bottom - rect.height + preventedOffsets.y,
      left: overflow.left - rect.width - preventedOffsets.x
    };
  }
  function isAnySideFullyClipped(overflow) {
    return [top, right, bottom, left].some(function(side) {
      return overflow[side] >= 0;
    });
  }
  function hide(_ref) {
    var state = _ref.state, name = _ref.name;
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var preventedOffsets = state.modifiersData.preventOverflow;
    var referenceOverflow = detectOverflow(state, {
      elementContext: "reference"
    });
    var popperAltOverflow = detectOverflow(state, {
      altBoundary: true
    });
    var referenceClippingOffsets = getSideOffsets(referenceOverflow, referenceRect);
    var popperEscapeOffsets = getSideOffsets(popperAltOverflow, popperRect, preventedOffsets);
    var isReferenceHidden = isAnySideFullyClipped(referenceClippingOffsets);
    var hasPopperEscaped = isAnySideFullyClipped(popperEscapeOffsets);
    state.modifiersData[name] = {
      referenceClippingOffsets,
      popperEscapeOffsets,
      isReferenceHidden,
      hasPopperEscaped
    };
    state.attributes.popper = Object.assign({}, state.attributes.popper, {
      "data-popper-reference-hidden": isReferenceHidden,
      "data-popper-escaped": hasPopperEscaped
    });
  }
  var hide_default = {
    name: "hide",
    enabled: true,
    phase: "main",
    requiresIfExists: ["preventOverflow"],
    fn: hide
  };

  // node_modules/@popperjs/core/lib/modifiers/offset.js
  function distanceAndSkiddingToXY(placement, rects, offset2) {
    var basePlacement = getBasePlacement(placement);
    var invertDistance = [left, top].indexOf(basePlacement) >= 0 ? -1 : 1;
    var _ref = typeof offset2 === "function" ? offset2(Object.assign({}, rects, {
      placement
    })) : offset2, skidding = _ref[0], distance = _ref[1];
    skidding = skidding || 0;
    distance = (distance || 0) * invertDistance;
    return [left, right].indexOf(basePlacement) >= 0 ? {
      x: distance,
      y: skidding
    } : {
      x: skidding,
      y: distance
    };
  }
  function offset(_ref2) {
    var state = _ref2.state, options = _ref2.options, name = _ref2.name;
    var _options$offset = options.offset, offset2 = _options$offset === void 0 ? [0, 0] : _options$offset;
    var data = placements.reduce(function(acc, placement) {
      acc[placement] = distanceAndSkiddingToXY(placement, state.rects, offset2);
      return acc;
    }, {});
    var _data$state$placement = data[state.placement], x = _data$state$placement.x, y = _data$state$placement.y;
    if (state.modifiersData.popperOffsets != null) {
      state.modifiersData.popperOffsets.x += x;
      state.modifiersData.popperOffsets.y += y;
    }
    state.modifiersData[name] = data;
  }
  var offset_default = {
    name: "offset",
    enabled: true,
    phase: "main",
    requires: ["popperOffsets"],
    fn: offset
  };

  // node_modules/@popperjs/core/lib/modifiers/popperOffsets.js
  function popperOffsets(_ref) {
    var state = _ref.state, name = _ref.name;
    state.modifiersData[name] = computeOffsets({
      reference: state.rects.reference,
      element: state.rects.popper,
      strategy: "absolute",
      placement: state.placement
    });
  }
  var popperOffsets_default = {
    name: "popperOffsets",
    enabled: true,
    phase: "read",
    fn: popperOffsets,
    data: {}
  };

  // node_modules/@popperjs/core/lib/utils/getAltAxis.js
  function getAltAxis(axis) {
    return axis === "x" ? "y" : "x";
  }

  // node_modules/@popperjs/core/lib/modifiers/preventOverflow.js
  function preventOverflow(_ref) {
    var state = _ref.state, options = _ref.options, name = _ref.name;
    var _options$mainAxis = options.mainAxis, checkMainAxis = _options$mainAxis === void 0 ? true : _options$mainAxis, _options$altAxis = options.altAxis, checkAltAxis = _options$altAxis === void 0 ? false : _options$altAxis, boundary = options.boundary, rootBoundary = options.rootBoundary, altBoundary = options.altBoundary, padding = options.padding, _options$tether = options.tether, tether = _options$tether === void 0 ? true : _options$tether, _options$tetherOffset = options.tetherOffset, tetherOffset = _options$tetherOffset === void 0 ? 0 : _options$tetherOffset;
    var overflow = detectOverflow(state, {
      boundary,
      rootBoundary,
      padding,
      altBoundary
    });
    var basePlacement = getBasePlacement(state.placement);
    var variation = getVariation(state.placement);
    var isBasePlacement = !variation;
    var mainAxis = getMainAxisFromPlacement(basePlacement);
    var altAxis = getAltAxis(mainAxis);
    var popperOffsets2 = state.modifiersData.popperOffsets;
    var referenceRect = state.rects.reference;
    var popperRect = state.rects.popper;
    var tetherOffsetValue = typeof tetherOffset === "function" ? tetherOffset(Object.assign({}, state.rects, {
      placement: state.placement
    })) : tetherOffset;
    var normalizedTetherOffsetValue = typeof tetherOffsetValue === "number" ? {
      mainAxis: tetherOffsetValue,
      altAxis: tetherOffsetValue
    } : Object.assign({
      mainAxis: 0,
      altAxis: 0
    }, tetherOffsetValue);
    var offsetModifierState = state.modifiersData.offset ? state.modifiersData.offset[state.placement] : null;
    var data = {
      x: 0,
      y: 0
    };
    if (!popperOffsets2) {
      return;
    }
    if (checkMainAxis) {
      var _offsetModifierState$;
      var mainSide = mainAxis === "y" ? top : left;
      var altSide = mainAxis === "y" ? bottom : right;
      var len = mainAxis === "y" ? "height" : "width";
      var offset2 = popperOffsets2[mainAxis];
      var min2 = offset2 + overflow[mainSide];
      var max2 = offset2 - overflow[altSide];
      var additive = tether ? -popperRect[len] / 2 : 0;
      var minLen = variation === start2 ? referenceRect[len] : popperRect[len];
      var maxLen = variation === start2 ? -popperRect[len] : -referenceRect[len];
      var arrowElement = state.elements.arrow;
      var arrowRect = tether && arrowElement ? getLayoutRect(arrowElement) : {
        width: 0,
        height: 0
      };
      var arrowPaddingObject = state.modifiersData["arrow#persistent"] ? state.modifiersData["arrow#persistent"].padding : getFreshSideObject();
      var arrowPaddingMin = arrowPaddingObject[mainSide];
      var arrowPaddingMax = arrowPaddingObject[altSide];
      var arrowLen = within(0, referenceRect[len], arrowRect[len]);
      var minOffset = isBasePlacement ? referenceRect[len] / 2 - additive - arrowLen - arrowPaddingMin - normalizedTetherOffsetValue.mainAxis : minLen - arrowLen - arrowPaddingMin - normalizedTetherOffsetValue.mainAxis;
      var maxOffset = isBasePlacement ? -referenceRect[len] / 2 + additive + arrowLen + arrowPaddingMax + normalizedTetherOffsetValue.mainAxis : maxLen + arrowLen + arrowPaddingMax + normalizedTetherOffsetValue.mainAxis;
      var arrowOffsetParent = state.elements.arrow && getOffsetParent(state.elements.arrow);
      var clientOffset = arrowOffsetParent ? mainAxis === "y" ? arrowOffsetParent.clientTop || 0 : arrowOffsetParent.clientLeft || 0 : 0;
      var offsetModifierValue = (_offsetModifierState$ = offsetModifierState == null ? void 0 : offsetModifierState[mainAxis]) != null ? _offsetModifierState$ : 0;
      var tetherMin = offset2 + minOffset - offsetModifierValue - clientOffset;
      var tetherMax = offset2 + maxOffset - offsetModifierValue;
      var preventedOffset = within(tether ? min(min2, tetherMin) : min2, offset2, tether ? max(max2, tetherMax) : max2);
      popperOffsets2[mainAxis] = preventedOffset;
      data[mainAxis] = preventedOffset - offset2;
    }
    if (checkAltAxis) {
      var _offsetModifierState$2;
      var _mainSide = mainAxis === "x" ? top : left;
      var _altSide = mainAxis === "x" ? bottom : right;
      var _offset = popperOffsets2[altAxis];
      var _len = altAxis === "y" ? "height" : "width";
      var _min = _offset + overflow[_mainSide];
      var _max = _offset - overflow[_altSide];
      var isOriginSide = [top, left].indexOf(basePlacement) !== -1;
      var _offsetModifierValue = (_offsetModifierState$2 = offsetModifierState == null ? void 0 : offsetModifierState[altAxis]) != null ? _offsetModifierState$2 : 0;
      var _tetherMin = isOriginSide ? _min : _offset - referenceRect[_len] - popperRect[_len] - _offsetModifierValue + normalizedTetherOffsetValue.altAxis;
      var _tetherMax = isOriginSide ? _offset + referenceRect[_len] + popperRect[_len] - _offsetModifierValue - normalizedTetherOffsetValue.altAxis : _max;
      var _preventedOffset = tether && isOriginSide ? withinMaxClamp(_tetherMin, _offset, _tetherMax) : within(tether ? _tetherMin : _min, _offset, tether ? _tetherMax : _max);
      popperOffsets2[altAxis] = _preventedOffset;
      data[altAxis] = _preventedOffset - _offset;
    }
    state.modifiersData[name] = data;
  }
  var preventOverflow_default = {
    name: "preventOverflow",
    enabled: true,
    phase: "main",
    fn: preventOverflow,
    requiresIfExists: ["offset"]
  };

  // node_modules/@popperjs/core/lib/dom-utils/getHTMLElementScroll.js
  function getHTMLElementScroll(element) {
    return {
      scrollLeft: element.scrollLeft,
      scrollTop: element.scrollTop
    };
  }

  // node_modules/@popperjs/core/lib/dom-utils/getNodeScroll.js
  function getNodeScroll(node) {
    if (node === getWindow(node) || !isHTMLElement(node)) {
      return getWindowScroll(node);
    } else {
      return getHTMLElementScroll(node);
    }
  }

  // node_modules/@popperjs/core/lib/dom-utils/getCompositeRect.js
  function isElementScaled(element) {
    var rect = element.getBoundingClientRect();
    var scaleX = round(rect.width) / element.offsetWidth || 1;
    var scaleY = round(rect.height) / element.offsetHeight || 1;
    return scaleX !== 1 || scaleY !== 1;
  }
  function getCompositeRect(elementOrVirtualElement, offsetParent, isFixed) {
    if (isFixed === void 0) {
      isFixed = false;
    }
    var isOffsetParentAnElement = isHTMLElement(offsetParent);
    var offsetParentIsScaled = isHTMLElement(offsetParent) && isElementScaled(offsetParent);
    var documentElement = getDocumentElement(offsetParent);
    var rect = getBoundingClientRect(elementOrVirtualElement, offsetParentIsScaled, isFixed);
    var scroll = {
      scrollLeft: 0,
      scrollTop: 0
    };
    var offsets = {
      x: 0,
      y: 0
    };
    if (isOffsetParentAnElement || !isOffsetParentAnElement && !isFixed) {
      if (getNodeName(offsetParent) !== "body" || isScrollParent(documentElement)) {
        scroll = getNodeScroll(offsetParent);
      }
      if (isHTMLElement(offsetParent)) {
        offsets = getBoundingClientRect(offsetParent, true);
        offsets.x += offsetParent.clientLeft;
        offsets.y += offsetParent.clientTop;
      } else if (documentElement) {
        offsets.x = getWindowScrollBarX(documentElement);
      }
    }
    return {
      x: rect.left + scroll.scrollLeft - offsets.x,
      y: rect.top + scroll.scrollTop - offsets.y,
      width: rect.width,
      height: rect.height
    };
  }

  // node_modules/@popperjs/core/lib/utils/orderModifiers.js
  function order(modifiers) {
    var map = /* @__PURE__ */ new Map();
    var visited = /* @__PURE__ */ new Set();
    var result = [];
    modifiers.forEach(function(modifier) {
      map.set(modifier.name, modifier);
    });
    function sort(modifier) {
      visited.add(modifier.name);
      var requires = [].concat(modifier.requires || [], modifier.requiresIfExists || []);
      requires.forEach(function(dep) {
        if (!visited.has(dep)) {
          var depModifier = map.get(dep);
          if (depModifier) {
            sort(depModifier);
          }
        }
      });
      result.push(modifier);
    }
    modifiers.forEach(function(modifier) {
      if (!visited.has(modifier.name)) {
        sort(modifier);
      }
    });
    return result;
  }
  function orderModifiers(modifiers) {
    var orderedModifiers = order(modifiers);
    return modifierPhases.reduce(function(acc, phase) {
      return acc.concat(orderedModifiers.filter(function(modifier) {
        return modifier.phase === phase;
      }));
    }, []);
  }

  // node_modules/@popperjs/core/lib/utils/debounce.js
  function debounce(fn2) {
    var pending;
    return function() {
      if (!pending) {
        pending = new Promise(function(resolve) {
          Promise.resolve().then(function() {
            pending = void 0;
            resolve(fn2());
          });
        });
      }
      return pending;
    };
  }

  // node_modules/@popperjs/core/lib/utils/mergeByName.js
  function mergeByName(modifiers) {
    var merged = modifiers.reduce(function(merged2, current) {
      var existing = merged2[current.name];
      merged2[current.name] = existing ? Object.assign({}, existing, current, {
        options: Object.assign({}, existing.options, current.options),
        data: Object.assign({}, existing.data, current.data)
      }) : current;
      return merged2;
    }, {});
    return Object.keys(merged).map(function(key) {
      return merged[key];
    });
  }

  // node_modules/@popperjs/core/lib/createPopper.js
  var DEFAULT_OPTIONS = {
    placement: "bottom",
    modifiers: [],
    strategy: "absolute"
  };
  function areValidElements() {
    for (var _len = arguments.length, args = new Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }
    return !args.some(function(element) {
      return !(element && typeof element.getBoundingClientRect === "function");
    });
  }
  function popperGenerator(generatorOptions) {
    if (generatorOptions === void 0) {
      generatorOptions = {};
    }
    var _generatorOptions = generatorOptions, _generatorOptions$def = _generatorOptions.defaultModifiers, defaultModifiers3 = _generatorOptions$def === void 0 ? [] : _generatorOptions$def, _generatorOptions$def2 = _generatorOptions.defaultOptions, defaultOptions2 = _generatorOptions$def2 === void 0 ? DEFAULT_OPTIONS : _generatorOptions$def2;
    return function createPopper4(reference2, popper2, options) {
      if (options === void 0) {
        options = defaultOptions2;
      }
      var state = {
        placement: "bottom",
        orderedModifiers: [],
        options: Object.assign({}, DEFAULT_OPTIONS, defaultOptions2),
        modifiersData: {},
        elements: {
          reference: reference2,
          popper: popper2
        },
        attributes: {},
        styles: {}
      };
      var effectCleanupFns = [];
      var isDestroyed = false;
      var instance = {
        state,
        setOptions: function setOptions(setOptionsAction) {
          var options2 = typeof setOptionsAction === "function" ? setOptionsAction(state.options) : setOptionsAction;
          cleanupModifierEffects();
          state.options = Object.assign({}, defaultOptions2, state.options, options2);
          state.scrollParents = {
            reference: isElement(reference2) ? listScrollParents(reference2) : reference2.contextElement ? listScrollParents(reference2.contextElement) : [],
            popper: listScrollParents(popper2)
          };
          var orderedModifiers = orderModifiers(mergeByName([].concat(defaultModifiers3, state.options.modifiers)));
          state.orderedModifiers = orderedModifiers.filter(function(m) {
            return m.enabled;
          });
          runModifierEffects();
          return instance.update();
        },
        forceUpdate: function forceUpdate() {
          if (isDestroyed) {
            return;
          }
          var _state$elements = state.elements, reference3 = _state$elements.reference, popper3 = _state$elements.popper;
          if (!areValidElements(reference3, popper3)) {
            return;
          }
          state.rects = {
            reference: getCompositeRect(reference3, getOffsetParent(popper3), state.options.strategy === "fixed"),
            popper: getLayoutRect(popper3)
          };
          state.reset = false;
          state.placement = state.options.placement;
          state.orderedModifiers.forEach(function(modifier) {
            return state.modifiersData[modifier.name] = Object.assign({}, modifier.data);
          });
          for (var index = 0; index < state.orderedModifiers.length; index++) {
            if (state.reset === true) {
              state.reset = false;
              index = -1;
              continue;
            }
            var _state$orderedModifie = state.orderedModifiers[index], fn2 = _state$orderedModifie.fn, _state$orderedModifie2 = _state$orderedModifie.options, _options = _state$orderedModifie2 === void 0 ? {} : _state$orderedModifie2, name = _state$orderedModifie.name;
            if (typeof fn2 === "function") {
              state = fn2({
                state,
                options: _options,
                name,
                instance
              }) || state;
            }
          }
        },
        update: debounce(function() {
          return new Promise(function(resolve) {
            instance.forceUpdate();
            resolve(state);
          });
        }),
        destroy: function destroy2() {
          cleanupModifierEffects();
          isDestroyed = true;
        }
      };
      if (!areValidElements(reference2, popper2)) {
        return instance;
      }
      instance.setOptions(options).then(function(state2) {
        if (!isDestroyed && options.onFirstUpdate) {
          options.onFirstUpdate(state2);
        }
      });
      function runModifierEffects() {
        state.orderedModifiers.forEach(function(_ref) {
          var name = _ref.name, _ref$options = _ref.options, options2 = _ref$options === void 0 ? {} : _ref$options, effect4 = _ref.effect;
          if (typeof effect4 === "function") {
            var cleanupFn = effect4({
              state,
              name,
              instance,
              options: options2
            });
            var noopFn = function noopFn2() {
            };
            effectCleanupFns.push(cleanupFn || noopFn);
          }
        });
      }
      function cleanupModifierEffects() {
        effectCleanupFns.forEach(function(fn2) {
          return fn2();
        });
        effectCleanupFns = [];
      }
      return instance;
    };
  }
  var createPopper = /* @__PURE__ */ popperGenerator();

  // node_modules/@popperjs/core/lib/popper-lite.js
  var defaultModifiers = [eventListeners_default, popperOffsets_default, computeStyles_default, applyStyles_default];
  var createPopper2 = /* @__PURE__ */ popperGenerator({
    defaultModifiers
  });

  // node_modules/@popperjs/core/lib/popper.js
  var defaultModifiers2 = [eventListeners_default, popperOffsets_default, computeStyles_default, applyStyles_default, offset_default, flip_default, preventOverflow_default, arrow_default, hide_default];
  var createPopper3 = /* @__PURE__ */ popperGenerator({
    defaultModifiers: defaultModifiers2
  });

  // app/javascript/controllers/dob_controller.js
  var dob_controller_default = class extends Controller {
    lastInputs = { year: "", month: "", day: "" };
    connect() {
      this.disableInputs();
    }
    disableInputs() {
      this.monthTarget.disabled = true;
      this.dayTarget.disabled = true;
    }
    enableMonth() {
      this.monthTarget.disabled = false;
      this.monthTarget.focus();
    }
    enableDay() {
      this.dayTarget.disabled = false;
      this.dayTarget.focus();
    }
    updateAge(event) {
      const year = this.yearTarget.value;
      const month = this.monthTarget.value;
      const day = this.dayTarget.value;
      if (this.shouldEnableMonth(year)) {
        this.setLastInputs();
        this.enableMonth();
      }
      if (this.shouldEnableDay(year, month)) {
        this.setLastInputs();
        this.enableDay();
      }
      if (this.isValidYear(year) && this.isValidDate(year, month, day)) {
        const age = this.currentAge(year, month, day);
        this.outputTarget.textContent = `Current age: ${age}`;
      } else {
        this.outputTarget.textContent = ``;
      }
      this.dispatch("checkForm");
    }
    shouldEnableMonth(year) {
      return this.isValidYear(year) && this.lastInputs.year !== year;
    }
    shouldEnableDay(year, month) {
      return month.length == 2 && this.isValidMonth(month) && this.isValidYear(year) && (this.lastInputs.month !== month || this.lastInputs.year !== year);
    }
    isValidYear(year) {
      const currentYear = new Date().getFullYear();
      return /^[12][0-9]{3}$/.test(year) && year <= currentYear && year >= currentYear - 100;
    }
    isValidMonth(month) {
      return /^0?[1-9]$|^1[0-2]$/.test(month);
    }
    isValidDate(year, month, day) {
      const date2 = new Date(year, month - 1, day);
      return year.length == 4 && month.length == 2 && day.length == 2 && date2.getFullYear() == year && date2.getMonth() == month - 1 && date2.getDate() == day;
    }
    currentAge(b_year, b_month, b_day) {
      let today = new Date();
      let birthDate = new Date(b_year, b_month - 1, b_day);
      let age = today.getFullYear() - birthDate.getFullYear();
      let month = today.getMonth() - birthDate.getMonth();
      if (month < 0 || month === 0 && today.getDate() < birthDate.getDate()) {
        age--;
      }
      return age;
    }
    disconnect() {
      this.lastInputs = { year: "", month: "", day: "" };
    }
    setLastInputs() {
      this.lastInputs = {
        year: this.yearTarget.value,
        month: this.monthTarget.value,
        day: this.dayTarget.value
      };
    }
  };
  __publicField(dob_controller_default, "targets", ["year", "month", "day", "output"]);

  // app/javascript/controllers/gender_check_controller.js
  var gender_check_controller_default = class extends Controller {
    connect() {
      this.inputTarget.focus();
      this.indicateSelection();
    }
    indicateSelection() {
      if (this.inputTarget.value == 0) {
        this.outputTarget.style.display = "none";
      } else {
        this.outputTarget.style.display = "";
      }
    }
  };
  __publicField(gender_check_controller_default, "targets", ["output", "input"]);

  // app/javascript/controllers/guide_splide_controller.js
  var guide_splide_controller_default = class extends Controller {
    connect() {
      console.log("guide_splide here");
      window.guide_splide = new Splide(this.element, {
        type: "loop",
        autoplay: true,
        gap: 40,
        mediaQuery: "min",
        perPage: 3,
        arrows: false,
        breakpoints: {
          800: {
            perPage: 2
          },
          600: {
            perPage: 1
          }
        }
      });
      window.guide_splide.mount();
    }
  };

  // app/javascript/controllers/link_jump_controller.js
  var link_jump_controller_default = class extends Controller {
    connect() {
      setTimeout(() => {
        this.jumpToURL();
      }, 1500);
    }
    jumpToURL() {
      window.open(this.jumpUrlValue, "_self");
    }
  };
  __publicField(link_jump_controller_default, "values", {
    offerId: Number,
    jumpUrl: String,
    splitCode: String,
    ip: String,
    originalUrl: String
  });

  // node_modules/bootstrap/dist/js/bootstrap.esm.js
  var elementMap = /* @__PURE__ */ new Map();
  var Data = {
    set(element, key, instance) {
      if (!elementMap.has(element)) {
        elementMap.set(element, /* @__PURE__ */ new Map());
      }
      const instanceMap = elementMap.get(element);
      if (!instanceMap.has(key) && instanceMap.size !== 0) {
        console.error(`Bootstrap doesn't allow more than one instance per element. Bound instance: ${Array.from(instanceMap.keys())[0]}.`);
        return;
      }
      instanceMap.set(key, instance);
    },
    get(element, key) {
      if (elementMap.has(element)) {
        return elementMap.get(element).get(key) || null;
      }
      return null;
    },
    remove(element, key) {
      if (!elementMap.has(element)) {
        return;
      }
      const instanceMap = elementMap.get(element);
      instanceMap.delete(key);
      if (instanceMap.size === 0) {
        elementMap.delete(element);
      }
    }
  };
  var MAX_UID = 1e6;
  var MILLISECONDS_MULTIPLIER = 1e3;
  var TRANSITION_END = "transitionend";
  var parseSelector = (selector) => {
    if (selector && window.CSS && window.CSS.escape) {
      selector = selector.replace(/#([^\s"#']+)/g, (match, id) => `#${CSS.escape(id)}`);
    }
    return selector;
  };
  var toType = (object) => {
    if (object === null || object === void 0) {
      return `${object}`;
    }
    return Object.prototype.toString.call(object).match(/\s([a-z]+)/i)[1].toLowerCase();
  };
  var getUID = (prefix) => {
    do {
      prefix += Math.floor(Math.random() * MAX_UID);
    } while (document.getElementById(prefix));
    return prefix;
  };
  var getTransitionDurationFromElement = (element) => {
    if (!element) {
      return 0;
    }
    let {
      transitionDuration,
      transitionDelay
    } = window.getComputedStyle(element);
    const floatTransitionDuration = Number.parseFloat(transitionDuration);
    const floatTransitionDelay = Number.parseFloat(transitionDelay);
    if (!floatTransitionDuration && !floatTransitionDelay) {
      return 0;
    }
    transitionDuration = transitionDuration.split(",")[0];
    transitionDelay = transitionDelay.split(",")[0];
    return (Number.parseFloat(transitionDuration) + Number.parseFloat(transitionDelay)) * MILLISECONDS_MULTIPLIER;
  };
  var triggerTransitionEnd = (element) => {
    element.dispatchEvent(new Event(TRANSITION_END));
  };
  var isElement2 = (object) => {
    if (!object || typeof object !== "object") {
      return false;
    }
    if (typeof object.jquery !== "undefined") {
      object = object[0];
    }
    return typeof object.nodeType !== "undefined";
  };
  var getElement = (object) => {
    if (isElement2(object)) {
      return object.jquery ? object[0] : object;
    }
    if (typeof object === "string" && object.length > 0) {
      return document.querySelector(parseSelector(object));
    }
    return null;
  };
  var isVisible = (element) => {
    if (!isElement2(element) || element.getClientRects().length === 0) {
      return false;
    }
    const elementIsVisible = getComputedStyle(element).getPropertyValue("visibility") === "visible";
    const closedDetails = element.closest("details:not([open])");
    if (!closedDetails) {
      return elementIsVisible;
    }
    if (closedDetails !== element) {
      const summary = element.closest("summary");
      if (summary && summary.parentNode !== closedDetails) {
        return false;
      }
      if (summary === null) {
        return false;
      }
    }
    return elementIsVisible;
  };
  var isDisabled = (element) => {
    if (!element || element.nodeType !== Node.ELEMENT_NODE) {
      return true;
    }
    if (element.classList.contains("disabled")) {
      return true;
    }
    if (typeof element.disabled !== "undefined") {
      return element.disabled;
    }
    return element.hasAttribute("disabled") && element.getAttribute("disabled") !== "false";
  };
  var findShadowRoot = (element) => {
    if (!document.documentElement.attachShadow) {
      return null;
    }
    if (typeof element.getRootNode === "function") {
      const root = element.getRootNode();
      return root instanceof ShadowRoot ? root : null;
    }
    if (element instanceof ShadowRoot) {
      return element;
    }
    if (!element.parentNode) {
      return null;
    }
    return findShadowRoot(element.parentNode);
  };
  var noop = () => {
  };
  var reflow = (element) => {
    element.offsetHeight;
  };
  var getjQuery = () => {
    if (window.jQuery && !document.body.hasAttribute("data-bs-no-jquery")) {
      return window.jQuery;
    }
    return null;
  };
  var DOMContentLoadedCallbacks = [];
  var onDOMContentLoaded = (callback) => {
    if (document.readyState === "loading") {
      if (!DOMContentLoadedCallbacks.length) {
        document.addEventListener("DOMContentLoaded", () => {
          for (const callback2 of DOMContentLoadedCallbacks) {
            callback2();
          }
        });
      }
      DOMContentLoadedCallbacks.push(callback);
    } else {
      callback();
    }
  };
  var isRTL = () => document.documentElement.dir === "rtl";
  var defineJQueryPlugin = (plugin) => {
    onDOMContentLoaded(() => {
      const $ = getjQuery();
      if ($) {
        const name = plugin.NAME;
        const JQUERY_NO_CONFLICT = $.fn[name];
        $.fn[name] = plugin.jQueryInterface;
        $.fn[name].Constructor = plugin;
        $.fn[name].noConflict = () => {
          $.fn[name] = JQUERY_NO_CONFLICT;
          return plugin.jQueryInterface;
        };
      }
    });
  };
  var execute = (possibleCallback, args = [], defaultValue = possibleCallback) => {
    return typeof possibleCallback === "function" ? possibleCallback(...args) : defaultValue;
  };
  var executeAfterTransition = (callback, transitionElement, waitForTransition = true) => {
    if (!waitForTransition) {
      execute(callback);
      return;
    }
    const durationPadding = 5;
    const emulatedDuration = getTransitionDurationFromElement(transitionElement) + durationPadding;
    let called = false;
    const handler = ({
      target
    }) => {
      if (target !== transitionElement) {
        return;
      }
      called = true;
      transitionElement.removeEventListener(TRANSITION_END, handler);
      execute(callback);
    };
    transitionElement.addEventListener(TRANSITION_END, handler);
    setTimeout(() => {
      if (!called) {
        triggerTransitionEnd(transitionElement);
      }
    }, emulatedDuration);
  };
  var getNextActiveElement = (list, activeElement, shouldGetNext, isCycleAllowed) => {
    const listLength = list.length;
    let index = list.indexOf(activeElement);
    if (index === -1) {
      return !shouldGetNext && isCycleAllowed ? list[listLength - 1] : list[0];
    }
    index += shouldGetNext ? 1 : -1;
    if (isCycleAllowed) {
      index = (index + listLength) % listLength;
    }
    return list[Math.max(0, Math.min(index, listLength - 1))];
  };
  var namespaceRegex = /[^.]*(?=\..*)\.|.*/;
  var stripNameRegex = /\..*/;
  var stripUidRegex = /::\d+$/;
  var eventRegistry = {};
  var uidEvent = 1;
  var customEvents = {
    mouseenter: "mouseover",
    mouseleave: "mouseout"
  };
  var nativeEvents = /* @__PURE__ */ new Set(["click", "dblclick", "mouseup", "mousedown", "contextmenu", "mousewheel", "DOMMouseScroll", "mouseover", "mouseout", "mousemove", "selectstart", "selectend", "keydown", "keypress", "keyup", "orientationchange", "touchstart", "touchmove", "touchend", "touchcancel", "pointerdown", "pointermove", "pointerup", "pointerleave", "pointercancel", "gesturestart", "gesturechange", "gestureend", "focus", "blur", "change", "reset", "select", "submit", "focusin", "focusout", "load", "unload", "beforeunload", "resize", "move", "DOMContentLoaded", "readystatechange", "error", "abort", "scroll"]);
  function makeEventUid(element, uid) {
    return uid && `${uid}::${uidEvent++}` || element.uidEvent || uidEvent++;
  }
  function getElementEvents(element) {
    const uid = makeEventUid(element);
    element.uidEvent = uid;
    eventRegistry[uid] = eventRegistry[uid] || {};
    return eventRegistry[uid];
  }
  function bootstrapHandler(element, fn2) {
    return function handler(event) {
      hydrateObj(event, {
        delegateTarget: element
      });
      if (handler.oneOff) {
        EventHandler.off(element, event.type, fn2);
      }
      return fn2.apply(element, [event]);
    };
  }
  function bootstrapDelegationHandler(element, selector, fn2) {
    return function handler(event) {
      const domElements = element.querySelectorAll(selector);
      for (let {
        target
      } = event; target && target !== this; target = target.parentNode) {
        for (const domElement of domElements) {
          if (domElement !== target) {
            continue;
          }
          hydrateObj(event, {
            delegateTarget: target
          });
          if (handler.oneOff) {
            EventHandler.off(element, event.type, selector, fn2);
          }
          return fn2.apply(target, [event]);
        }
      }
    };
  }
  function findHandler(events, callable, delegationSelector = null) {
    return Object.values(events).find((event) => event.callable === callable && event.delegationSelector === delegationSelector);
  }
  function normalizeParameters(originalTypeEvent, handler, delegationFunction) {
    const isDelegated = typeof handler === "string";
    const callable = isDelegated ? delegationFunction : handler || delegationFunction;
    let typeEvent = getTypeEvent(originalTypeEvent);
    if (!nativeEvents.has(typeEvent)) {
      typeEvent = originalTypeEvent;
    }
    return [isDelegated, callable, typeEvent];
  }
  function addHandler(element, originalTypeEvent, handler, delegationFunction, oneOff) {
    if (typeof originalTypeEvent !== "string" || !element) {
      return;
    }
    let [isDelegated, callable, typeEvent] = normalizeParameters(originalTypeEvent, handler, delegationFunction);
    if (originalTypeEvent in customEvents) {
      const wrapFunction = (fn3) => {
        return function(event) {
          if (!event.relatedTarget || event.relatedTarget !== event.delegateTarget && !event.delegateTarget.contains(event.relatedTarget)) {
            return fn3.call(this, event);
          }
        };
      };
      callable = wrapFunction(callable);
    }
    const events = getElementEvents(element);
    const handlers = events[typeEvent] || (events[typeEvent] = {});
    const previousFunction = findHandler(handlers, callable, isDelegated ? handler : null);
    if (previousFunction) {
      previousFunction.oneOff = previousFunction.oneOff && oneOff;
      return;
    }
    const uid = makeEventUid(callable, originalTypeEvent.replace(namespaceRegex, ""));
    const fn2 = isDelegated ? bootstrapDelegationHandler(element, handler, callable) : bootstrapHandler(element, callable);
    fn2.delegationSelector = isDelegated ? handler : null;
    fn2.callable = callable;
    fn2.oneOff = oneOff;
    fn2.uidEvent = uid;
    handlers[uid] = fn2;
    element.addEventListener(typeEvent, fn2, isDelegated);
  }
  function removeHandler(element, events, typeEvent, handler, delegationSelector) {
    const fn2 = findHandler(events[typeEvent], handler, delegationSelector);
    if (!fn2) {
      return;
    }
    element.removeEventListener(typeEvent, fn2, Boolean(delegationSelector));
    delete events[typeEvent][fn2.uidEvent];
  }
  function removeNamespacedHandlers(element, events, typeEvent, namespace) {
    const storeElementEvent = events[typeEvent] || {};
    for (const [handlerKey, event] of Object.entries(storeElementEvent)) {
      if (handlerKey.includes(namespace)) {
        removeHandler(element, events, typeEvent, event.callable, event.delegationSelector);
      }
    }
  }
  function getTypeEvent(event) {
    event = event.replace(stripNameRegex, "");
    return customEvents[event] || event;
  }
  var EventHandler = {
    on(element, event, handler, delegationFunction) {
      addHandler(element, event, handler, delegationFunction, false);
    },
    one(element, event, handler, delegationFunction) {
      addHandler(element, event, handler, delegationFunction, true);
    },
    off(element, originalTypeEvent, handler, delegationFunction) {
      if (typeof originalTypeEvent !== "string" || !element) {
        return;
      }
      const [isDelegated, callable, typeEvent] = normalizeParameters(originalTypeEvent, handler, delegationFunction);
      const inNamespace = typeEvent !== originalTypeEvent;
      const events = getElementEvents(element);
      const storeElementEvent = events[typeEvent] || {};
      const isNamespace = originalTypeEvent.startsWith(".");
      if (typeof callable !== "undefined") {
        if (!Object.keys(storeElementEvent).length) {
          return;
        }
        removeHandler(element, events, typeEvent, callable, isDelegated ? handler : null);
        return;
      }
      if (isNamespace) {
        for (const elementEvent of Object.keys(events)) {
          removeNamespacedHandlers(element, events, elementEvent, originalTypeEvent.slice(1));
        }
      }
      for (const [keyHandlers, event] of Object.entries(storeElementEvent)) {
        const handlerKey = keyHandlers.replace(stripUidRegex, "");
        if (!inNamespace || originalTypeEvent.includes(handlerKey)) {
          removeHandler(element, events, typeEvent, event.callable, event.delegationSelector);
        }
      }
    },
    trigger(element, event, args) {
      if (typeof event !== "string" || !element) {
        return null;
      }
      const $ = getjQuery();
      const typeEvent = getTypeEvent(event);
      const inNamespace = event !== typeEvent;
      let jQueryEvent = null;
      let bubbles = true;
      let nativeDispatch = true;
      let defaultPrevented = false;
      if (inNamespace && $) {
        jQueryEvent = $.Event(event, args);
        $(element).trigger(jQueryEvent);
        bubbles = !jQueryEvent.isPropagationStopped();
        nativeDispatch = !jQueryEvent.isImmediatePropagationStopped();
        defaultPrevented = jQueryEvent.isDefaultPrevented();
      }
      const evt = hydrateObj(new Event(event, {
        bubbles,
        cancelable: true
      }), args);
      if (defaultPrevented) {
        evt.preventDefault();
      }
      if (nativeDispatch) {
        element.dispatchEvent(evt);
      }
      if (evt.defaultPrevented && jQueryEvent) {
        jQueryEvent.preventDefault();
      }
      return evt;
    }
  };
  function hydrateObj(obj, meta = {}) {
    for (const [key, value] of Object.entries(meta)) {
      try {
        obj[key] = value;
      } catch (_unused) {
        Object.defineProperty(obj, key, {
          configurable: true,
          get() {
            return value;
          }
        });
      }
    }
    return obj;
  }
  function normalizeData(value) {
    if (value === "true") {
      return true;
    }
    if (value === "false") {
      return false;
    }
    if (value === Number(value).toString()) {
      return Number(value);
    }
    if (value === "" || value === "null") {
      return null;
    }
    if (typeof value !== "string") {
      return value;
    }
    try {
      return JSON.parse(decodeURIComponent(value));
    } catch (_unused) {
      return value;
    }
  }
  function normalizeDataKey(key) {
    return key.replace(/[A-Z]/g, (chr) => `-${chr.toLowerCase()}`);
  }
  var Manipulator = {
    setDataAttribute(element, key, value) {
      element.setAttribute(`data-bs-${normalizeDataKey(key)}`, value);
    },
    removeDataAttribute(element, key) {
      element.removeAttribute(`data-bs-${normalizeDataKey(key)}`);
    },
    getDataAttributes(element) {
      if (!element) {
        return {};
      }
      const attributes = {};
      const bsKeys = Object.keys(element.dataset).filter((key) => key.startsWith("bs") && !key.startsWith("bsConfig"));
      for (const key of bsKeys) {
        let pureKey = key.replace(/^bs/, "");
        pureKey = pureKey.charAt(0).toLowerCase() + pureKey.slice(1, pureKey.length);
        attributes[pureKey] = normalizeData(element.dataset[key]);
      }
      return attributes;
    },
    getDataAttribute(element, key) {
      return normalizeData(element.getAttribute(`data-bs-${normalizeDataKey(key)}`));
    }
  };
  var Config = class {
    static get Default() {
      return {};
    }
    static get DefaultType() {
      return {};
    }
    static get NAME() {
      throw new Error('You have to implement the static method "NAME", for each component!');
    }
    _getConfig(config) {
      config = this._mergeConfigObj(config);
      config = this._configAfterMerge(config);
      this._typeCheckConfig(config);
      return config;
    }
    _configAfterMerge(config) {
      return config;
    }
    _mergeConfigObj(config, element) {
      const jsonConfig = isElement2(element) ? Manipulator.getDataAttribute(element, "config") : {};
      return {
        ...this.constructor.Default,
        ...typeof jsonConfig === "object" ? jsonConfig : {},
        ...isElement2(element) ? Manipulator.getDataAttributes(element) : {},
        ...typeof config === "object" ? config : {}
      };
    }
    _typeCheckConfig(config, configTypes = this.constructor.DefaultType) {
      for (const [property, expectedTypes] of Object.entries(configTypes)) {
        const value = config[property];
        const valueType = isElement2(value) ? "element" : toType(value);
        if (!new RegExp(expectedTypes).test(valueType)) {
          throw new TypeError(`${this.constructor.NAME.toUpperCase()}: Option "${property}" provided type "${valueType}" but expected type "${expectedTypes}".`);
        }
      }
    }
  };
  var VERSION = "5.3.3";
  var BaseComponent = class extends Config {
    constructor(element, config) {
      super();
      element = getElement(element);
      if (!element) {
        return;
      }
      this._element = element;
      this._config = this._getConfig(config);
      Data.set(this._element, this.constructor.DATA_KEY, this);
    }
    dispose() {
      Data.remove(this._element, this.constructor.DATA_KEY);
      EventHandler.off(this._element, this.constructor.EVENT_KEY);
      for (const propertyName of Object.getOwnPropertyNames(this)) {
        this[propertyName] = null;
      }
    }
    _queueCallback(callback, element, isAnimated = true) {
      executeAfterTransition(callback, element, isAnimated);
    }
    _getConfig(config) {
      config = this._mergeConfigObj(config, this._element);
      config = this._configAfterMerge(config);
      this._typeCheckConfig(config);
      return config;
    }
    static getInstance(element) {
      return Data.get(getElement(element), this.DATA_KEY);
    }
    static getOrCreateInstance(element, config = {}) {
      return this.getInstance(element) || new this(element, typeof config === "object" ? config : null);
    }
    static get VERSION() {
      return VERSION;
    }
    static get DATA_KEY() {
      return `bs.${this.NAME}`;
    }
    static get EVENT_KEY() {
      return `.${this.DATA_KEY}`;
    }
    static eventName(name) {
      return `${name}${this.EVENT_KEY}`;
    }
  };
  var getSelector = (element) => {
    let selector = element.getAttribute("data-bs-target");
    if (!selector || selector === "#") {
      let hrefAttribute = element.getAttribute("href");
      if (!hrefAttribute || !hrefAttribute.includes("#") && !hrefAttribute.startsWith(".")) {
        return null;
      }
      if (hrefAttribute.includes("#") && !hrefAttribute.startsWith("#")) {
        hrefAttribute = `#${hrefAttribute.split("#")[1]}`;
      }
      selector = hrefAttribute && hrefAttribute !== "#" ? hrefAttribute.trim() : null;
    }
    return selector ? selector.split(",").map((sel) => parseSelector(sel)).join(",") : null;
  };
  var SelectorEngine = {
    find(selector, element = document.documentElement) {
      return [].concat(...Element.prototype.querySelectorAll.call(element, selector));
    },
    findOne(selector, element = document.documentElement) {
      return Element.prototype.querySelector.call(element, selector);
    },
    children(element, selector) {
      return [].concat(...element.children).filter((child) => child.matches(selector));
    },
    parents(element, selector) {
      const parents = [];
      let ancestor = element.parentNode.closest(selector);
      while (ancestor) {
        parents.push(ancestor);
        ancestor = ancestor.parentNode.closest(selector);
      }
      return parents;
    },
    prev(element, selector) {
      let previous = element.previousElementSibling;
      while (previous) {
        if (previous.matches(selector)) {
          return [previous];
        }
        previous = previous.previousElementSibling;
      }
      return [];
    },
    next(element, selector) {
      let next = element.nextElementSibling;
      while (next) {
        if (next.matches(selector)) {
          return [next];
        }
        next = next.nextElementSibling;
      }
      return [];
    },
    focusableChildren(element) {
      const focusables = ["a", "button", "input", "textarea", "select", "details", "[tabindex]", '[contenteditable="true"]'].map((selector) => `${selector}:not([tabindex^="-"])`).join(",");
      return this.find(focusables, element).filter((el) => !isDisabled(el) && isVisible(el));
    },
    getSelectorFromElement(element) {
      const selector = getSelector(element);
      if (selector) {
        return SelectorEngine.findOne(selector) ? selector : null;
      }
      return null;
    },
    getElementFromSelector(element) {
      const selector = getSelector(element);
      return selector ? SelectorEngine.findOne(selector) : null;
    },
    getMultipleElementsFromSelector(element) {
      const selector = getSelector(element);
      return selector ? SelectorEngine.find(selector) : [];
    }
  };
  var enableDismissTrigger = (component, method = "hide") => {
    const clickEvent = `click.dismiss${component.EVENT_KEY}`;
    const name = component.NAME;
    EventHandler.on(document, clickEvent, `[data-bs-dismiss="${name}"]`, function(event) {
      if (["A", "AREA"].includes(this.tagName)) {
        event.preventDefault();
      }
      if (isDisabled(this)) {
        return;
      }
      const target = SelectorEngine.getElementFromSelector(this) || this.closest(`.${name}`);
      const instance = component.getOrCreateInstance(target);
      instance[method]();
    });
  };
  var NAME$f = "alert";
  var DATA_KEY$a = "bs.alert";
  var EVENT_KEY$b = `.${DATA_KEY$a}`;
  var EVENT_CLOSE = `close${EVENT_KEY$b}`;
  var EVENT_CLOSED = `closed${EVENT_KEY$b}`;
  var CLASS_NAME_FADE$5 = "fade";
  var CLASS_NAME_SHOW$8 = "show";
  var Alert = class extends BaseComponent {
    static get NAME() {
      return NAME$f;
    }
    close() {
      const closeEvent = EventHandler.trigger(this._element, EVENT_CLOSE);
      if (closeEvent.defaultPrevented) {
        return;
      }
      this._element.classList.remove(CLASS_NAME_SHOW$8);
      const isAnimated = this._element.classList.contains(CLASS_NAME_FADE$5);
      this._queueCallback(() => this._destroyElement(), this._element, isAnimated);
    }
    _destroyElement() {
      this._element.remove();
      EventHandler.trigger(this._element, EVENT_CLOSED);
      this.dispose();
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Alert.getOrCreateInstance(this);
        if (typeof config !== "string") {
          return;
        }
        if (data[config] === void 0 || config.startsWith("_") || config === "constructor") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config](this);
      });
    }
  };
  enableDismissTrigger(Alert, "close");
  defineJQueryPlugin(Alert);
  var NAME$e = "button";
  var DATA_KEY$9 = "bs.button";
  var EVENT_KEY$a = `.${DATA_KEY$9}`;
  var DATA_API_KEY$6 = ".data-api";
  var CLASS_NAME_ACTIVE$3 = "active";
  var SELECTOR_DATA_TOGGLE$5 = '[data-bs-toggle="button"]';
  var EVENT_CLICK_DATA_API$6 = `click${EVENT_KEY$a}${DATA_API_KEY$6}`;
  var Button = class extends BaseComponent {
    static get NAME() {
      return NAME$e;
    }
    toggle() {
      this._element.setAttribute("aria-pressed", this._element.classList.toggle(CLASS_NAME_ACTIVE$3));
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Button.getOrCreateInstance(this);
        if (config === "toggle") {
          data[config]();
        }
      });
    }
  };
  EventHandler.on(document, EVENT_CLICK_DATA_API$6, SELECTOR_DATA_TOGGLE$5, (event) => {
    event.preventDefault();
    const button = event.target.closest(SELECTOR_DATA_TOGGLE$5);
    const data = Button.getOrCreateInstance(button);
    data.toggle();
  });
  defineJQueryPlugin(Button);
  var NAME$d = "swipe";
  var EVENT_KEY$9 = ".bs.swipe";
  var EVENT_TOUCHSTART = `touchstart${EVENT_KEY$9}`;
  var EVENT_TOUCHMOVE = `touchmove${EVENT_KEY$9}`;
  var EVENT_TOUCHEND = `touchend${EVENT_KEY$9}`;
  var EVENT_POINTERDOWN = `pointerdown${EVENT_KEY$9}`;
  var EVENT_POINTERUP = `pointerup${EVENT_KEY$9}`;
  var POINTER_TYPE_TOUCH = "touch";
  var POINTER_TYPE_PEN = "pen";
  var CLASS_NAME_POINTER_EVENT = "pointer-event";
  var SWIPE_THRESHOLD = 40;
  var Default$c = {
    endCallback: null,
    leftCallback: null,
    rightCallback: null
  };
  var DefaultType$c = {
    endCallback: "(function|null)",
    leftCallback: "(function|null)",
    rightCallback: "(function|null)"
  };
  var Swipe = class extends Config {
    constructor(element, config) {
      super();
      this._element = element;
      if (!element || !Swipe.isSupported()) {
        return;
      }
      this._config = this._getConfig(config);
      this._deltaX = 0;
      this._supportPointerEvents = Boolean(window.PointerEvent);
      this._initEvents();
    }
    static get Default() {
      return Default$c;
    }
    static get DefaultType() {
      return DefaultType$c;
    }
    static get NAME() {
      return NAME$d;
    }
    dispose() {
      EventHandler.off(this._element, EVENT_KEY$9);
    }
    _start(event) {
      if (!this._supportPointerEvents) {
        this._deltaX = event.touches[0].clientX;
        return;
      }
      if (this._eventIsPointerPenTouch(event)) {
        this._deltaX = event.clientX;
      }
    }
    _end(event) {
      if (this._eventIsPointerPenTouch(event)) {
        this._deltaX = event.clientX - this._deltaX;
      }
      this._handleSwipe();
      execute(this._config.endCallback);
    }
    _move(event) {
      this._deltaX = event.touches && event.touches.length > 1 ? 0 : event.touches[0].clientX - this._deltaX;
    }
    _handleSwipe() {
      const absDeltaX = Math.abs(this._deltaX);
      if (absDeltaX <= SWIPE_THRESHOLD) {
        return;
      }
      const direction = absDeltaX / this._deltaX;
      this._deltaX = 0;
      if (!direction) {
        return;
      }
      execute(direction > 0 ? this._config.rightCallback : this._config.leftCallback);
    }
    _initEvents() {
      if (this._supportPointerEvents) {
        EventHandler.on(this._element, EVENT_POINTERDOWN, (event) => this._start(event));
        EventHandler.on(this._element, EVENT_POINTERUP, (event) => this._end(event));
        this._element.classList.add(CLASS_NAME_POINTER_EVENT);
      } else {
        EventHandler.on(this._element, EVENT_TOUCHSTART, (event) => this._start(event));
        EventHandler.on(this._element, EVENT_TOUCHMOVE, (event) => this._move(event));
        EventHandler.on(this._element, EVENT_TOUCHEND, (event) => this._end(event));
      }
    }
    _eventIsPointerPenTouch(event) {
      return this._supportPointerEvents && (event.pointerType === POINTER_TYPE_PEN || event.pointerType === POINTER_TYPE_TOUCH);
    }
    static isSupported() {
      return "ontouchstart" in document.documentElement || navigator.maxTouchPoints > 0;
    }
  };
  var NAME$c = "carousel";
  var DATA_KEY$8 = "bs.carousel";
  var EVENT_KEY$8 = `.${DATA_KEY$8}`;
  var DATA_API_KEY$5 = ".data-api";
  var ARROW_LEFT_KEY$1 = "ArrowLeft";
  var ARROW_RIGHT_KEY$1 = "ArrowRight";
  var TOUCHEVENT_COMPAT_WAIT = 500;
  var ORDER_NEXT = "next";
  var ORDER_PREV = "prev";
  var DIRECTION_LEFT = "left";
  var DIRECTION_RIGHT = "right";
  var EVENT_SLIDE = `slide${EVENT_KEY$8}`;
  var EVENT_SLID = `slid${EVENT_KEY$8}`;
  var EVENT_KEYDOWN$1 = `keydown${EVENT_KEY$8}`;
  var EVENT_MOUSEENTER$1 = `mouseenter${EVENT_KEY$8}`;
  var EVENT_MOUSELEAVE$1 = `mouseleave${EVENT_KEY$8}`;
  var EVENT_DRAG_START = `dragstart${EVENT_KEY$8}`;
  var EVENT_LOAD_DATA_API$3 = `load${EVENT_KEY$8}${DATA_API_KEY$5}`;
  var EVENT_CLICK_DATA_API$5 = `click${EVENT_KEY$8}${DATA_API_KEY$5}`;
  var CLASS_NAME_CAROUSEL = "carousel";
  var CLASS_NAME_ACTIVE$2 = "active";
  var CLASS_NAME_SLIDE = "slide";
  var CLASS_NAME_END = "carousel-item-end";
  var CLASS_NAME_START = "carousel-item-start";
  var CLASS_NAME_NEXT = "carousel-item-next";
  var CLASS_NAME_PREV = "carousel-item-prev";
  var SELECTOR_ACTIVE = ".active";
  var SELECTOR_ITEM = ".carousel-item";
  var SELECTOR_ACTIVE_ITEM = SELECTOR_ACTIVE + SELECTOR_ITEM;
  var SELECTOR_ITEM_IMG = ".carousel-item img";
  var SELECTOR_INDICATORS = ".carousel-indicators";
  var SELECTOR_DATA_SLIDE = "[data-bs-slide], [data-bs-slide-to]";
  var SELECTOR_DATA_RIDE = '[data-bs-ride="carousel"]';
  var KEY_TO_DIRECTION = {
    [ARROW_LEFT_KEY$1]: DIRECTION_RIGHT,
    [ARROW_RIGHT_KEY$1]: DIRECTION_LEFT
  };
  var Default$b = {
    interval: 5e3,
    keyboard: true,
    pause: "hover",
    ride: false,
    touch: true,
    wrap: true
  };
  var DefaultType$b = {
    interval: "(number|boolean)",
    keyboard: "boolean",
    pause: "(string|boolean)",
    ride: "(boolean|string)",
    touch: "boolean",
    wrap: "boolean"
  };
  var Carousel = class extends BaseComponent {
    constructor(element, config) {
      super(element, config);
      this._interval = null;
      this._activeElement = null;
      this._isSliding = false;
      this.touchTimeout = null;
      this._swipeHelper = null;
      this._indicatorsElement = SelectorEngine.findOne(SELECTOR_INDICATORS, this._element);
      this._addEventListeners();
      if (this._config.ride === CLASS_NAME_CAROUSEL) {
        this.cycle();
      }
    }
    static get Default() {
      return Default$b;
    }
    static get DefaultType() {
      return DefaultType$b;
    }
    static get NAME() {
      return NAME$c;
    }
    next() {
      this._slide(ORDER_NEXT);
    }
    nextWhenVisible() {
      if (!document.hidden && isVisible(this._element)) {
        this.next();
      }
    }
    prev() {
      this._slide(ORDER_PREV);
    }
    pause() {
      if (this._isSliding) {
        triggerTransitionEnd(this._element);
      }
      this._clearInterval();
    }
    cycle() {
      this._clearInterval();
      this._updateInterval();
      this._interval = setInterval(() => this.nextWhenVisible(), this._config.interval);
    }
    _maybeEnableCycle() {
      if (!this._config.ride) {
        return;
      }
      if (this._isSliding) {
        EventHandler.one(this._element, EVENT_SLID, () => this.cycle());
        return;
      }
      this.cycle();
    }
    to(index) {
      const items = this._getItems();
      if (index > items.length - 1 || index < 0) {
        return;
      }
      if (this._isSliding) {
        EventHandler.one(this._element, EVENT_SLID, () => this.to(index));
        return;
      }
      const activeIndex = this._getItemIndex(this._getActive());
      if (activeIndex === index) {
        return;
      }
      const order2 = index > activeIndex ? ORDER_NEXT : ORDER_PREV;
      this._slide(order2, items[index]);
    }
    dispose() {
      if (this._swipeHelper) {
        this._swipeHelper.dispose();
      }
      super.dispose();
    }
    _configAfterMerge(config) {
      config.defaultInterval = config.interval;
      return config;
    }
    _addEventListeners() {
      if (this._config.keyboard) {
        EventHandler.on(this._element, EVENT_KEYDOWN$1, (event) => this._keydown(event));
      }
      if (this._config.pause === "hover") {
        EventHandler.on(this._element, EVENT_MOUSEENTER$1, () => this.pause());
        EventHandler.on(this._element, EVENT_MOUSELEAVE$1, () => this._maybeEnableCycle());
      }
      if (this._config.touch && Swipe.isSupported()) {
        this._addTouchEventListeners();
      }
    }
    _addTouchEventListeners() {
      for (const img of SelectorEngine.find(SELECTOR_ITEM_IMG, this._element)) {
        EventHandler.on(img, EVENT_DRAG_START, (event) => event.preventDefault());
      }
      const endCallBack = () => {
        if (this._config.pause !== "hover") {
          return;
        }
        this.pause();
        if (this.touchTimeout) {
          clearTimeout(this.touchTimeout);
        }
        this.touchTimeout = setTimeout(() => this._maybeEnableCycle(), TOUCHEVENT_COMPAT_WAIT + this._config.interval);
      };
      const swipeConfig = {
        leftCallback: () => this._slide(this._directionToOrder(DIRECTION_LEFT)),
        rightCallback: () => this._slide(this._directionToOrder(DIRECTION_RIGHT)),
        endCallback: endCallBack
      };
      this._swipeHelper = new Swipe(this._element, swipeConfig);
    }
    _keydown(event) {
      if (/input|textarea/i.test(event.target.tagName)) {
        return;
      }
      const direction = KEY_TO_DIRECTION[event.key];
      if (direction) {
        event.preventDefault();
        this._slide(this._directionToOrder(direction));
      }
    }
    _getItemIndex(element) {
      return this._getItems().indexOf(element);
    }
    _setActiveIndicatorElement(index) {
      if (!this._indicatorsElement) {
        return;
      }
      const activeIndicator = SelectorEngine.findOne(SELECTOR_ACTIVE, this._indicatorsElement);
      activeIndicator.classList.remove(CLASS_NAME_ACTIVE$2);
      activeIndicator.removeAttribute("aria-current");
      const newActiveIndicator = SelectorEngine.findOne(`[data-bs-slide-to="${index}"]`, this._indicatorsElement);
      if (newActiveIndicator) {
        newActiveIndicator.classList.add(CLASS_NAME_ACTIVE$2);
        newActiveIndicator.setAttribute("aria-current", "true");
      }
    }
    _updateInterval() {
      const element = this._activeElement || this._getActive();
      if (!element) {
        return;
      }
      const elementInterval = Number.parseInt(element.getAttribute("data-bs-interval"), 10);
      this._config.interval = elementInterval || this._config.defaultInterval;
    }
    _slide(order2, element = null) {
      if (this._isSliding) {
        return;
      }
      const activeElement = this._getActive();
      const isNext = order2 === ORDER_NEXT;
      const nextElement = element || getNextActiveElement(this._getItems(), activeElement, isNext, this._config.wrap);
      if (nextElement === activeElement) {
        return;
      }
      const nextElementIndex = this._getItemIndex(nextElement);
      const triggerEvent = (eventName) => {
        return EventHandler.trigger(this._element, eventName, {
          relatedTarget: nextElement,
          direction: this._orderToDirection(order2),
          from: this._getItemIndex(activeElement),
          to: nextElementIndex
        });
      };
      const slideEvent = triggerEvent(EVENT_SLIDE);
      if (slideEvent.defaultPrevented) {
        return;
      }
      if (!activeElement || !nextElement) {
        return;
      }
      const isCycling = Boolean(this._interval);
      this.pause();
      this._isSliding = true;
      this._setActiveIndicatorElement(nextElementIndex);
      this._activeElement = nextElement;
      const directionalClassName = isNext ? CLASS_NAME_START : CLASS_NAME_END;
      const orderClassName = isNext ? CLASS_NAME_NEXT : CLASS_NAME_PREV;
      nextElement.classList.add(orderClassName);
      reflow(nextElement);
      activeElement.classList.add(directionalClassName);
      nextElement.classList.add(directionalClassName);
      const completeCallBack = () => {
        nextElement.classList.remove(directionalClassName, orderClassName);
        nextElement.classList.add(CLASS_NAME_ACTIVE$2);
        activeElement.classList.remove(CLASS_NAME_ACTIVE$2, orderClassName, directionalClassName);
        this._isSliding = false;
        triggerEvent(EVENT_SLID);
      };
      this._queueCallback(completeCallBack, activeElement, this._isAnimated());
      if (isCycling) {
        this.cycle();
      }
    }
    _isAnimated() {
      return this._element.classList.contains(CLASS_NAME_SLIDE);
    }
    _getActive() {
      return SelectorEngine.findOne(SELECTOR_ACTIVE_ITEM, this._element);
    }
    _getItems() {
      return SelectorEngine.find(SELECTOR_ITEM, this._element);
    }
    _clearInterval() {
      if (this._interval) {
        clearInterval(this._interval);
        this._interval = null;
      }
    }
    _directionToOrder(direction) {
      if (isRTL()) {
        return direction === DIRECTION_LEFT ? ORDER_PREV : ORDER_NEXT;
      }
      return direction === DIRECTION_LEFT ? ORDER_NEXT : ORDER_PREV;
    }
    _orderToDirection(order2) {
      if (isRTL()) {
        return order2 === ORDER_PREV ? DIRECTION_LEFT : DIRECTION_RIGHT;
      }
      return order2 === ORDER_PREV ? DIRECTION_RIGHT : DIRECTION_LEFT;
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Carousel.getOrCreateInstance(this, config);
        if (typeof config === "number") {
          data.to(config);
          return;
        }
        if (typeof config === "string") {
          if (data[config] === void 0 || config.startsWith("_") || config === "constructor") {
            throw new TypeError(`No method named "${config}"`);
          }
          data[config]();
        }
      });
    }
  };
  EventHandler.on(document, EVENT_CLICK_DATA_API$5, SELECTOR_DATA_SLIDE, function(event) {
    const target = SelectorEngine.getElementFromSelector(this);
    if (!target || !target.classList.contains(CLASS_NAME_CAROUSEL)) {
      return;
    }
    event.preventDefault();
    const carousel = Carousel.getOrCreateInstance(target);
    const slideIndex = this.getAttribute("data-bs-slide-to");
    if (slideIndex) {
      carousel.to(slideIndex);
      carousel._maybeEnableCycle();
      return;
    }
    if (Manipulator.getDataAttribute(this, "slide") === "next") {
      carousel.next();
      carousel._maybeEnableCycle();
      return;
    }
    carousel.prev();
    carousel._maybeEnableCycle();
  });
  EventHandler.on(window, EVENT_LOAD_DATA_API$3, () => {
    const carousels = SelectorEngine.find(SELECTOR_DATA_RIDE);
    for (const carousel of carousels) {
      Carousel.getOrCreateInstance(carousel);
    }
  });
  defineJQueryPlugin(Carousel);
  var NAME$b = "collapse";
  var DATA_KEY$7 = "bs.collapse";
  var EVENT_KEY$7 = `.${DATA_KEY$7}`;
  var DATA_API_KEY$4 = ".data-api";
  var EVENT_SHOW$6 = `show${EVENT_KEY$7}`;
  var EVENT_SHOWN$6 = `shown${EVENT_KEY$7}`;
  var EVENT_HIDE$6 = `hide${EVENT_KEY$7}`;
  var EVENT_HIDDEN$6 = `hidden${EVENT_KEY$7}`;
  var EVENT_CLICK_DATA_API$4 = `click${EVENT_KEY$7}${DATA_API_KEY$4}`;
  var CLASS_NAME_SHOW$7 = "show";
  var CLASS_NAME_COLLAPSE = "collapse";
  var CLASS_NAME_COLLAPSING = "collapsing";
  var CLASS_NAME_COLLAPSED = "collapsed";
  var CLASS_NAME_DEEPER_CHILDREN = `:scope .${CLASS_NAME_COLLAPSE} .${CLASS_NAME_COLLAPSE}`;
  var CLASS_NAME_HORIZONTAL = "collapse-horizontal";
  var WIDTH = "width";
  var HEIGHT = "height";
  var SELECTOR_ACTIVES = ".collapse.show, .collapse.collapsing";
  var SELECTOR_DATA_TOGGLE$4 = '[data-bs-toggle="collapse"]';
  var Default$a = {
    parent: null,
    toggle: true
  };
  var DefaultType$a = {
    parent: "(null|element)",
    toggle: "boolean"
  };
  var Collapse = class extends BaseComponent {
    constructor(element, config) {
      super(element, config);
      this._isTransitioning = false;
      this._triggerArray = [];
      const toggleList = SelectorEngine.find(SELECTOR_DATA_TOGGLE$4);
      for (const elem of toggleList) {
        const selector = SelectorEngine.getSelectorFromElement(elem);
        const filterElement = SelectorEngine.find(selector).filter((foundElement) => foundElement === this._element);
        if (selector !== null && filterElement.length) {
          this._triggerArray.push(elem);
        }
      }
      this._initializeChildren();
      if (!this._config.parent) {
        this._addAriaAndCollapsedClass(this._triggerArray, this._isShown());
      }
      if (this._config.toggle) {
        this.toggle();
      }
    }
    static get Default() {
      return Default$a;
    }
    static get DefaultType() {
      return DefaultType$a;
    }
    static get NAME() {
      return NAME$b;
    }
    toggle() {
      if (this._isShown()) {
        this.hide();
      } else {
        this.show();
      }
    }
    show() {
      if (this._isTransitioning || this._isShown()) {
        return;
      }
      let activeChildren = [];
      if (this._config.parent) {
        activeChildren = this._getFirstLevelChildren(SELECTOR_ACTIVES).filter((element) => element !== this._element).map((element) => Collapse.getOrCreateInstance(element, {
          toggle: false
        }));
      }
      if (activeChildren.length && activeChildren[0]._isTransitioning) {
        return;
      }
      const startEvent = EventHandler.trigger(this._element, EVENT_SHOW$6);
      if (startEvent.defaultPrevented) {
        return;
      }
      for (const activeInstance of activeChildren) {
        activeInstance.hide();
      }
      const dimension = this._getDimension();
      this._element.classList.remove(CLASS_NAME_COLLAPSE);
      this._element.classList.add(CLASS_NAME_COLLAPSING);
      this._element.style[dimension] = 0;
      this._addAriaAndCollapsedClass(this._triggerArray, true);
      this._isTransitioning = true;
      const complete = () => {
        this._isTransitioning = false;
        this._element.classList.remove(CLASS_NAME_COLLAPSING);
        this._element.classList.add(CLASS_NAME_COLLAPSE, CLASS_NAME_SHOW$7);
        this._element.style[dimension] = "";
        EventHandler.trigger(this._element, EVENT_SHOWN$6);
      };
      const capitalizedDimension = dimension[0].toUpperCase() + dimension.slice(1);
      const scrollSize = `scroll${capitalizedDimension}`;
      this._queueCallback(complete, this._element, true);
      this._element.style[dimension] = `${this._element[scrollSize]}px`;
    }
    hide() {
      if (this._isTransitioning || !this._isShown()) {
        return;
      }
      const startEvent = EventHandler.trigger(this._element, EVENT_HIDE$6);
      if (startEvent.defaultPrevented) {
        return;
      }
      const dimension = this._getDimension();
      this._element.style[dimension] = `${this._element.getBoundingClientRect()[dimension]}px`;
      reflow(this._element);
      this._element.classList.add(CLASS_NAME_COLLAPSING);
      this._element.classList.remove(CLASS_NAME_COLLAPSE, CLASS_NAME_SHOW$7);
      for (const trigger of this._triggerArray) {
        const element = SelectorEngine.getElementFromSelector(trigger);
        if (element && !this._isShown(element)) {
          this._addAriaAndCollapsedClass([trigger], false);
        }
      }
      this._isTransitioning = true;
      const complete = () => {
        this._isTransitioning = false;
        this._element.classList.remove(CLASS_NAME_COLLAPSING);
        this._element.classList.add(CLASS_NAME_COLLAPSE);
        EventHandler.trigger(this._element, EVENT_HIDDEN$6);
      };
      this._element.style[dimension] = "";
      this._queueCallback(complete, this._element, true);
    }
    _isShown(element = this._element) {
      return element.classList.contains(CLASS_NAME_SHOW$7);
    }
    _configAfterMerge(config) {
      config.toggle = Boolean(config.toggle);
      config.parent = getElement(config.parent);
      return config;
    }
    _getDimension() {
      return this._element.classList.contains(CLASS_NAME_HORIZONTAL) ? WIDTH : HEIGHT;
    }
    _initializeChildren() {
      if (!this._config.parent) {
        return;
      }
      const children = this._getFirstLevelChildren(SELECTOR_DATA_TOGGLE$4);
      for (const element of children) {
        const selected = SelectorEngine.getElementFromSelector(element);
        if (selected) {
          this._addAriaAndCollapsedClass([element], this._isShown(selected));
        }
      }
    }
    _getFirstLevelChildren(selector) {
      const children = SelectorEngine.find(CLASS_NAME_DEEPER_CHILDREN, this._config.parent);
      return SelectorEngine.find(selector, this._config.parent).filter((element) => !children.includes(element));
    }
    _addAriaAndCollapsedClass(triggerArray, isOpen) {
      if (!triggerArray.length) {
        return;
      }
      for (const element of triggerArray) {
        element.classList.toggle(CLASS_NAME_COLLAPSED, !isOpen);
        element.setAttribute("aria-expanded", isOpen);
      }
    }
    static jQueryInterface(config) {
      const _config = {};
      if (typeof config === "string" && /show|hide/.test(config)) {
        _config.toggle = false;
      }
      return this.each(function() {
        const data = Collapse.getOrCreateInstance(this, _config);
        if (typeof config === "string") {
          if (typeof data[config] === "undefined") {
            throw new TypeError(`No method named "${config}"`);
          }
          data[config]();
        }
      });
    }
  };
  EventHandler.on(document, EVENT_CLICK_DATA_API$4, SELECTOR_DATA_TOGGLE$4, function(event) {
    if (event.target.tagName === "A" || event.delegateTarget && event.delegateTarget.tagName === "A") {
      event.preventDefault();
    }
    for (const element of SelectorEngine.getMultipleElementsFromSelector(this)) {
      Collapse.getOrCreateInstance(element, {
        toggle: false
      }).toggle();
    }
  });
  defineJQueryPlugin(Collapse);
  var NAME$a = "dropdown";
  var DATA_KEY$6 = "bs.dropdown";
  var EVENT_KEY$6 = `.${DATA_KEY$6}`;
  var DATA_API_KEY$3 = ".data-api";
  var ESCAPE_KEY$2 = "Escape";
  var TAB_KEY$1 = "Tab";
  var ARROW_UP_KEY$1 = "ArrowUp";
  var ARROW_DOWN_KEY$1 = "ArrowDown";
  var RIGHT_MOUSE_BUTTON = 2;
  var EVENT_HIDE$5 = `hide${EVENT_KEY$6}`;
  var EVENT_HIDDEN$5 = `hidden${EVENT_KEY$6}`;
  var EVENT_SHOW$5 = `show${EVENT_KEY$6}`;
  var EVENT_SHOWN$5 = `shown${EVENT_KEY$6}`;
  var EVENT_CLICK_DATA_API$3 = `click${EVENT_KEY$6}${DATA_API_KEY$3}`;
  var EVENT_KEYDOWN_DATA_API = `keydown${EVENT_KEY$6}${DATA_API_KEY$3}`;
  var EVENT_KEYUP_DATA_API = `keyup${EVENT_KEY$6}${DATA_API_KEY$3}`;
  var CLASS_NAME_SHOW$6 = "show";
  var CLASS_NAME_DROPUP = "dropup";
  var CLASS_NAME_DROPEND = "dropend";
  var CLASS_NAME_DROPSTART = "dropstart";
  var CLASS_NAME_DROPUP_CENTER = "dropup-center";
  var CLASS_NAME_DROPDOWN_CENTER = "dropdown-center";
  var SELECTOR_DATA_TOGGLE$3 = '[data-bs-toggle="dropdown"]:not(.disabled):not(:disabled)';
  var SELECTOR_DATA_TOGGLE_SHOWN = `${SELECTOR_DATA_TOGGLE$3}.${CLASS_NAME_SHOW$6}`;
  var SELECTOR_MENU = ".dropdown-menu";
  var SELECTOR_NAVBAR = ".navbar";
  var SELECTOR_NAVBAR_NAV = ".navbar-nav";
  var SELECTOR_VISIBLE_ITEMS = ".dropdown-menu .dropdown-item:not(.disabled):not(:disabled)";
  var PLACEMENT_TOP = isRTL() ? "top-end" : "top-start";
  var PLACEMENT_TOPEND = isRTL() ? "top-start" : "top-end";
  var PLACEMENT_BOTTOM = isRTL() ? "bottom-end" : "bottom-start";
  var PLACEMENT_BOTTOMEND = isRTL() ? "bottom-start" : "bottom-end";
  var PLACEMENT_RIGHT = isRTL() ? "left-start" : "right-start";
  var PLACEMENT_LEFT = isRTL() ? "right-start" : "left-start";
  var PLACEMENT_TOPCENTER = "top";
  var PLACEMENT_BOTTOMCENTER = "bottom";
  var Default$9 = {
    autoClose: true,
    boundary: "clippingParents",
    display: "dynamic",
    offset: [0, 2],
    popperConfig: null,
    reference: "toggle"
  };
  var DefaultType$9 = {
    autoClose: "(boolean|string)",
    boundary: "(string|element)",
    display: "string",
    offset: "(array|string|function)",
    popperConfig: "(null|object|function)",
    reference: "(string|element|object)"
  };
  var Dropdown = class extends BaseComponent {
    constructor(element, config) {
      super(element, config);
      this._popper = null;
      this._parent = this._element.parentNode;
      this._menu = SelectorEngine.next(this._element, SELECTOR_MENU)[0] || SelectorEngine.prev(this._element, SELECTOR_MENU)[0] || SelectorEngine.findOne(SELECTOR_MENU, this._parent);
      this._inNavbar = this._detectNavbar();
    }
    static get Default() {
      return Default$9;
    }
    static get DefaultType() {
      return DefaultType$9;
    }
    static get NAME() {
      return NAME$a;
    }
    toggle() {
      return this._isShown() ? this.hide() : this.show();
    }
    show() {
      if (isDisabled(this._element) || this._isShown()) {
        return;
      }
      const relatedTarget = {
        relatedTarget: this._element
      };
      const showEvent = EventHandler.trigger(this._element, EVENT_SHOW$5, relatedTarget);
      if (showEvent.defaultPrevented) {
        return;
      }
      this._createPopper();
      if ("ontouchstart" in document.documentElement && !this._parent.closest(SELECTOR_NAVBAR_NAV)) {
        for (const element of [].concat(...document.body.children)) {
          EventHandler.on(element, "mouseover", noop);
        }
      }
      this._element.focus();
      this._element.setAttribute("aria-expanded", true);
      this._menu.classList.add(CLASS_NAME_SHOW$6);
      this._element.classList.add(CLASS_NAME_SHOW$6);
      EventHandler.trigger(this._element, EVENT_SHOWN$5, relatedTarget);
    }
    hide() {
      if (isDisabled(this._element) || !this._isShown()) {
        return;
      }
      const relatedTarget = {
        relatedTarget: this._element
      };
      this._completeHide(relatedTarget);
    }
    dispose() {
      if (this._popper) {
        this._popper.destroy();
      }
      super.dispose();
    }
    update() {
      this._inNavbar = this._detectNavbar();
      if (this._popper) {
        this._popper.update();
      }
    }
    _completeHide(relatedTarget) {
      const hideEvent = EventHandler.trigger(this._element, EVENT_HIDE$5, relatedTarget);
      if (hideEvent.defaultPrevented) {
        return;
      }
      if ("ontouchstart" in document.documentElement) {
        for (const element of [].concat(...document.body.children)) {
          EventHandler.off(element, "mouseover", noop);
        }
      }
      if (this._popper) {
        this._popper.destroy();
      }
      this._menu.classList.remove(CLASS_NAME_SHOW$6);
      this._element.classList.remove(CLASS_NAME_SHOW$6);
      this._element.setAttribute("aria-expanded", "false");
      Manipulator.removeDataAttribute(this._menu, "popper");
      EventHandler.trigger(this._element, EVENT_HIDDEN$5, relatedTarget);
    }
    _getConfig(config) {
      config = super._getConfig(config);
      if (typeof config.reference === "object" && !isElement2(config.reference) && typeof config.reference.getBoundingClientRect !== "function") {
        throw new TypeError(`${NAME$a.toUpperCase()}: Option "reference" provided type "object" without a required "getBoundingClientRect" method.`);
      }
      return config;
    }
    _createPopper() {
      if (typeof lib_exports === "undefined") {
        throw new TypeError("Bootstrap's dropdowns require Popper (https://popper.js.org)");
      }
      let referenceElement = this._element;
      if (this._config.reference === "parent") {
        referenceElement = this._parent;
      } else if (isElement2(this._config.reference)) {
        referenceElement = getElement(this._config.reference);
      } else if (typeof this._config.reference === "object") {
        referenceElement = this._config.reference;
      }
      const popperConfig = this._getPopperConfig();
      this._popper = createPopper3(referenceElement, this._menu, popperConfig);
    }
    _isShown() {
      return this._menu.classList.contains(CLASS_NAME_SHOW$6);
    }
    _getPlacement() {
      const parentDropdown = this._parent;
      if (parentDropdown.classList.contains(CLASS_NAME_DROPEND)) {
        return PLACEMENT_RIGHT;
      }
      if (parentDropdown.classList.contains(CLASS_NAME_DROPSTART)) {
        return PLACEMENT_LEFT;
      }
      if (parentDropdown.classList.contains(CLASS_NAME_DROPUP_CENTER)) {
        return PLACEMENT_TOPCENTER;
      }
      if (parentDropdown.classList.contains(CLASS_NAME_DROPDOWN_CENTER)) {
        return PLACEMENT_BOTTOMCENTER;
      }
      const isEnd = getComputedStyle(this._menu).getPropertyValue("--bs-position").trim() === "end";
      if (parentDropdown.classList.contains(CLASS_NAME_DROPUP)) {
        return isEnd ? PLACEMENT_TOPEND : PLACEMENT_TOP;
      }
      return isEnd ? PLACEMENT_BOTTOMEND : PLACEMENT_BOTTOM;
    }
    _detectNavbar() {
      return this._element.closest(SELECTOR_NAVBAR) !== null;
    }
    _getOffset() {
      const {
        offset: offset2
      } = this._config;
      if (typeof offset2 === "string") {
        return offset2.split(",").map((value) => Number.parseInt(value, 10));
      }
      if (typeof offset2 === "function") {
        return (popperData) => offset2(popperData, this._element);
      }
      return offset2;
    }
    _getPopperConfig() {
      const defaultBsPopperConfig = {
        placement: this._getPlacement(),
        modifiers: [{
          name: "preventOverflow",
          options: {
            boundary: this._config.boundary
          }
        }, {
          name: "offset",
          options: {
            offset: this._getOffset()
          }
        }]
      };
      if (this._inNavbar || this._config.display === "static") {
        Manipulator.setDataAttribute(this._menu, "popper", "static");
        defaultBsPopperConfig.modifiers = [{
          name: "applyStyles",
          enabled: false
        }];
      }
      return {
        ...defaultBsPopperConfig,
        ...execute(this._config.popperConfig, [defaultBsPopperConfig])
      };
    }
    _selectMenuItem({
      key,
      target
    }) {
      const items = SelectorEngine.find(SELECTOR_VISIBLE_ITEMS, this._menu).filter((element) => isVisible(element));
      if (!items.length) {
        return;
      }
      getNextActiveElement(items, target, key === ARROW_DOWN_KEY$1, !items.includes(target)).focus();
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Dropdown.getOrCreateInstance(this, config);
        if (typeof config !== "string") {
          return;
        }
        if (typeof data[config] === "undefined") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config]();
      });
    }
    static clearMenus(event) {
      if (event.button === RIGHT_MOUSE_BUTTON || event.type === "keyup" && event.key !== TAB_KEY$1) {
        return;
      }
      const openToggles = SelectorEngine.find(SELECTOR_DATA_TOGGLE_SHOWN);
      for (const toggle of openToggles) {
        const context = Dropdown.getInstance(toggle);
        if (!context || context._config.autoClose === false) {
          continue;
        }
        const composedPath = event.composedPath();
        const isMenuTarget = composedPath.includes(context._menu);
        if (composedPath.includes(context._element) || context._config.autoClose === "inside" && !isMenuTarget || context._config.autoClose === "outside" && isMenuTarget) {
          continue;
        }
        if (context._menu.contains(event.target) && (event.type === "keyup" && event.key === TAB_KEY$1 || /input|select|option|textarea|form/i.test(event.target.tagName))) {
          continue;
        }
        const relatedTarget = {
          relatedTarget: context._element
        };
        if (event.type === "click") {
          relatedTarget.clickEvent = event;
        }
        context._completeHide(relatedTarget);
      }
    }
    static dataApiKeydownHandler(event) {
      const isInput = /input|textarea/i.test(event.target.tagName);
      const isEscapeEvent = event.key === ESCAPE_KEY$2;
      const isUpOrDownEvent = [ARROW_UP_KEY$1, ARROW_DOWN_KEY$1].includes(event.key);
      if (!isUpOrDownEvent && !isEscapeEvent) {
        return;
      }
      if (isInput && !isEscapeEvent) {
        return;
      }
      event.preventDefault();
      const getToggleButton = this.matches(SELECTOR_DATA_TOGGLE$3) ? this : SelectorEngine.prev(this, SELECTOR_DATA_TOGGLE$3)[0] || SelectorEngine.next(this, SELECTOR_DATA_TOGGLE$3)[0] || SelectorEngine.findOne(SELECTOR_DATA_TOGGLE$3, event.delegateTarget.parentNode);
      const instance = Dropdown.getOrCreateInstance(getToggleButton);
      if (isUpOrDownEvent) {
        event.stopPropagation();
        instance.show();
        instance._selectMenuItem(event);
        return;
      }
      if (instance._isShown()) {
        event.stopPropagation();
        instance.hide();
        getToggleButton.focus();
      }
    }
  };
  EventHandler.on(document, EVENT_KEYDOWN_DATA_API, SELECTOR_DATA_TOGGLE$3, Dropdown.dataApiKeydownHandler);
  EventHandler.on(document, EVENT_KEYDOWN_DATA_API, SELECTOR_MENU, Dropdown.dataApiKeydownHandler);
  EventHandler.on(document, EVENT_CLICK_DATA_API$3, Dropdown.clearMenus);
  EventHandler.on(document, EVENT_KEYUP_DATA_API, Dropdown.clearMenus);
  EventHandler.on(document, EVENT_CLICK_DATA_API$3, SELECTOR_DATA_TOGGLE$3, function(event) {
    event.preventDefault();
    Dropdown.getOrCreateInstance(this).toggle();
  });
  defineJQueryPlugin(Dropdown);
  var NAME$9 = "backdrop";
  var CLASS_NAME_FADE$4 = "fade";
  var CLASS_NAME_SHOW$5 = "show";
  var EVENT_MOUSEDOWN = `mousedown.bs.${NAME$9}`;
  var Default$8 = {
    className: "modal-backdrop",
    clickCallback: null,
    isAnimated: false,
    isVisible: true,
    rootElement: "body"
  };
  var DefaultType$8 = {
    className: "string",
    clickCallback: "(function|null)",
    isAnimated: "boolean",
    isVisible: "boolean",
    rootElement: "(element|string)"
  };
  var Backdrop = class extends Config {
    constructor(config) {
      super();
      this._config = this._getConfig(config);
      this._isAppended = false;
      this._element = null;
    }
    static get Default() {
      return Default$8;
    }
    static get DefaultType() {
      return DefaultType$8;
    }
    static get NAME() {
      return NAME$9;
    }
    show(callback) {
      if (!this._config.isVisible) {
        execute(callback);
        return;
      }
      this._append();
      const element = this._getElement();
      if (this._config.isAnimated) {
        reflow(element);
      }
      element.classList.add(CLASS_NAME_SHOW$5);
      this._emulateAnimation(() => {
        execute(callback);
      });
    }
    hide(callback) {
      if (!this._config.isVisible) {
        execute(callback);
        return;
      }
      this._getElement().classList.remove(CLASS_NAME_SHOW$5);
      this._emulateAnimation(() => {
        this.dispose();
        execute(callback);
      });
    }
    dispose() {
      if (!this._isAppended) {
        return;
      }
      EventHandler.off(this._element, EVENT_MOUSEDOWN);
      this._element.remove();
      this._isAppended = false;
    }
    _getElement() {
      if (!this._element) {
        const backdrop = document.createElement("div");
        backdrop.className = this._config.className;
        if (this._config.isAnimated) {
          backdrop.classList.add(CLASS_NAME_FADE$4);
        }
        this._element = backdrop;
      }
      return this._element;
    }
    _configAfterMerge(config) {
      config.rootElement = getElement(config.rootElement);
      return config;
    }
    _append() {
      if (this._isAppended) {
        return;
      }
      const element = this._getElement();
      this._config.rootElement.append(element);
      EventHandler.on(element, EVENT_MOUSEDOWN, () => {
        execute(this._config.clickCallback);
      });
      this._isAppended = true;
    }
    _emulateAnimation(callback) {
      executeAfterTransition(callback, this._getElement(), this._config.isAnimated);
    }
  };
  var NAME$8 = "focustrap";
  var DATA_KEY$5 = "bs.focustrap";
  var EVENT_KEY$5 = `.${DATA_KEY$5}`;
  var EVENT_FOCUSIN$2 = `focusin${EVENT_KEY$5}`;
  var EVENT_KEYDOWN_TAB = `keydown.tab${EVENT_KEY$5}`;
  var TAB_KEY = "Tab";
  var TAB_NAV_FORWARD = "forward";
  var TAB_NAV_BACKWARD = "backward";
  var Default$7 = {
    autofocus: true,
    trapElement: null
  };
  var DefaultType$7 = {
    autofocus: "boolean",
    trapElement: "element"
  };
  var FocusTrap = class extends Config {
    constructor(config) {
      super();
      this._config = this._getConfig(config);
      this._isActive = false;
      this._lastTabNavDirection = null;
    }
    static get Default() {
      return Default$7;
    }
    static get DefaultType() {
      return DefaultType$7;
    }
    static get NAME() {
      return NAME$8;
    }
    activate() {
      if (this._isActive) {
        return;
      }
      if (this._config.autofocus) {
        this._config.trapElement.focus();
      }
      EventHandler.off(document, EVENT_KEY$5);
      EventHandler.on(document, EVENT_FOCUSIN$2, (event) => this._handleFocusin(event));
      EventHandler.on(document, EVENT_KEYDOWN_TAB, (event) => this._handleKeydown(event));
      this._isActive = true;
    }
    deactivate() {
      if (!this._isActive) {
        return;
      }
      this._isActive = false;
      EventHandler.off(document, EVENT_KEY$5);
    }
    _handleFocusin(event) {
      const {
        trapElement
      } = this._config;
      if (event.target === document || event.target === trapElement || trapElement.contains(event.target)) {
        return;
      }
      const elements = SelectorEngine.focusableChildren(trapElement);
      if (elements.length === 0) {
        trapElement.focus();
      } else if (this._lastTabNavDirection === TAB_NAV_BACKWARD) {
        elements[elements.length - 1].focus();
      } else {
        elements[0].focus();
      }
    }
    _handleKeydown(event) {
      if (event.key !== TAB_KEY) {
        return;
      }
      this._lastTabNavDirection = event.shiftKey ? TAB_NAV_BACKWARD : TAB_NAV_FORWARD;
    }
  };
  var SELECTOR_FIXED_CONTENT = ".fixed-top, .fixed-bottom, .is-fixed, .sticky-top";
  var SELECTOR_STICKY_CONTENT = ".sticky-top";
  var PROPERTY_PADDING = "padding-right";
  var PROPERTY_MARGIN = "margin-right";
  var ScrollBarHelper = class {
    constructor() {
      this._element = document.body;
    }
    getWidth() {
      const documentWidth = document.documentElement.clientWidth;
      return Math.abs(window.innerWidth - documentWidth);
    }
    hide() {
      const width = this.getWidth();
      this._disableOverFlow();
      this._setElementAttributes(this._element, PROPERTY_PADDING, (calculatedValue) => calculatedValue + width);
      this._setElementAttributes(SELECTOR_FIXED_CONTENT, PROPERTY_PADDING, (calculatedValue) => calculatedValue + width);
      this._setElementAttributes(SELECTOR_STICKY_CONTENT, PROPERTY_MARGIN, (calculatedValue) => calculatedValue - width);
    }
    reset() {
      this._resetElementAttributes(this._element, "overflow");
      this._resetElementAttributes(this._element, PROPERTY_PADDING);
      this._resetElementAttributes(SELECTOR_FIXED_CONTENT, PROPERTY_PADDING);
      this._resetElementAttributes(SELECTOR_STICKY_CONTENT, PROPERTY_MARGIN);
    }
    isOverflowing() {
      return this.getWidth() > 0;
    }
    _disableOverFlow() {
      this._saveInitialAttribute(this._element, "overflow");
      this._element.style.overflow = "hidden";
    }
    _setElementAttributes(selector, styleProperty, callback) {
      const scrollbarWidth = this.getWidth();
      const manipulationCallBack = (element) => {
        if (element !== this._element && window.innerWidth > element.clientWidth + scrollbarWidth) {
          return;
        }
        this._saveInitialAttribute(element, styleProperty);
        const calculatedValue = window.getComputedStyle(element).getPropertyValue(styleProperty);
        element.style.setProperty(styleProperty, `${callback(Number.parseFloat(calculatedValue))}px`);
      };
      this._applyManipulationCallback(selector, manipulationCallBack);
    }
    _saveInitialAttribute(element, styleProperty) {
      const actualValue = element.style.getPropertyValue(styleProperty);
      if (actualValue) {
        Manipulator.setDataAttribute(element, styleProperty, actualValue);
      }
    }
    _resetElementAttributes(selector, styleProperty) {
      const manipulationCallBack = (element) => {
        const value = Manipulator.getDataAttribute(element, styleProperty);
        if (value === null) {
          element.style.removeProperty(styleProperty);
          return;
        }
        Manipulator.removeDataAttribute(element, styleProperty);
        element.style.setProperty(styleProperty, value);
      };
      this._applyManipulationCallback(selector, manipulationCallBack);
    }
    _applyManipulationCallback(selector, callBack) {
      if (isElement2(selector)) {
        callBack(selector);
        return;
      }
      for (const sel of SelectorEngine.find(selector, this._element)) {
        callBack(sel);
      }
    }
  };
  var NAME$7 = "modal";
  var DATA_KEY$4 = "bs.modal";
  var EVENT_KEY$4 = `.${DATA_KEY$4}`;
  var DATA_API_KEY$2 = ".data-api";
  var ESCAPE_KEY$1 = "Escape";
  var EVENT_HIDE$4 = `hide${EVENT_KEY$4}`;
  var EVENT_HIDE_PREVENTED$1 = `hidePrevented${EVENT_KEY$4}`;
  var EVENT_HIDDEN$4 = `hidden${EVENT_KEY$4}`;
  var EVENT_SHOW$4 = `show${EVENT_KEY$4}`;
  var EVENT_SHOWN$4 = `shown${EVENT_KEY$4}`;
  var EVENT_RESIZE$1 = `resize${EVENT_KEY$4}`;
  var EVENT_CLICK_DISMISS = `click.dismiss${EVENT_KEY$4}`;
  var EVENT_MOUSEDOWN_DISMISS = `mousedown.dismiss${EVENT_KEY$4}`;
  var EVENT_KEYDOWN_DISMISS$1 = `keydown.dismiss${EVENT_KEY$4}`;
  var EVENT_CLICK_DATA_API$2 = `click${EVENT_KEY$4}${DATA_API_KEY$2}`;
  var CLASS_NAME_OPEN = "modal-open";
  var CLASS_NAME_FADE$3 = "fade";
  var CLASS_NAME_SHOW$4 = "show";
  var CLASS_NAME_STATIC = "modal-static";
  var OPEN_SELECTOR$1 = ".modal.show";
  var SELECTOR_DIALOG = ".modal-dialog";
  var SELECTOR_MODAL_BODY = ".modal-body";
  var SELECTOR_DATA_TOGGLE$2 = '[data-bs-toggle="modal"]';
  var Default$6 = {
    backdrop: true,
    focus: true,
    keyboard: true
  };
  var DefaultType$6 = {
    backdrop: "(boolean|string)",
    focus: "boolean",
    keyboard: "boolean"
  };
  var Modal = class extends BaseComponent {
    constructor(element, config) {
      super(element, config);
      this._dialog = SelectorEngine.findOne(SELECTOR_DIALOG, this._element);
      this._backdrop = this._initializeBackDrop();
      this._focustrap = this._initializeFocusTrap();
      this._isShown = false;
      this._isTransitioning = false;
      this._scrollBar = new ScrollBarHelper();
      this._addEventListeners();
    }
    static get Default() {
      return Default$6;
    }
    static get DefaultType() {
      return DefaultType$6;
    }
    static get NAME() {
      return NAME$7;
    }
    toggle(relatedTarget) {
      return this._isShown ? this.hide() : this.show(relatedTarget);
    }
    show(relatedTarget) {
      if (this._isShown || this._isTransitioning) {
        return;
      }
      const showEvent = EventHandler.trigger(this._element, EVENT_SHOW$4, {
        relatedTarget
      });
      if (showEvent.defaultPrevented) {
        return;
      }
      this._isShown = true;
      this._isTransitioning = true;
      this._scrollBar.hide();
      document.body.classList.add(CLASS_NAME_OPEN);
      this._adjustDialog();
      this._backdrop.show(() => this._showElement(relatedTarget));
    }
    hide() {
      if (!this._isShown || this._isTransitioning) {
        return;
      }
      const hideEvent = EventHandler.trigger(this._element, EVENT_HIDE$4);
      if (hideEvent.defaultPrevented) {
        return;
      }
      this._isShown = false;
      this._isTransitioning = true;
      this._focustrap.deactivate();
      this._element.classList.remove(CLASS_NAME_SHOW$4);
      this._queueCallback(() => this._hideModal(), this._element, this._isAnimated());
    }
    dispose() {
      EventHandler.off(window, EVENT_KEY$4);
      EventHandler.off(this._dialog, EVENT_KEY$4);
      this._backdrop.dispose();
      this._focustrap.deactivate();
      super.dispose();
    }
    handleUpdate() {
      this._adjustDialog();
    }
    _initializeBackDrop() {
      return new Backdrop({
        isVisible: Boolean(this._config.backdrop),
        isAnimated: this._isAnimated()
      });
    }
    _initializeFocusTrap() {
      return new FocusTrap({
        trapElement: this._element
      });
    }
    _showElement(relatedTarget) {
      if (!document.body.contains(this._element)) {
        document.body.append(this._element);
      }
      this._element.style.display = "block";
      this._element.removeAttribute("aria-hidden");
      this._element.setAttribute("aria-modal", true);
      this._element.setAttribute("role", "dialog");
      this._element.scrollTop = 0;
      const modalBody = SelectorEngine.findOne(SELECTOR_MODAL_BODY, this._dialog);
      if (modalBody) {
        modalBody.scrollTop = 0;
      }
      reflow(this._element);
      this._element.classList.add(CLASS_NAME_SHOW$4);
      const transitionComplete = () => {
        if (this._config.focus) {
          this._focustrap.activate();
        }
        this._isTransitioning = false;
        EventHandler.trigger(this._element, EVENT_SHOWN$4, {
          relatedTarget
        });
      };
      this._queueCallback(transitionComplete, this._dialog, this._isAnimated());
    }
    _addEventListeners() {
      EventHandler.on(this._element, EVENT_KEYDOWN_DISMISS$1, (event) => {
        if (event.key !== ESCAPE_KEY$1) {
          return;
        }
        if (this._config.keyboard) {
          this.hide();
          return;
        }
        this._triggerBackdropTransition();
      });
      EventHandler.on(window, EVENT_RESIZE$1, () => {
        if (this._isShown && !this._isTransitioning) {
          this._adjustDialog();
        }
      });
      EventHandler.on(this._element, EVENT_MOUSEDOWN_DISMISS, (event) => {
        EventHandler.one(this._element, EVENT_CLICK_DISMISS, (event2) => {
          if (this._element !== event.target || this._element !== event2.target) {
            return;
          }
          if (this._config.backdrop === "static") {
            this._triggerBackdropTransition();
            return;
          }
          if (this._config.backdrop) {
            this.hide();
          }
        });
      });
    }
    _hideModal() {
      this._element.style.display = "none";
      this._element.setAttribute("aria-hidden", true);
      this._element.removeAttribute("aria-modal");
      this._element.removeAttribute("role");
      this._isTransitioning = false;
      this._backdrop.hide(() => {
        document.body.classList.remove(CLASS_NAME_OPEN);
        this._resetAdjustments();
        this._scrollBar.reset();
        EventHandler.trigger(this._element, EVENT_HIDDEN$4);
      });
    }
    _isAnimated() {
      return this._element.classList.contains(CLASS_NAME_FADE$3);
    }
    _triggerBackdropTransition() {
      const hideEvent = EventHandler.trigger(this._element, EVENT_HIDE_PREVENTED$1);
      if (hideEvent.defaultPrevented) {
        return;
      }
      const isModalOverflowing = this._element.scrollHeight > document.documentElement.clientHeight;
      const initialOverflowY = this._element.style.overflowY;
      if (initialOverflowY === "hidden" || this._element.classList.contains(CLASS_NAME_STATIC)) {
        return;
      }
      if (!isModalOverflowing) {
        this._element.style.overflowY = "hidden";
      }
      this._element.classList.add(CLASS_NAME_STATIC);
      this._queueCallback(() => {
        this._element.classList.remove(CLASS_NAME_STATIC);
        this._queueCallback(() => {
          this._element.style.overflowY = initialOverflowY;
        }, this._dialog);
      }, this._dialog);
      this._element.focus();
    }
    _adjustDialog() {
      const isModalOverflowing = this._element.scrollHeight > document.documentElement.clientHeight;
      const scrollbarWidth = this._scrollBar.getWidth();
      const isBodyOverflowing = scrollbarWidth > 0;
      if (isBodyOverflowing && !isModalOverflowing) {
        const property = isRTL() ? "paddingLeft" : "paddingRight";
        this._element.style[property] = `${scrollbarWidth}px`;
      }
      if (!isBodyOverflowing && isModalOverflowing) {
        const property = isRTL() ? "paddingRight" : "paddingLeft";
        this._element.style[property] = `${scrollbarWidth}px`;
      }
    }
    _resetAdjustments() {
      this._element.style.paddingLeft = "";
      this._element.style.paddingRight = "";
    }
    static jQueryInterface(config, relatedTarget) {
      return this.each(function() {
        const data = Modal.getOrCreateInstance(this, config);
        if (typeof config !== "string") {
          return;
        }
        if (typeof data[config] === "undefined") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config](relatedTarget);
      });
    }
  };
  EventHandler.on(document, EVENT_CLICK_DATA_API$2, SELECTOR_DATA_TOGGLE$2, function(event) {
    const target = SelectorEngine.getElementFromSelector(this);
    if (["A", "AREA"].includes(this.tagName)) {
      event.preventDefault();
    }
    EventHandler.one(target, EVENT_SHOW$4, (showEvent) => {
      if (showEvent.defaultPrevented) {
        return;
      }
      EventHandler.one(target, EVENT_HIDDEN$4, () => {
        if (isVisible(this)) {
          this.focus();
        }
      });
    });
    const alreadyOpen = SelectorEngine.findOne(OPEN_SELECTOR$1);
    if (alreadyOpen) {
      Modal.getInstance(alreadyOpen).hide();
    }
    const data = Modal.getOrCreateInstance(target);
    data.toggle(this);
  });
  enableDismissTrigger(Modal);
  defineJQueryPlugin(Modal);
  var NAME$6 = "offcanvas";
  var DATA_KEY$3 = "bs.offcanvas";
  var EVENT_KEY$3 = `.${DATA_KEY$3}`;
  var DATA_API_KEY$1 = ".data-api";
  var EVENT_LOAD_DATA_API$2 = `load${EVENT_KEY$3}${DATA_API_KEY$1}`;
  var ESCAPE_KEY = "Escape";
  var CLASS_NAME_SHOW$3 = "show";
  var CLASS_NAME_SHOWING$1 = "showing";
  var CLASS_NAME_HIDING = "hiding";
  var CLASS_NAME_BACKDROP = "offcanvas-backdrop";
  var OPEN_SELECTOR = ".offcanvas.show";
  var EVENT_SHOW$3 = `show${EVENT_KEY$3}`;
  var EVENT_SHOWN$3 = `shown${EVENT_KEY$3}`;
  var EVENT_HIDE$3 = `hide${EVENT_KEY$3}`;
  var EVENT_HIDE_PREVENTED = `hidePrevented${EVENT_KEY$3}`;
  var EVENT_HIDDEN$3 = `hidden${EVENT_KEY$3}`;
  var EVENT_RESIZE = `resize${EVENT_KEY$3}`;
  var EVENT_CLICK_DATA_API$1 = `click${EVENT_KEY$3}${DATA_API_KEY$1}`;
  var EVENT_KEYDOWN_DISMISS = `keydown.dismiss${EVENT_KEY$3}`;
  var SELECTOR_DATA_TOGGLE$1 = '[data-bs-toggle="offcanvas"]';
  var Default$5 = {
    backdrop: true,
    keyboard: true,
    scroll: false
  };
  var DefaultType$5 = {
    backdrop: "(boolean|string)",
    keyboard: "boolean",
    scroll: "boolean"
  };
  var Offcanvas = class extends BaseComponent {
    constructor(element, config) {
      super(element, config);
      this._isShown = false;
      this._backdrop = this._initializeBackDrop();
      this._focustrap = this._initializeFocusTrap();
      this._addEventListeners();
    }
    static get Default() {
      return Default$5;
    }
    static get DefaultType() {
      return DefaultType$5;
    }
    static get NAME() {
      return NAME$6;
    }
    toggle(relatedTarget) {
      return this._isShown ? this.hide() : this.show(relatedTarget);
    }
    show(relatedTarget) {
      if (this._isShown) {
        return;
      }
      const showEvent = EventHandler.trigger(this._element, EVENT_SHOW$3, {
        relatedTarget
      });
      if (showEvent.defaultPrevented) {
        return;
      }
      this._isShown = true;
      this._backdrop.show();
      if (!this._config.scroll) {
        new ScrollBarHelper().hide();
      }
      this._element.setAttribute("aria-modal", true);
      this._element.setAttribute("role", "dialog");
      this._element.classList.add(CLASS_NAME_SHOWING$1);
      const completeCallBack = () => {
        if (!this._config.scroll || this._config.backdrop) {
          this._focustrap.activate();
        }
        this._element.classList.add(CLASS_NAME_SHOW$3);
        this._element.classList.remove(CLASS_NAME_SHOWING$1);
        EventHandler.trigger(this._element, EVENT_SHOWN$3, {
          relatedTarget
        });
      };
      this._queueCallback(completeCallBack, this._element, true);
    }
    hide() {
      if (!this._isShown) {
        return;
      }
      const hideEvent = EventHandler.trigger(this._element, EVENT_HIDE$3);
      if (hideEvent.defaultPrevented) {
        return;
      }
      this._focustrap.deactivate();
      this._element.blur();
      this._isShown = false;
      this._element.classList.add(CLASS_NAME_HIDING);
      this._backdrop.hide();
      const completeCallback = () => {
        this._element.classList.remove(CLASS_NAME_SHOW$3, CLASS_NAME_HIDING);
        this._element.removeAttribute("aria-modal");
        this._element.removeAttribute("role");
        if (!this._config.scroll) {
          new ScrollBarHelper().reset();
        }
        EventHandler.trigger(this._element, EVENT_HIDDEN$3);
      };
      this._queueCallback(completeCallback, this._element, true);
    }
    dispose() {
      this._backdrop.dispose();
      this._focustrap.deactivate();
      super.dispose();
    }
    _initializeBackDrop() {
      const clickCallback = () => {
        if (this._config.backdrop === "static") {
          EventHandler.trigger(this._element, EVENT_HIDE_PREVENTED);
          return;
        }
        this.hide();
      };
      const isVisible2 = Boolean(this._config.backdrop);
      return new Backdrop({
        className: CLASS_NAME_BACKDROP,
        isVisible: isVisible2,
        isAnimated: true,
        rootElement: this._element.parentNode,
        clickCallback: isVisible2 ? clickCallback : null
      });
    }
    _initializeFocusTrap() {
      return new FocusTrap({
        trapElement: this._element
      });
    }
    _addEventListeners() {
      EventHandler.on(this._element, EVENT_KEYDOWN_DISMISS, (event) => {
        if (event.key !== ESCAPE_KEY) {
          return;
        }
        if (this._config.keyboard) {
          this.hide();
          return;
        }
        EventHandler.trigger(this._element, EVENT_HIDE_PREVENTED);
      });
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Offcanvas.getOrCreateInstance(this, config);
        if (typeof config !== "string") {
          return;
        }
        if (data[config] === void 0 || config.startsWith("_") || config === "constructor") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config](this);
      });
    }
  };
  EventHandler.on(document, EVENT_CLICK_DATA_API$1, SELECTOR_DATA_TOGGLE$1, function(event) {
    const target = SelectorEngine.getElementFromSelector(this);
    if (["A", "AREA"].includes(this.tagName)) {
      event.preventDefault();
    }
    if (isDisabled(this)) {
      return;
    }
    EventHandler.one(target, EVENT_HIDDEN$3, () => {
      if (isVisible(this)) {
        this.focus();
      }
    });
    const alreadyOpen = SelectorEngine.findOne(OPEN_SELECTOR);
    if (alreadyOpen && alreadyOpen !== target) {
      Offcanvas.getInstance(alreadyOpen).hide();
    }
    const data = Offcanvas.getOrCreateInstance(target);
    data.toggle(this);
  });
  EventHandler.on(window, EVENT_LOAD_DATA_API$2, () => {
    for (const selector of SelectorEngine.find(OPEN_SELECTOR)) {
      Offcanvas.getOrCreateInstance(selector).show();
    }
  });
  EventHandler.on(window, EVENT_RESIZE, () => {
    for (const element of SelectorEngine.find("[aria-modal][class*=show][class*=offcanvas-]")) {
      if (getComputedStyle(element).position !== "fixed") {
        Offcanvas.getOrCreateInstance(element).hide();
      }
    }
  });
  enableDismissTrigger(Offcanvas);
  defineJQueryPlugin(Offcanvas);
  var ARIA_ATTRIBUTE_PATTERN = /^aria-[\w-]*$/i;
  var DefaultAllowlist = {
    "*": ["class", "dir", "id", "lang", "role", ARIA_ATTRIBUTE_PATTERN],
    a: ["target", "href", "title", "rel"],
    area: [],
    b: [],
    br: [],
    col: [],
    code: [],
    dd: [],
    div: [],
    dl: [],
    dt: [],
    em: [],
    hr: [],
    h1: [],
    h2: [],
    h3: [],
    h4: [],
    h5: [],
    h6: [],
    i: [],
    img: ["src", "srcset", "alt", "title", "width", "height"],
    li: [],
    ol: [],
    p: [],
    pre: [],
    s: [],
    small: [],
    span: [],
    sub: [],
    sup: [],
    strong: [],
    u: [],
    ul: []
  };
  var uriAttributes = /* @__PURE__ */ new Set(["background", "cite", "href", "itemtype", "longdesc", "poster", "src", "xlink:href"]);
  var SAFE_URL_PATTERN = /^(?!javascript:)(?:[a-z0-9+.-]+:|[^&:/?#]*(?:[/?#]|$))/i;
  var allowedAttribute = (attribute, allowedAttributeList) => {
    const attributeName = attribute.nodeName.toLowerCase();
    if (allowedAttributeList.includes(attributeName)) {
      if (uriAttributes.has(attributeName)) {
        return Boolean(SAFE_URL_PATTERN.test(attribute.nodeValue));
      }
      return true;
    }
    return allowedAttributeList.filter((attributeRegex) => attributeRegex instanceof RegExp).some((regex) => regex.test(attributeName));
  };
  function sanitizeHtml(unsafeHtml, allowList, sanitizeFunction) {
    if (!unsafeHtml.length) {
      return unsafeHtml;
    }
    if (sanitizeFunction && typeof sanitizeFunction === "function") {
      return sanitizeFunction(unsafeHtml);
    }
    const domParser = new window.DOMParser();
    const createdDocument = domParser.parseFromString(unsafeHtml, "text/html");
    const elements = [].concat(...createdDocument.body.querySelectorAll("*"));
    for (const element of elements) {
      const elementName = element.nodeName.toLowerCase();
      if (!Object.keys(allowList).includes(elementName)) {
        element.remove();
        continue;
      }
      const attributeList = [].concat(...element.attributes);
      const allowedAttributes = [].concat(allowList["*"] || [], allowList[elementName] || []);
      for (const attribute of attributeList) {
        if (!allowedAttribute(attribute, allowedAttributes)) {
          element.removeAttribute(attribute.nodeName);
        }
      }
    }
    return createdDocument.body.innerHTML;
  }
  var NAME$5 = "TemplateFactory";
  var Default$4 = {
    allowList: DefaultAllowlist,
    content: {},
    extraClass: "",
    html: false,
    sanitize: true,
    sanitizeFn: null,
    template: "<div></div>"
  };
  var DefaultType$4 = {
    allowList: "object",
    content: "object",
    extraClass: "(string|function)",
    html: "boolean",
    sanitize: "boolean",
    sanitizeFn: "(null|function)",
    template: "string"
  };
  var DefaultContentType = {
    entry: "(string|element|function|null)",
    selector: "(string|element)"
  };
  var TemplateFactory = class extends Config {
    constructor(config) {
      super();
      this._config = this._getConfig(config);
    }
    static get Default() {
      return Default$4;
    }
    static get DefaultType() {
      return DefaultType$4;
    }
    static get NAME() {
      return NAME$5;
    }
    getContent() {
      return Object.values(this._config.content).map((config) => this._resolvePossibleFunction(config)).filter(Boolean);
    }
    hasContent() {
      return this.getContent().length > 0;
    }
    changeContent(content) {
      this._checkContent(content);
      this._config.content = {
        ...this._config.content,
        ...content
      };
      return this;
    }
    toHtml() {
      const templateWrapper = document.createElement("div");
      templateWrapper.innerHTML = this._maybeSanitize(this._config.template);
      for (const [selector, text] of Object.entries(this._config.content)) {
        this._setContent(templateWrapper, text, selector);
      }
      const template = templateWrapper.children[0];
      const extraClass = this._resolvePossibleFunction(this._config.extraClass);
      if (extraClass) {
        template.classList.add(...extraClass.split(" "));
      }
      return template;
    }
    _typeCheckConfig(config) {
      super._typeCheckConfig(config);
      this._checkContent(config.content);
    }
    _checkContent(arg) {
      for (const [selector, content] of Object.entries(arg)) {
        super._typeCheckConfig({
          selector,
          entry: content
        }, DefaultContentType);
      }
    }
    _setContent(template, content, selector) {
      const templateElement = SelectorEngine.findOne(selector, template);
      if (!templateElement) {
        return;
      }
      content = this._resolvePossibleFunction(content);
      if (!content) {
        templateElement.remove();
        return;
      }
      if (isElement2(content)) {
        this._putElementInTemplate(getElement(content), templateElement);
        return;
      }
      if (this._config.html) {
        templateElement.innerHTML = this._maybeSanitize(content);
        return;
      }
      templateElement.textContent = content;
    }
    _maybeSanitize(arg) {
      return this._config.sanitize ? sanitizeHtml(arg, this._config.allowList, this._config.sanitizeFn) : arg;
    }
    _resolvePossibleFunction(arg) {
      return execute(arg, [this]);
    }
    _putElementInTemplate(element, templateElement) {
      if (this._config.html) {
        templateElement.innerHTML = "";
        templateElement.append(element);
        return;
      }
      templateElement.textContent = element.textContent;
    }
  };
  var NAME$4 = "tooltip";
  var DISALLOWED_ATTRIBUTES = /* @__PURE__ */ new Set(["sanitize", "allowList", "sanitizeFn"]);
  var CLASS_NAME_FADE$2 = "fade";
  var CLASS_NAME_MODAL = "modal";
  var CLASS_NAME_SHOW$2 = "show";
  var SELECTOR_TOOLTIP_INNER = ".tooltip-inner";
  var SELECTOR_MODAL = `.${CLASS_NAME_MODAL}`;
  var EVENT_MODAL_HIDE = "hide.bs.modal";
  var TRIGGER_HOVER = "hover";
  var TRIGGER_FOCUS = "focus";
  var TRIGGER_CLICK = "click";
  var TRIGGER_MANUAL = "manual";
  var EVENT_HIDE$2 = "hide";
  var EVENT_HIDDEN$2 = "hidden";
  var EVENT_SHOW$2 = "show";
  var EVENT_SHOWN$2 = "shown";
  var EVENT_INSERTED = "inserted";
  var EVENT_CLICK$1 = "click";
  var EVENT_FOCUSIN$1 = "focusin";
  var EVENT_FOCUSOUT$1 = "focusout";
  var EVENT_MOUSEENTER = "mouseenter";
  var EVENT_MOUSELEAVE = "mouseleave";
  var AttachmentMap = {
    AUTO: "auto",
    TOP: "top",
    RIGHT: isRTL() ? "left" : "right",
    BOTTOM: "bottom",
    LEFT: isRTL() ? "right" : "left"
  };
  var Default$3 = {
    allowList: DefaultAllowlist,
    animation: true,
    boundary: "clippingParents",
    container: false,
    customClass: "",
    delay: 0,
    fallbackPlacements: ["top", "right", "bottom", "left"],
    html: false,
    offset: [0, 6],
    placement: "top",
    popperConfig: null,
    sanitize: true,
    sanitizeFn: null,
    selector: false,
    template: '<div class="tooltip" role="tooltip"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>',
    title: "",
    trigger: "hover focus"
  };
  var DefaultType$3 = {
    allowList: "object",
    animation: "boolean",
    boundary: "(string|element)",
    container: "(string|element|boolean)",
    customClass: "(string|function)",
    delay: "(number|object)",
    fallbackPlacements: "array",
    html: "boolean",
    offset: "(array|string|function)",
    placement: "(string|function)",
    popperConfig: "(null|object|function)",
    sanitize: "boolean",
    sanitizeFn: "(null|function)",
    selector: "(string|boolean)",
    template: "string",
    title: "(string|element|function)",
    trigger: "string"
  };
  var Tooltip = class extends BaseComponent {
    constructor(element, config) {
      if (typeof lib_exports === "undefined") {
        throw new TypeError("Bootstrap's tooltips require Popper (https://popper.js.org)");
      }
      super(element, config);
      this._isEnabled = true;
      this._timeout = 0;
      this._isHovered = null;
      this._activeTrigger = {};
      this._popper = null;
      this._templateFactory = null;
      this._newContent = null;
      this.tip = null;
      this._setListeners();
      if (!this._config.selector) {
        this._fixTitle();
      }
    }
    static get Default() {
      return Default$3;
    }
    static get DefaultType() {
      return DefaultType$3;
    }
    static get NAME() {
      return NAME$4;
    }
    enable() {
      this._isEnabled = true;
    }
    disable() {
      this._isEnabled = false;
    }
    toggleEnabled() {
      this._isEnabled = !this._isEnabled;
    }
    toggle() {
      if (!this._isEnabled) {
        return;
      }
      this._activeTrigger.click = !this._activeTrigger.click;
      if (this._isShown()) {
        this._leave();
        return;
      }
      this._enter();
    }
    dispose() {
      clearTimeout(this._timeout);
      EventHandler.off(this._element.closest(SELECTOR_MODAL), EVENT_MODAL_HIDE, this._hideModalHandler);
      if (this._element.getAttribute("data-bs-original-title")) {
        this._element.setAttribute("title", this._element.getAttribute("data-bs-original-title"));
      }
      this._disposePopper();
      super.dispose();
    }
    show() {
      if (this._element.style.display === "none") {
        throw new Error("Please use show on visible elements");
      }
      if (!(this._isWithContent() && this._isEnabled)) {
        return;
      }
      const showEvent = EventHandler.trigger(this._element, this.constructor.eventName(EVENT_SHOW$2));
      const shadowRoot = findShadowRoot(this._element);
      const isInTheDom = (shadowRoot || this._element.ownerDocument.documentElement).contains(this._element);
      if (showEvent.defaultPrevented || !isInTheDom) {
        return;
      }
      this._disposePopper();
      const tip = this._getTipElement();
      this._element.setAttribute("aria-describedby", tip.getAttribute("id"));
      const {
        container
      } = this._config;
      if (!this._element.ownerDocument.documentElement.contains(this.tip)) {
        container.append(tip);
        EventHandler.trigger(this._element, this.constructor.eventName(EVENT_INSERTED));
      }
      this._popper = this._createPopper(tip);
      tip.classList.add(CLASS_NAME_SHOW$2);
      if ("ontouchstart" in document.documentElement) {
        for (const element of [].concat(...document.body.children)) {
          EventHandler.on(element, "mouseover", noop);
        }
      }
      const complete = () => {
        EventHandler.trigger(this._element, this.constructor.eventName(EVENT_SHOWN$2));
        if (this._isHovered === false) {
          this._leave();
        }
        this._isHovered = false;
      };
      this._queueCallback(complete, this.tip, this._isAnimated());
    }
    hide() {
      if (!this._isShown()) {
        return;
      }
      const hideEvent = EventHandler.trigger(this._element, this.constructor.eventName(EVENT_HIDE$2));
      if (hideEvent.defaultPrevented) {
        return;
      }
      const tip = this._getTipElement();
      tip.classList.remove(CLASS_NAME_SHOW$2);
      if ("ontouchstart" in document.documentElement) {
        for (const element of [].concat(...document.body.children)) {
          EventHandler.off(element, "mouseover", noop);
        }
      }
      this._activeTrigger[TRIGGER_CLICK] = false;
      this._activeTrigger[TRIGGER_FOCUS] = false;
      this._activeTrigger[TRIGGER_HOVER] = false;
      this._isHovered = null;
      const complete = () => {
        if (this._isWithActiveTrigger()) {
          return;
        }
        if (!this._isHovered) {
          this._disposePopper();
        }
        this._element.removeAttribute("aria-describedby");
        EventHandler.trigger(this._element, this.constructor.eventName(EVENT_HIDDEN$2));
      };
      this._queueCallback(complete, this.tip, this._isAnimated());
    }
    update() {
      if (this._popper) {
        this._popper.update();
      }
    }
    _isWithContent() {
      return Boolean(this._getTitle());
    }
    _getTipElement() {
      if (!this.tip) {
        this.tip = this._createTipElement(this._newContent || this._getContentForTemplate());
      }
      return this.tip;
    }
    _createTipElement(content) {
      const tip = this._getTemplateFactory(content).toHtml();
      if (!tip) {
        return null;
      }
      tip.classList.remove(CLASS_NAME_FADE$2, CLASS_NAME_SHOW$2);
      tip.classList.add(`bs-${this.constructor.NAME}-auto`);
      const tipId = getUID(this.constructor.NAME).toString();
      tip.setAttribute("id", tipId);
      if (this._isAnimated()) {
        tip.classList.add(CLASS_NAME_FADE$2);
      }
      return tip;
    }
    setContent(content) {
      this._newContent = content;
      if (this._isShown()) {
        this._disposePopper();
        this.show();
      }
    }
    _getTemplateFactory(content) {
      if (this._templateFactory) {
        this._templateFactory.changeContent(content);
      } else {
        this._templateFactory = new TemplateFactory({
          ...this._config,
          content,
          extraClass: this._resolvePossibleFunction(this._config.customClass)
        });
      }
      return this._templateFactory;
    }
    _getContentForTemplate() {
      return {
        [SELECTOR_TOOLTIP_INNER]: this._getTitle()
      };
    }
    _getTitle() {
      return this._resolvePossibleFunction(this._config.title) || this._element.getAttribute("data-bs-original-title");
    }
    _initializeOnDelegatedTarget(event) {
      return this.constructor.getOrCreateInstance(event.delegateTarget, this._getDelegateConfig());
    }
    _isAnimated() {
      return this._config.animation || this.tip && this.tip.classList.contains(CLASS_NAME_FADE$2);
    }
    _isShown() {
      return this.tip && this.tip.classList.contains(CLASS_NAME_SHOW$2);
    }
    _createPopper(tip) {
      const placement = execute(this._config.placement, [this, tip, this._element]);
      const attachment = AttachmentMap[placement.toUpperCase()];
      return createPopper3(this._element, tip, this._getPopperConfig(attachment));
    }
    _getOffset() {
      const {
        offset: offset2
      } = this._config;
      if (typeof offset2 === "string") {
        return offset2.split(",").map((value) => Number.parseInt(value, 10));
      }
      if (typeof offset2 === "function") {
        return (popperData) => offset2(popperData, this._element);
      }
      return offset2;
    }
    _resolvePossibleFunction(arg) {
      return execute(arg, [this._element]);
    }
    _getPopperConfig(attachment) {
      const defaultBsPopperConfig = {
        placement: attachment,
        modifiers: [{
          name: "flip",
          options: {
            fallbackPlacements: this._config.fallbackPlacements
          }
        }, {
          name: "offset",
          options: {
            offset: this._getOffset()
          }
        }, {
          name: "preventOverflow",
          options: {
            boundary: this._config.boundary
          }
        }, {
          name: "arrow",
          options: {
            element: `.${this.constructor.NAME}-arrow`
          }
        }, {
          name: "preSetPlacement",
          enabled: true,
          phase: "beforeMain",
          fn: (data) => {
            this._getTipElement().setAttribute("data-popper-placement", data.state.placement);
          }
        }]
      };
      return {
        ...defaultBsPopperConfig,
        ...execute(this._config.popperConfig, [defaultBsPopperConfig])
      };
    }
    _setListeners() {
      const triggers = this._config.trigger.split(" ");
      for (const trigger of triggers) {
        if (trigger === "click") {
          EventHandler.on(this._element, this.constructor.eventName(EVENT_CLICK$1), this._config.selector, (event) => {
            const context = this._initializeOnDelegatedTarget(event);
            context.toggle();
          });
        } else if (trigger !== TRIGGER_MANUAL) {
          const eventIn = trigger === TRIGGER_HOVER ? this.constructor.eventName(EVENT_MOUSEENTER) : this.constructor.eventName(EVENT_FOCUSIN$1);
          const eventOut = trigger === TRIGGER_HOVER ? this.constructor.eventName(EVENT_MOUSELEAVE) : this.constructor.eventName(EVENT_FOCUSOUT$1);
          EventHandler.on(this._element, eventIn, this._config.selector, (event) => {
            const context = this._initializeOnDelegatedTarget(event);
            context._activeTrigger[event.type === "focusin" ? TRIGGER_FOCUS : TRIGGER_HOVER] = true;
            context._enter();
          });
          EventHandler.on(this._element, eventOut, this._config.selector, (event) => {
            const context = this._initializeOnDelegatedTarget(event);
            context._activeTrigger[event.type === "focusout" ? TRIGGER_FOCUS : TRIGGER_HOVER] = context._element.contains(event.relatedTarget);
            context._leave();
          });
        }
      }
      this._hideModalHandler = () => {
        if (this._element) {
          this.hide();
        }
      };
      EventHandler.on(this._element.closest(SELECTOR_MODAL), EVENT_MODAL_HIDE, this._hideModalHandler);
    }
    _fixTitle() {
      const title = this._element.getAttribute("title");
      if (!title) {
        return;
      }
      if (!this._element.getAttribute("aria-label") && !this._element.textContent.trim()) {
        this._element.setAttribute("aria-label", title);
      }
      this._element.setAttribute("data-bs-original-title", title);
      this._element.removeAttribute("title");
    }
    _enter() {
      if (this._isShown() || this._isHovered) {
        this._isHovered = true;
        return;
      }
      this._isHovered = true;
      this._setTimeout(() => {
        if (this._isHovered) {
          this.show();
        }
      }, this._config.delay.show);
    }
    _leave() {
      if (this._isWithActiveTrigger()) {
        return;
      }
      this._isHovered = false;
      this._setTimeout(() => {
        if (!this._isHovered) {
          this.hide();
        }
      }, this._config.delay.hide);
    }
    _setTimeout(handler, timeout) {
      clearTimeout(this._timeout);
      this._timeout = setTimeout(handler, timeout);
    }
    _isWithActiveTrigger() {
      return Object.values(this._activeTrigger).includes(true);
    }
    _getConfig(config) {
      const dataAttributes = Manipulator.getDataAttributes(this._element);
      for (const dataAttribute of Object.keys(dataAttributes)) {
        if (DISALLOWED_ATTRIBUTES.has(dataAttribute)) {
          delete dataAttributes[dataAttribute];
        }
      }
      config = {
        ...dataAttributes,
        ...typeof config === "object" && config ? config : {}
      };
      config = this._mergeConfigObj(config);
      config = this._configAfterMerge(config);
      this._typeCheckConfig(config);
      return config;
    }
    _configAfterMerge(config) {
      config.container = config.container === false ? document.body : getElement(config.container);
      if (typeof config.delay === "number") {
        config.delay = {
          show: config.delay,
          hide: config.delay
        };
      }
      if (typeof config.title === "number") {
        config.title = config.title.toString();
      }
      if (typeof config.content === "number") {
        config.content = config.content.toString();
      }
      return config;
    }
    _getDelegateConfig() {
      const config = {};
      for (const [key, value] of Object.entries(this._config)) {
        if (this.constructor.Default[key] !== value) {
          config[key] = value;
        }
      }
      config.selector = false;
      config.trigger = "manual";
      return config;
    }
    _disposePopper() {
      if (this._popper) {
        this._popper.destroy();
        this._popper = null;
      }
      if (this.tip) {
        this.tip.remove();
        this.tip = null;
      }
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Tooltip.getOrCreateInstance(this, config);
        if (typeof config !== "string") {
          return;
        }
        if (typeof data[config] === "undefined") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config]();
      });
    }
  };
  defineJQueryPlugin(Tooltip);
  var NAME$3 = "popover";
  var SELECTOR_TITLE = ".popover-header";
  var SELECTOR_CONTENT = ".popover-body";
  var Default$2 = {
    ...Tooltip.Default,
    content: "",
    offset: [0, 8],
    placement: "right",
    template: '<div class="popover" role="tooltip"><div class="popover-arrow"></div><h3 class="popover-header"></h3><div class="popover-body"></div></div>',
    trigger: "click"
  };
  var DefaultType$2 = {
    ...Tooltip.DefaultType,
    content: "(null|string|element|function)"
  };
  var Popover = class extends Tooltip {
    static get Default() {
      return Default$2;
    }
    static get DefaultType() {
      return DefaultType$2;
    }
    static get NAME() {
      return NAME$3;
    }
    _isWithContent() {
      return this._getTitle() || this._getContent();
    }
    _getContentForTemplate() {
      return {
        [SELECTOR_TITLE]: this._getTitle(),
        [SELECTOR_CONTENT]: this._getContent()
      };
    }
    _getContent() {
      return this._resolvePossibleFunction(this._config.content);
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Popover.getOrCreateInstance(this, config);
        if (typeof config !== "string") {
          return;
        }
        if (typeof data[config] === "undefined") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config]();
      });
    }
  };
  defineJQueryPlugin(Popover);
  var NAME$2 = "scrollspy";
  var DATA_KEY$2 = "bs.scrollspy";
  var EVENT_KEY$2 = `.${DATA_KEY$2}`;
  var DATA_API_KEY = ".data-api";
  var EVENT_ACTIVATE = `activate${EVENT_KEY$2}`;
  var EVENT_CLICK = `click${EVENT_KEY$2}`;
  var EVENT_LOAD_DATA_API$1 = `load${EVENT_KEY$2}${DATA_API_KEY}`;
  var CLASS_NAME_DROPDOWN_ITEM = "dropdown-item";
  var CLASS_NAME_ACTIVE$1 = "active";
  var SELECTOR_DATA_SPY = '[data-bs-spy="scroll"]';
  var SELECTOR_TARGET_LINKS = "[href]";
  var SELECTOR_NAV_LIST_GROUP = ".nav, .list-group";
  var SELECTOR_NAV_LINKS = ".nav-link";
  var SELECTOR_NAV_ITEMS = ".nav-item";
  var SELECTOR_LIST_ITEMS = ".list-group-item";
  var SELECTOR_LINK_ITEMS = `${SELECTOR_NAV_LINKS}, ${SELECTOR_NAV_ITEMS} > ${SELECTOR_NAV_LINKS}, ${SELECTOR_LIST_ITEMS}`;
  var SELECTOR_DROPDOWN = ".dropdown";
  var SELECTOR_DROPDOWN_TOGGLE$1 = ".dropdown-toggle";
  var Default$1 = {
    offset: null,
    rootMargin: "0px 0px -25%",
    smoothScroll: false,
    target: null,
    threshold: [0.1, 0.5, 1]
  };
  var DefaultType$1 = {
    offset: "(number|null)",
    rootMargin: "string",
    smoothScroll: "boolean",
    target: "element",
    threshold: "array"
  };
  var ScrollSpy = class extends BaseComponent {
    constructor(element, config) {
      super(element, config);
      this._targetLinks = /* @__PURE__ */ new Map();
      this._observableSections = /* @__PURE__ */ new Map();
      this._rootElement = getComputedStyle(this._element).overflowY === "visible" ? null : this._element;
      this._activeTarget = null;
      this._observer = null;
      this._previousScrollData = {
        visibleEntryTop: 0,
        parentScrollTop: 0
      };
      this.refresh();
    }
    static get Default() {
      return Default$1;
    }
    static get DefaultType() {
      return DefaultType$1;
    }
    static get NAME() {
      return NAME$2;
    }
    refresh() {
      this._initializeTargetsAndObservables();
      this._maybeEnableSmoothScroll();
      if (this._observer) {
        this._observer.disconnect();
      } else {
        this._observer = this._getNewObserver();
      }
      for (const section of this._observableSections.values()) {
        this._observer.observe(section);
      }
    }
    dispose() {
      this._observer.disconnect();
      super.dispose();
    }
    _configAfterMerge(config) {
      config.target = getElement(config.target) || document.body;
      config.rootMargin = config.offset ? `${config.offset}px 0px -30%` : config.rootMargin;
      if (typeof config.threshold === "string") {
        config.threshold = config.threshold.split(",").map((value) => Number.parseFloat(value));
      }
      return config;
    }
    _maybeEnableSmoothScroll() {
      if (!this._config.smoothScroll) {
        return;
      }
      EventHandler.off(this._config.target, EVENT_CLICK);
      EventHandler.on(this._config.target, EVENT_CLICK, SELECTOR_TARGET_LINKS, (event) => {
        const observableSection = this._observableSections.get(event.target.hash);
        if (observableSection) {
          event.preventDefault();
          const root = this._rootElement || window;
          const height = observableSection.offsetTop - this._element.offsetTop;
          if (root.scrollTo) {
            root.scrollTo({
              top: height,
              behavior: "smooth"
            });
            return;
          }
          root.scrollTop = height;
        }
      });
    }
    _getNewObserver() {
      const options = {
        root: this._rootElement,
        threshold: this._config.threshold,
        rootMargin: this._config.rootMargin
      };
      return new IntersectionObserver((entries) => this._observerCallback(entries), options);
    }
    _observerCallback(entries) {
      const targetElement = (entry) => this._targetLinks.get(`#${entry.target.id}`);
      const activate = (entry) => {
        this._previousScrollData.visibleEntryTop = entry.target.offsetTop;
        this._process(targetElement(entry));
      };
      const parentScrollTop = (this._rootElement || document.documentElement).scrollTop;
      const userScrollsDown = parentScrollTop >= this._previousScrollData.parentScrollTop;
      this._previousScrollData.parentScrollTop = parentScrollTop;
      for (const entry of entries) {
        if (!entry.isIntersecting) {
          this._activeTarget = null;
          this._clearActiveClass(targetElement(entry));
          continue;
        }
        const entryIsLowerThanPrevious = entry.target.offsetTop >= this._previousScrollData.visibleEntryTop;
        if (userScrollsDown && entryIsLowerThanPrevious) {
          activate(entry);
          if (!parentScrollTop) {
            return;
          }
          continue;
        }
        if (!userScrollsDown && !entryIsLowerThanPrevious) {
          activate(entry);
        }
      }
    }
    _initializeTargetsAndObservables() {
      this._targetLinks = /* @__PURE__ */ new Map();
      this._observableSections = /* @__PURE__ */ new Map();
      const targetLinks = SelectorEngine.find(SELECTOR_TARGET_LINKS, this._config.target);
      for (const anchor of targetLinks) {
        if (!anchor.hash || isDisabled(anchor)) {
          continue;
        }
        const observableSection = SelectorEngine.findOne(decodeURI(anchor.hash), this._element);
        if (isVisible(observableSection)) {
          this._targetLinks.set(decodeURI(anchor.hash), anchor);
          this._observableSections.set(anchor.hash, observableSection);
        }
      }
    }
    _process(target) {
      if (this._activeTarget === target) {
        return;
      }
      this._clearActiveClass(this._config.target);
      this._activeTarget = target;
      target.classList.add(CLASS_NAME_ACTIVE$1);
      this._activateParents(target);
      EventHandler.trigger(this._element, EVENT_ACTIVATE, {
        relatedTarget: target
      });
    }
    _activateParents(target) {
      if (target.classList.contains(CLASS_NAME_DROPDOWN_ITEM)) {
        SelectorEngine.findOne(SELECTOR_DROPDOWN_TOGGLE$1, target.closest(SELECTOR_DROPDOWN)).classList.add(CLASS_NAME_ACTIVE$1);
        return;
      }
      for (const listGroup of SelectorEngine.parents(target, SELECTOR_NAV_LIST_GROUP)) {
        for (const item of SelectorEngine.prev(listGroup, SELECTOR_LINK_ITEMS)) {
          item.classList.add(CLASS_NAME_ACTIVE$1);
        }
      }
    }
    _clearActiveClass(parent) {
      parent.classList.remove(CLASS_NAME_ACTIVE$1);
      const activeNodes = SelectorEngine.find(`${SELECTOR_TARGET_LINKS}.${CLASS_NAME_ACTIVE$1}`, parent);
      for (const node of activeNodes) {
        node.classList.remove(CLASS_NAME_ACTIVE$1);
      }
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = ScrollSpy.getOrCreateInstance(this, config);
        if (typeof config !== "string") {
          return;
        }
        if (data[config] === void 0 || config.startsWith("_") || config === "constructor") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config]();
      });
    }
  };
  EventHandler.on(window, EVENT_LOAD_DATA_API$1, () => {
    for (const spy of SelectorEngine.find(SELECTOR_DATA_SPY)) {
      ScrollSpy.getOrCreateInstance(spy);
    }
  });
  defineJQueryPlugin(ScrollSpy);
  var NAME$1 = "tab";
  var DATA_KEY$1 = "bs.tab";
  var EVENT_KEY$1 = `.${DATA_KEY$1}`;
  var EVENT_HIDE$1 = `hide${EVENT_KEY$1}`;
  var EVENT_HIDDEN$1 = `hidden${EVENT_KEY$1}`;
  var EVENT_SHOW$1 = `show${EVENT_KEY$1}`;
  var EVENT_SHOWN$1 = `shown${EVENT_KEY$1}`;
  var EVENT_CLICK_DATA_API = `click${EVENT_KEY$1}`;
  var EVENT_KEYDOWN = `keydown${EVENT_KEY$1}`;
  var EVENT_LOAD_DATA_API = `load${EVENT_KEY$1}`;
  var ARROW_LEFT_KEY = "ArrowLeft";
  var ARROW_RIGHT_KEY = "ArrowRight";
  var ARROW_UP_KEY = "ArrowUp";
  var ARROW_DOWN_KEY = "ArrowDown";
  var HOME_KEY = "Home";
  var END_KEY = "End";
  var CLASS_NAME_ACTIVE = "active";
  var CLASS_NAME_FADE$1 = "fade";
  var CLASS_NAME_SHOW$1 = "show";
  var CLASS_DROPDOWN = "dropdown";
  var SELECTOR_DROPDOWN_TOGGLE = ".dropdown-toggle";
  var SELECTOR_DROPDOWN_MENU = ".dropdown-menu";
  var NOT_SELECTOR_DROPDOWN_TOGGLE = `:not(${SELECTOR_DROPDOWN_TOGGLE})`;
  var SELECTOR_TAB_PANEL = '.list-group, .nav, [role="tablist"]';
  var SELECTOR_OUTER = ".nav-item, .list-group-item";
  var SELECTOR_INNER = `.nav-link${NOT_SELECTOR_DROPDOWN_TOGGLE}, .list-group-item${NOT_SELECTOR_DROPDOWN_TOGGLE}, [role="tab"]${NOT_SELECTOR_DROPDOWN_TOGGLE}`;
  var SELECTOR_DATA_TOGGLE = '[data-bs-toggle="tab"], [data-bs-toggle="pill"], [data-bs-toggle="list"]';
  var SELECTOR_INNER_ELEM = `${SELECTOR_INNER}, ${SELECTOR_DATA_TOGGLE}`;
  var SELECTOR_DATA_TOGGLE_ACTIVE = `.${CLASS_NAME_ACTIVE}[data-bs-toggle="tab"], .${CLASS_NAME_ACTIVE}[data-bs-toggle="pill"], .${CLASS_NAME_ACTIVE}[data-bs-toggle="list"]`;
  var Tab = class extends BaseComponent {
    constructor(element) {
      super(element);
      this._parent = this._element.closest(SELECTOR_TAB_PANEL);
      if (!this._parent) {
        return;
      }
      this._setInitialAttributes(this._parent, this._getChildren());
      EventHandler.on(this._element, EVENT_KEYDOWN, (event) => this._keydown(event));
    }
    static get NAME() {
      return NAME$1;
    }
    show() {
      const innerElem = this._element;
      if (this._elemIsActive(innerElem)) {
        return;
      }
      const active = this._getActiveElem();
      const hideEvent = active ? EventHandler.trigger(active, EVENT_HIDE$1, {
        relatedTarget: innerElem
      }) : null;
      const showEvent = EventHandler.trigger(innerElem, EVENT_SHOW$1, {
        relatedTarget: active
      });
      if (showEvent.defaultPrevented || hideEvent && hideEvent.defaultPrevented) {
        return;
      }
      this._deactivate(active, innerElem);
      this._activate(innerElem, active);
    }
    _activate(element, relatedElem) {
      if (!element) {
        return;
      }
      element.classList.add(CLASS_NAME_ACTIVE);
      this._activate(SelectorEngine.getElementFromSelector(element));
      const complete = () => {
        if (element.getAttribute("role") !== "tab") {
          element.classList.add(CLASS_NAME_SHOW$1);
          return;
        }
        element.removeAttribute("tabindex");
        element.setAttribute("aria-selected", true);
        this._toggleDropDown(element, true);
        EventHandler.trigger(element, EVENT_SHOWN$1, {
          relatedTarget: relatedElem
        });
      };
      this._queueCallback(complete, element, element.classList.contains(CLASS_NAME_FADE$1));
    }
    _deactivate(element, relatedElem) {
      if (!element) {
        return;
      }
      element.classList.remove(CLASS_NAME_ACTIVE);
      element.blur();
      this._deactivate(SelectorEngine.getElementFromSelector(element));
      const complete = () => {
        if (element.getAttribute("role") !== "tab") {
          element.classList.remove(CLASS_NAME_SHOW$1);
          return;
        }
        element.setAttribute("aria-selected", false);
        element.setAttribute("tabindex", "-1");
        this._toggleDropDown(element, false);
        EventHandler.trigger(element, EVENT_HIDDEN$1, {
          relatedTarget: relatedElem
        });
      };
      this._queueCallback(complete, element, element.classList.contains(CLASS_NAME_FADE$1));
    }
    _keydown(event) {
      if (![ARROW_LEFT_KEY, ARROW_RIGHT_KEY, ARROW_UP_KEY, ARROW_DOWN_KEY, HOME_KEY, END_KEY].includes(event.key)) {
        return;
      }
      event.stopPropagation();
      event.preventDefault();
      const children = this._getChildren().filter((element) => !isDisabled(element));
      let nextActiveElement;
      if ([HOME_KEY, END_KEY].includes(event.key)) {
        nextActiveElement = children[event.key === HOME_KEY ? 0 : children.length - 1];
      } else {
        const isNext = [ARROW_RIGHT_KEY, ARROW_DOWN_KEY].includes(event.key);
        nextActiveElement = getNextActiveElement(children, event.target, isNext, true);
      }
      if (nextActiveElement) {
        nextActiveElement.focus({
          preventScroll: true
        });
        Tab.getOrCreateInstance(nextActiveElement).show();
      }
    }
    _getChildren() {
      return SelectorEngine.find(SELECTOR_INNER_ELEM, this._parent);
    }
    _getActiveElem() {
      return this._getChildren().find((child) => this._elemIsActive(child)) || null;
    }
    _setInitialAttributes(parent, children) {
      this._setAttributeIfNotExists(parent, "role", "tablist");
      for (const child of children) {
        this._setInitialAttributesOnChild(child);
      }
    }
    _setInitialAttributesOnChild(child) {
      child = this._getInnerElement(child);
      const isActive = this._elemIsActive(child);
      const outerElem = this._getOuterElement(child);
      child.setAttribute("aria-selected", isActive);
      if (outerElem !== child) {
        this._setAttributeIfNotExists(outerElem, "role", "presentation");
      }
      if (!isActive) {
        child.setAttribute("tabindex", "-1");
      }
      this._setAttributeIfNotExists(child, "role", "tab");
      this._setInitialAttributesOnTargetPanel(child);
    }
    _setInitialAttributesOnTargetPanel(child) {
      const target = SelectorEngine.getElementFromSelector(child);
      if (!target) {
        return;
      }
      this._setAttributeIfNotExists(target, "role", "tabpanel");
      if (child.id) {
        this._setAttributeIfNotExists(target, "aria-labelledby", `${child.id}`);
      }
    }
    _toggleDropDown(element, open) {
      const outerElem = this._getOuterElement(element);
      if (!outerElem.classList.contains(CLASS_DROPDOWN)) {
        return;
      }
      const toggle = (selector, className) => {
        const element2 = SelectorEngine.findOne(selector, outerElem);
        if (element2) {
          element2.classList.toggle(className, open);
        }
      };
      toggle(SELECTOR_DROPDOWN_TOGGLE, CLASS_NAME_ACTIVE);
      toggle(SELECTOR_DROPDOWN_MENU, CLASS_NAME_SHOW$1);
      outerElem.setAttribute("aria-expanded", open);
    }
    _setAttributeIfNotExists(element, attribute, value) {
      if (!element.hasAttribute(attribute)) {
        element.setAttribute(attribute, value);
      }
    }
    _elemIsActive(elem) {
      return elem.classList.contains(CLASS_NAME_ACTIVE);
    }
    _getInnerElement(elem) {
      return elem.matches(SELECTOR_INNER_ELEM) ? elem : SelectorEngine.findOne(SELECTOR_INNER_ELEM, elem);
    }
    _getOuterElement(elem) {
      return elem.closest(SELECTOR_OUTER) || elem;
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Tab.getOrCreateInstance(this);
        if (typeof config !== "string") {
          return;
        }
        if (data[config] === void 0 || config.startsWith("_") || config === "constructor") {
          throw new TypeError(`No method named "${config}"`);
        }
        data[config]();
      });
    }
  };
  EventHandler.on(document, EVENT_CLICK_DATA_API, SELECTOR_DATA_TOGGLE, function(event) {
    if (["A", "AREA"].includes(this.tagName)) {
      event.preventDefault();
    }
    if (isDisabled(this)) {
      return;
    }
    Tab.getOrCreateInstance(this).show();
  });
  EventHandler.on(window, EVENT_LOAD_DATA_API, () => {
    for (const element of SelectorEngine.find(SELECTOR_DATA_TOGGLE_ACTIVE)) {
      Tab.getOrCreateInstance(element);
    }
  });
  defineJQueryPlugin(Tab);
  var NAME = "toast";
  var DATA_KEY = "bs.toast";
  var EVENT_KEY = `.${DATA_KEY}`;
  var EVENT_MOUSEOVER = `mouseover${EVENT_KEY}`;
  var EVENT_MOUSEOUT = `mouseout${EVENT_KEY}`;
  var EVENT_FOCUSIN = `focusin${EVENT_KEY}`;
  var EVENT_FOCUSOUT = `focusout${EVENT_KEY}`;
  var EVENT_HIDE = `hide${EVENT_KEY}`;
  var EVENT_HIDDEN = `hidden${EVENT_KEY}`;
  var EVENT_SHOW = `show${EVENT_KEY}`;
  var EVENT_SHOWN = `shown${EVENT_KEY}`;
  var CLASS_NAME_FADE = "fade";
  var CLASS_NAME_HIDE = "hide";
  var CLASS_NAME_SHOW = "show";
  var CLASS_NAME_SHOWING = "showing";
  var DefaultType = {
    animation: "boolean",
    autohide: "boolean",
    delay: "number"
  };
  var Default = {
    animation: true,
    autohide: true,
    delay: 5e3
  };
  var Toast = class extends BaseComponent {
    constructor(element, config) {
      super(element, config);
      this._timeout = null;
      this._hasMouseInteraction = false;
      this._hasKeyboardInteraction = false;
      this._setListeners();
    }
    static get Default() {
      return Default;
    }
    static get DefaultType() {
      return DefaultType;
    }
    static get NAME() {
      return NAME;
    }
    show() {
      const showEvent = EventHandler.trigger(this._element, EVENT_SHOW);
      if (showEvent.defaultPrevented) {
        return;
      }
      this._clearTimeout();
      if (this._config.animation) {
        this._element.classList.add(CLASS_NAME_FADE);
      }
      const complete = () => {
        this._element.classList.remove(CLASS_NAME_SHOWING);
        EventHandler.trigger(this._element, EVENT_SHOWN);
        this._maybeScheduleHide();
      };
      this._element.classList.remove(CLASS_NAME_HIDE);
      reflow(this._element);
      this._element.classList.add(CLASS_NAME_SHOW, CLASS_NAME_SHOWING);
      this._queueCallback(complete, this._element, this._config.animation);
    }
    hide() {
      if (!this.isShown()) {
        return;
      }
      const hideEvent = EventHandler.trigger(this._element, EVENT_HIDE);
      if (hideEvent.defaultPrevented) {
        return;
      }
      const complete = () => {
        this._element.classList.add(CLASS_NAME_HIDE);
        this._element.classList.remove(CLASS_NAME_SHOWING, CLASS_NAME_SHOW);
        EventHandler.trigger(this._element, EVENT_HIDDEN);
      };
      this._element.classList.add(CLASS_NAME_SHOWING);
      this._queueCallback(complete, this._element, this._config.animation);
    }
    dispose() {
      this._clearTimeout();
      if (this.isShown()) {
        this._element.classList.remove(CLASS_NAME_SHOW);
      }
      super.dispose();
    }
    isShown() {
      return this._element.classList.contains(CLASS_NAME_SHOW);
    }
    _maybeScheduleHide() {
      if (!this._config.autohide) {
        return;
      }
      if (this._hasMouseInteraction || this._hasKeyboardInteraction) {
        return;
      }
      this._timeout = setTimeout(() => {
        this.hide();
      }, this._config.delay);
    }
    _onInteraction(event, isInteracting) {
      switch (event.type) {
        case "mouseover":
        case "mouseout": {
          this._hasMouseInteraction = isInteracting;
          break;
        }
        case "focusin":
        case "focusout": {
          this._hasKeyboardInteraction = isInteracting;
          break;
        }
      }
      if (isInteracting) {
        this._clearTimeout();
        return;
      }
      const nextElement = event.relatedTarget;
      if (this._element === nextElement || this._element.contains(nextElement)) {
        return;
      }
      this._maybeScheduleHide();
    }
    _setListeners() {
      EventHandler.on(this._element, EVENT_MOUSEOVER, (event) => this._onInteraction(event, true));
      EventHandler.on(this._element, EVENT_MOUSEOUT, (event) => this._onInteraction(event, false));
      EventHandler.on(this._element, EVENT_FOCUSIN, (event) => this._onInteraction(event, true));
      EventHandler.on(this._element, EVENT_FOCUSOUT, (event) => this._onInteraction(event, false));
    }
    _clearTimeout() {
      clearTimeout(this._timeout);
      this._timeout = null;
    }
    static jQueryInterface(config) {
      return this.each(function() {
        const data = Toast.getOrCreateInstance(this, config);
        if (typeof config === "string") {
          if (typeof data[config] === "undefined") {
            throw new TypeError(`No method named "${config}"`);
          }
          data[config](this);
        }
      });
    }
  };
  enableDismissTrigger(Toast);
  defineJQueryPlugin(Toast);

  // app/javascript/controllers/modal_controller.js
  var modal_controller_default = class extends Controller {
    connect() {
      console.log("modal here");
    }
    closeModal() {
      this.dispatch("closeModal");
    }
    next_splide() {
      window.survey_splide.go(">");
    }
    prev_splide() {
      window.survey_splide.go("<");
    }
  };

  // app/javascript/controllers/sign_up_controller.js
  var sign_up_controller_default = class extends Controller {
    connect() {
      this.checkFormValidity();
    }
    checkFormValidity() {
      if (this.isValidDate(this.yTarget.value, this.mTarget.value, this.dTarget.value) && this.yTarget.value >= new Date().getFullYear() - 100 && this.sTarget.value != 0 && (this.zTarget.value.length == 0 || this.zTarget.value.length == 5 && this.zConfirmTarget.innerHTML != "") && true) {
        this.enableSubmit();
      } else {
        this.disableSubmit();
      }
    }
    enableSubmit() {
      this.submitButtonTarget.disabled = false;
    }
    disableSubmit() {
      this.submitButtonTarget.disabled = true;
    }
    isValidDate(year, month, day) {
      const date2 = new Date(year, month - 1, day);
      return year.length == 4 && month.length == 2 && day.length == 2 && date2.getFullYear() == year && date2.getMonth() == month - 1 && date2.getDate() == day;
    }
  };
  __publicField(sign_up_controller_default, "targets", ["s", "y", "m", "d", "z", "zConfirm", "submitButton"]);

  // app/javascript/controllers/survey_splide_controller.js
  var survey_splide_controller_default = class extends Controller {
    connect() {
      console.log("survey_splide here");
      this.set_survey_splide();
    }
    closeModal() {
      this.dispatch("closeModal");
    }
    set_survey_splide() {
      console.log("set_survey_splide");
      setTimeout(() => {
        window.survey_splide = new Splide(".splide");
        window.survey_splide.mount();
        this.color_pagination();
        this.set_pagination_listner();
      }, 500);
    }
    set_pagination_listner() {
      var elementToObserve = window.document.getElementById("completion_string_frame");
      var observer = new MutationObserver(() => {
        this.color_pagination();
      });
      observer.observe(elementToObserve, { childList: true });
    }
    next_splide() {
      window.survey_splide.go(">");
    }
    prev_splide() {
      window.survey_splide.go("<");
    }
    color_pagination() {
      var completionArray = Array.from(document.getElementById("completion_string").innerText);
      var index = 0;
      window.survey_splide.Components.Pagination.data.items.forEach(function(item) {
        if (completionArray[index] == "1") {
          item.button.className += " bg-success";
        }
        index++;
      });
      if (!completionArray.includes("0")) {
        window.document.getElementById("survey-done-button").classList.add("btn-success");
      }
    }
  };

  // app/javascript/controllers/tag_controller.js
  var tag_controller_default = class extends Controller {
    flash_green() {
      let tagEl = document.getElementById("tag-box-trait-id-" + this.traitidValue);
      console.log(tagEl);
      for (var i = 0; i < tagEl.children.length; i++) {
        tagEl.children[i].classList.add("flash-green");
      }
      setTimeout(function() {
        console.log("remove class " + this.traitidValue);
        for (var i2 = 0; i2 < tagEl.children.length; i2++) {
          tagEl.children[i2].classList.remove("flash-green");
        }
      }, 800);
    }
    flash_red() {
      let tagEl = document.getElementById("tag-box-trait-id-" + this.traitidValue);
      for (var i = 0; i < tagEl.children.length; i++) {
        tagEl.children[i].classList.add("flash-red");
      }
      tagEl.classList.add("delete-shrink");
    }
    delete_tag() {
    }
  };
  __publicField(tag_controller_default, "values", {
    traitid: String
  });

  // app/javascript/controllers/three_tap_unit_controller.js
  var three_tap_unit_controller_default = class extends Controller {
    reveal() {
      console.log("three-tap reveal");
      this.coverTarget.className += " open";
      this.revealAreaTarget.remove();
      const event = new CustomEvent("update-stats");
      window.dispatchEvent(event);
    }
    banner() {
      console.log("three-tap banner");
      this.collectForBanner();
      this.coverTarget.remove();
      this.bannerAreaTarget.remove();
      this.bannerPromptTarget.remove();
      this.jumpTarget.classList.remove("three-tap-nonactive");
      this.bannerTarget.className += " up";
    }
    async jump() {
      console.log("three-tap jump");
      var confirmation = window.open("/link_jumper/" + this.offerValue, "_blank");
      while (confirmation === null) {
        console.log("window not yet open");
      }
      const result_json = await this.collectForJump();
      console.log("three-tap jump return from collectForJump = " + result_json);
      this.bannerTarget.remove();
      this.jumpAreaTarget.remove();
      this.stateStripTarget.remove();
      this.jumpTarget.className += " up";
      const formatter = new Intl.NumberFormat("en-US", {
        style: "currency",
        currency: "USD"
      });
      this.collectedTarget.innerHTML = formatter.format(JSON.parse(result_json).offer.collected_amount);
      this.givenTarget.innerHTML = formatter.format(JSON.parse(result_json).offer.given_amount);
    }
    async collectForBanner() {
      const response = await post("/ad_viewer/banner_impression_collection", { body: { offer_id: this.offerValue }, headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content }, responseKind: "json" });
      const json = await response.json;
      const event = new CustomEvent("update-stats");
      window.dispatchEvent(event);
      return JSON.stringify(json);
    }
    async collectForJump() {
      console.log("three-tap collectForJump");
      const response = await post("/ad_viewer/ad_jump_collection", { body: { offer_id: this.offerValue }, headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content }, responseKind: "json" });
      console.log("three-tap collectForJump response = " + String(response));
      const json = await response.json;
      console.log("three-tap collectForJump json = " + json);
      const event = new CustomEvent("update-stats");
      window.dispatchEvent(event);
      return JSON.stringify(json);
    }
  };
  __publicField(three_tap_unit_controller_default, "values", {
    offer: String
  });
  __publicField(three_tap_unit_controller_default, "targets", ["cover", "banner", "jump", "revealArea", "bannerArea", "jumpArea", "collected", "given", "app", "bannerPrompt", "textPrompt", "stateStrip"]);

  // app/javascript/controllers/zip_check_controller.js
  var zip_check_controller_default = class extends Controller {
    connect() {
    }
    keyup() {
      const regex = /[^\d]/g;
      this.zipInputTarget.value = this.zipInputTarget.value.replace(regex, "");
      if (this.zipInputTarget.value.length === 5) {
        this.getCityState();
      } else {
        this.clearZipMessage();
      }
    }
    clearZipMessage() {
      this.errorOutputTarget.innerHTML = ``;
      this.zipOutputTarget.innerHTML = "";
    }
    async getCityState() {
      const response = await get(`/me_file_starter/get_zip_code_info/${this.zipInputTarget.value}`, { responseKind: "json" });
      const json = await response.json;
      if (json.error) {
        this.zipOutputTarget.innerHTML = json.error;
      } else {
        if (json.city == null || json.state == null) {
          this.errorOutputTarget.innerHTML = `Invalid Zip Code`;
          this.zipOutputTarget.innerHTML = "";
        } else {
          this.zipOutputTarget.innerHTML = `Area: ${json.city}, ${json.state}`;
          this.errorOutputTarget.innerHTML = ``;
        }
      }
      this.dispatch("checkForm");
    }
  };
  __publicField(zip_check_controller_default, "targets", ["zipOutput", "zipInput", "errorOutput"]);

  // app/javascript/controllers/tip_drawer_controller.js
  var tip_drawer_controller_default = class extends Controller {
    connect() {
      console.log("drawer reporting for duty");
    }
    toggleDrawer() {
      const drawer = document.querySelector(".tip-drawer");
      const drawerHeight = drawer.offsetHeight;
      const viewportHeight = window.innerHeight;
      console.log("toggle drawer");
      document.body.classList.toggle("tip-drawer-open");
      if (this.drawerTarget.classList.contains("open")) {
        this.drawerTarget.classList.remove("open");
        this.drawerTarget.style.top = `${viewportHeight - 80}px`;
        var currentMode = "closed";
      } else {
        const topPosition = viewportHeight - drawerHeight - 40;
        this.drawerTarget.style.top = `${topPosition}px`;
        this.drawerTarget.className += " open";
        var currentMode = "open";
      }
    }
  };
  __publicField(tip_drawer_controller_default, "values", {
    offer: String
  });
  __publicField(tip_drawer_controller_default, "targets", ["drawer"]);

  // app/javascript/controllers/index.js
  application.register("app", app_controller_default);
  application.register("app-page", app_page_controller_default);
  application.register("dob", dob_controller_default);
  application.register("gender-check", gender_check_controller_default);
  application.register("guide-splide", guide_splide_controller_default);
  application.register("link-jump", link_jump_controller_default);
  application.register("modal", modal_controller_default);
  application.register("sign-up", sign_up_controller_default);
  application.register("survey-splide", survey_splide_controller_default);
  application.register("tag", tag_controller_default);
  application.register("three-tap-unit", three_tap_unit_controller_default);
  application.register("zip-check", zip_check_controller_default);
  application.register("tip-drawer", tip_drawer_controller_default);

  // app/javascript/mobilekit/base.js
  var Mobilekit = {
    version: "2.9",
    PWA: {
      enable: true
    },
    Dark_Mode: {
      default: false,
      night_mode: {
        enable: false,
        start_time: 20,
        end_time: 7
      },
      auto_detect: {
        enable: false
      }
    },
    RTL: {
      enable: false
    },
    Test: {
      enable: true,
      word: "testmode",
      alert: true,
      alertMessage: "Test mode has been activated. Look at the developer console!"
    }
  };
  var pageBody = document.querySelector("body");
  var appSidebar = document.getElementById("sidebarPanel");
  var loader = document.getElementById("loader");
  setTimeout(() => {
    loader.setAttribute("style", "pointer-events: none; opacity: 0; transition: 0.2s ease-in-out;");
    setTimeout(() => {
      loader.setAttribute("style", "display: none;");
    }, 1e3);
  }, 450);
  if (Mobilekit.RTL.enable) {
    pageHTML = document.querySelector("html");
    pageHTML.dir = "rtl";
    document.querySelector("body").classList.add("rtl-mode");
    if (appSidebar != null) {
      appSidebar.classList.remove("offcanvas-start");
      appSidebar.classList.add("offcanvas-end");
    }
    document.querySelectorAll(".carousel-full, .carousel-single, .carousel-multiple, .carousel-small, .carousel-slider, .story-block").forEach(function(el) {
      el.setAttribute("data-splide", '{"direction":"rtl"}');
    });
  }
  var pageHTML;
  var aWithHref = document.querySelectorAll('a[href*="#"]');
  aWithHref.forEach(function(el) {
    el.addEventListener("click", function(e) {
      e.preventDefault();
    });
  });
  var goTopButton = document.querySelectorAll(".goTop");
  goTopButton.forEach(function(el) {
    window.addEventListener("scroll", function() {
      var scrolled = window.scrollY;
      if (scrolled > 100) {
        el.classList.add("show");
      } else {
        el.classList.remove("show");
      }
    });
    el.addEventListener("click", function(e) {
      e.preventDefault();
      window.scrollTo({
        top: 0,
        behavior: "smooth"
      });
    });
  });
  var goBackButton = document.querySelectorAll(".goBack");
  goBackButton.forEach(function(el) {
    el.addEventListener("click", function() {
      window.history.go(-1);
    });
  });
  var adboxCloseButton = document.querySelectorAll(".adbox .closebutton");
  adboxCloseButton.forEach(function(el) {
    el.addEventListener("click", function() {
      var adbox = this.parentElement;
      adbox.classList.add("hide");
    });
  });
  var date = new Date();
  var nowYear = date.getFullYear();
  var copyrightYear = document.querySelectorAll(".yearNow");
  copyrightYear.forEach(function(el) {
    el.innerHTML = nowYear;
  });
  var storiesButton = document.querySelectorAll("[data-component='stories']");
  storiesButton.forEach(function(el) {
    el.addEventListener("click", function() {
      var target = this.getAttribute("data-bs-target");
      var content = document.querySelector(target + " .modal-content");
      var storytime = this.getAttribute("data-time");
      target = document.querySelector(target);
      if (storytime) {
        target.classList.add("with-story-bar");
        content.appendChild(document.createElement("div")).className = "story-bar";
        var storybar = document.querySelector("#" + target.id + " .story-bar");
        storybar.innerHTML = "<span></span>";
        document.querySelector("#" + target.id + " .story-bar span").animate({
          width: "100%"
        }, storytime);
        var storyTimeout = setTimeout(() => {
          var modalEl = document.getElementById(target.id);
          var modal = bootstrap.Modal.getInstance(modalEl);
          modal.hide();
          storybar.remove();
          target.classList.remove("with-story-bar");
        }, storytime);
        var closeButton = document.querySelectorAll(".close-stories");
        closeButton.forEach(function(el2) {
          el2.addEventListener("click", function() {
            clearTimeout(storyTimeout);
            storybar.remove();
            target.classList.remove("with-story-bar");
          });
        });
      }
    });
  });
  var osDetection = navigator.userAgent || navigator.vendor || window.opera;
  var windowsPhoneDetection = /windows phone/i.test(osDetection);
  var androidDetection = /android/i.test(osDetection);
  var iosDetection = /iPad|iPhone|iPod/.test(osDetection) && !window.MSStream;
  var detectionWindowsPhone = document.querySelectorAll(".windowsphone-detection");
  var detectionAndroid = document.querySelectorAll(".android-detection");
  var detectioniOS = document.querySelectorAll(".ios-detection");
  var detectionNone = document.querySelectorAll(".non-mobile-detection");
  if (windowsPhoneDetection) {
    detectionWindowsPhone.forEach(function(el) {
      el.classList.add("is-active");
    });
  } else if (androidDetection) {
    detectionAndroid.forEach(function(el) {
      el.classList.add("is-active");
    });
  } else if (iosDetection) {
    detectioniOS.forEach(function(el) {
      el.classList.add("is-active");
    });
  } else {
    detectionNone.forEach(function(el) {
      el.classList.add("is-active");
    });
  }
  var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
  var tooltipList = tooltipTriggerList.map(function(tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl);
  });
  var clearInput = document.querySelectorAll(".clear-input");
  clearInput.forEach(function(el) {
    el.addEventListener("click", function() {
      var parent = this.parentElement;
      var input = parent.querySelector(".form-control");
      input.focus();
      input.value = "";
      parent.classList.remove("not-empty");
    });
  });
  var formControl = document.querySelectorAll(".form-group .form-control");
  formControl.forEach(function(el) {
    el.addEventListener("focus", () => {
      var parent = el.parentElement;
      parent.classList.add("active");
    });
    el.addEventListener("blur", () => {
      var parent = el.parentElement;
      parent.classList.remove("active");
    });
    el.addEventListener("keyup", log);
    function log(e) {
      var inputCheck = this.value.length;
      if (inputCheck > 0) {
        this.parentElement.classList.add("not-empty");
      } else {
        this.parentElement.classList.remove("not-empty");
      }
    }
  });
  var searchboxToggle = document.querySelectorAll(".toggle-searchbox");
  searchboxToggle.forEach(function(el) {
    el.addEventListener("click", function() {
      var search = document.getElementById("search");
      var a = search.classList.contains("show");
      if (a) {
        search.classList.remove("show");
      } else {
        search.classList.add("show");
        search.querySelector(".form-control").focus();
      }
    });
  });
  var stepperUp = document.querySelectorAll(".stepper-up");
  stepperUp.forEach(function(el) {
    el.addEventListener("click", function() {
      var input = el.parentElement.querySelector(".form-control");
      input.value = parseInt(input.value) + 1;
    });
  });
  var stepperDown = document.querySelectorAll(".stepper-down");
  stepperDown.forEach(function(el) {
    el.addEventListener("click", function() {
      var input = el.parentElement.querySelector(".form-control");
      if (parseInt(input.value) > 0) {
        input.value = parseInt(input.value) - 1;
      }
    });
  });
  document.addEventListener("DOMContentLoaded", function() {
    document.querySelectorAll(".carousel-full").forEach((carousel) => new Splide(carousel, {
      perPage: 1,
      rewind: true,
      type: "loop",
      gap: 0,
      arrows: false,
      pagination: false
    }).mount());
    document.querySelectorAll(".carousel-single").forEach((carousel) => new Splide(carousel, {
      perPage: 3,
      rewind: true,
      type: "loop",
      gap: 16,
      padding: 16,
      arrows: false,
      pagination: false,
      breakpoints: {
        768: {
          perPage: 1
        },
        991: {
          perPage: 2
        }
      }
    }).mount());
    document.querySelectorAll(".carousel-multiple").forEach((carousel) => new Splide(carousel, {
      perPage: 4,
      rewind: true,
      gap: 16,
      padding: 16,
      arrows: false,
      pagination: false,
      breakpoints: {
        768: {
          perPage: 2
        },
        991: {
          perPage: 5
        }
      }
    }).mount());
    document.querySelectorAll(".carousel-small").forEach((carousel) => new Splide(carousel, {
      perPage: 9,
      rewind: false,
      type: "loop",
      gap: 16,
      padding: 16,
      arrows: false,
      pagination: false,
      breakpoints: {
        768: {
          perPage: 5
        },
        991: {
          perPage: 7
        }
      }
    }).mount());
    document.querySelectorAll(".carousel-slider").forEach((carousel) => new Splide(carousel, {
      perPage: 1,
      rewind: false,
      type: "loop",
      gap: 16,
      padding: 16,
      arrows: false,
      pagination: true
    }).mount());
    document.querySelectorAll(".story-block").forEach((carousel) => new Splide(carousel, {
      perPage: 16,
      rewind: false,
      type: "slide",
      gap: 16,
      padding: 16,
      arrows: false,
      pagination: false,
      breakpoints: {
        500: {
          perPage: 4
        },
        768: {
          perPage: 7
        },
        1200: {
          perPage: 11
        }
      }
    }).mount());
  });
  var notificationCloseButton = document.querySelectorAll(".notification-box .close-button");
  var notificationTaptoClose = document.querySelectorAll(".tap-to-close .notification-dialog");
  var notificationBox = document.querySelectorAll(".notification-box");
  var autoCloseNotification;
  function closeNotificationBox() {
    notificationBox.forEach(function(el) {
      el.classList.remove("show");
      clearTimeout(autoCloseNotification);
    });
  }
  notificationCloseButton.forEach(function(el) {
    el.addEventListener("click", function(e) {
      e.preventDefault();
      closeNotificationBox();
    });
  });
  notificationTaptoClose.forEach(function(el) {
    el.addEventListener("click", function(e) {
      closeNotificationBox();
    });
  });
  var toastCloseButton = document.querySelectorAll(".toast-box .close-button");
  var toastTaptoClose = document.querySelectorAll(".toast-box.tap-to-close");
  var toastBoxes = document.querySelectorAll(".toast-box");
  var autoCloseToast;
  function closeToastBox() {
    toastBoxes.forEach(function(el) {
      el.classList.remove("show");
      clearTimeout(autoCloseToast);
    });
  }
  function toastbox(target, time) {
    var a = document.getElementById(target);
    closeToastBox();
    setTimeout(() => {
      a.classList.add("show");
    }, 100);
    if (time) {
      time = time + 100;
      autoCloseToast = setTimeout(() => {
        closeToastBox();
      }, time);
    }
  }
  toastCloseButton.forEach(function(el) {
    el.addEventListener("click", function(e) {
      e.preventDefault();
      closeToastBox();
    });
  });
  toastTaptoClose.forEach(function(el) {
    el.addEventListener("click", function(e) {
      closeToastBox();
    });
  });
  var appHeader = document.querySelector(".appHeader.scrolled");
  function animatedScroll() {
    var scrolled = window.scrollY;
    if (scrolled > 20) {
      appHeader.classList.add("is-active");
    } else {
      appHeader.classList.remove("is-active");
    }
  }
  if (document.body.contains(appHeader)) {
    animatedScroll();
    window.addEventListener("scroll", function() {
      animatedScroll();
    });
  }
  var OnlineText = "Connected to Internet";
  var OfflineText = "No Internet Connection";
  function onlineModeToast() {
    var check = document.getElementById("online-toast");
    if (document.body.contains(check)) {
      check.classList.add("show");
    } else {
      pageBody.appendChild(document.createElement("div")).id = "online-toast";
      var toast = document.getElementById("online-toast");
      toast.className = "toast-box bg-success toast-top tap-to-close";
      toast.innerHTML = "<div class='in'><div class='text'>" + OnlineText + "</div></div>";
      setTimeout(() => {
        toastbox("online-toast", 3e3);
      }, 500);
    }
  }
  function offlineModeToast() {
    var check = document.getElementById("offline-toast");
    if (document.body.contains(check)) {
      check.classList.add("show");
    } else {
      pageBody.appendChild(document.createElement("div")).id = "offline-toast";
      var toast = document.getElementById("offline-toast");
      toast.className = "toast-box bg-danger toast-top tap-to-close";
      toast.innerHTML = "<div class='in'><div class='text'>" + OfflineText + "</div></div>";
      setTimeout(() => {
        toastbox("offline-toast", 3e3);
      }, 500);
    }
  }
  function onlineMode() {
    var check = document.getElementById("offline-toast");
    if (document.body.contains(check)) {
      check.classList.remove("show");
    }
    onlineModeToast();
    var toast = document.getElementById("online-toast");
    toast.addEventListener("click", function() {
      this.classList.remove("show");
    });
    setTimeout(() => {
      toast.classList.remove("show");
    }, 3e3);
  }
  function offlineMode() {
    var check = document.getElementById("online-toast");
    if (document.body.contains(check)) {
      check.classList.remove("show");
    }
    offlineModeToast();
    var toast = document.getElementById("offline-toast");
    toast.addEventListener("click", function() {
      this.classList.remove("show");
    });
    setTimeout(() => {
      toast.classList.remove("show");
    }, 3e3);
  }
  window.addEventListener("online", onlineMode);
  window.addEventListener("offline", offlineMode);
  var uploadComponent = document.querySelectorAll(".custom-file-upload");
  uploadComponent.forEach(function(el) {
    var fileUploadParent = "#" + el.id;
    var fileInput = document.querySelector(fileUploadParent + ' input[type="file"]');
    var fileLabel = document.querySelector(fileUploadParent + " label");
    var fileLabelText = document.querySelector(fileUploadParent + " label span");
    var filelabelDefault = fileLabelText.innerHTML;
    fileInput.addEventListener("change", function(event) {
      var name = this.value.split("\\").pop();
      tmppath = URL.createObjectURL(event.target.files[0]);
      if (name) {
        fileLabel.classList.add("file-uploaded");
        fileLabel.style.backgroundImage = "url(" + tmppath + ")";
        fileLabelText.innerHTML = name;
      } else {
        fileLabel.classList.remove("file-uploaded");
        fileLabelText.innerHTML = filelabelDefault;
      }
    });
  });
  var multiListview = document.querySelectorAll(".listview .multi-level > a.item");
  multiListview.forEach(function(el) {
    el.addEventListener("click", function() {
      var parent = this.parentNode;
      var listview = parent.parentNode;
      var container = parent.querySelectorAll(".listview");
      var activated = listview.querySelectorAll(".multi-level.active");
      var activatedContainer = listview.querySelectorAll(".multi-level.active .listview");
      function openContainer() {
        container.forEach(function(e) {
          e.style.height = "auto";
          var currentheight = e.clientHeight + 10 + "px";
          e.style.height = "0px";
          setTimeout(() => {
            e.style.height = currentheight;
          }, 0);
        });
      }
      function closeContainer() {
        container.forEach(function(e) {
          e.style.height = "0px";
        });
      }
      if (parent.classList.contains("active")) {
        parent.classList.remove("active");
        closeContainer();
      } else {
        parent.classList.add("active");
        openContainer();
      }
      activated.forEach(function(element) {
        element.classList.remove("active");
        activatedContainer.forEach(function(e) {
          e.style.height = "0px";
        });
      });
    });
  });
  var checkDarkModeStatus = localStorage.getItem("MobilekitDarkMode");
  var switchDarkMode = document.querySelectorAll(".dark-mode-switch");
  var pageBodyActive = pageBody.classList.contains("dark-mode-active");
  if (Mobilekit.Dark_Mode.default) {
    pageBody.classList.add("dark-mode-active");
  }
  if (Mobilekit.Dark_Mode.night_mode.enable) {
    nightStart = Mobilekit.Dark_Mode.night_mode.start_time;
    nightEnd = Mobilekit.Dark_Mode.night_mode.end_time;
    currentDate = new Date();
    currentHour = currentDate.getHours();
    if (currentHour >= nightStart || currentHour < nightEnd) {
      pageBody.classList.add("dark-mode-active");
    }
  }
  var nightStart;
  var nightEnd;
  var currentDate;
  var currentHour;
  if (Mobilekit.Dark_Mode.auto_detect.enable) {
    if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) {
      pageBody.classList.add("dark-mode-active");
    }
  }
  function switchDarkModeCheck(value) {
    switchDarkMode.forEach(function(el) {
      el.checked = value;
    });
  }
  if (checkDarkModeStatus === 1 || checkDarkModeStatus === "1" || pageBody.classList.contains("dark-mode-active")) {
    switchDarkModeCheck(true);
    if (pageBodyActive) {
    } else {
      pageBody.classList.add("dark-mode-active");
    }
  } else {
    switchDarkModeCheck(false);
  }
  switchDarkMode.forEach(function(el) {
    el.addEventListener("click", function() {
      var darkmodeCheck = localStorage.getItem("MobilekitDarkMode");
      var bodyCheck = pageBody.classList.contains("dark-mode-active");
      if (darkmodeCheck === 1 || darkmodeCheck === "1" || bodyCheck) {
        pageBody.classList.remove("dark-mode-active");
        localStorage.setItem("MobilekitDarkMode", "0");
        switchDarkModeCheck(false);
      } else {
        pageBody.classList.add("dark-mode-active");
        switchDarkModeCheck(true);
        localStorage.setItem("MobilekitDarkMode", "1");
      }
    });
  });
  if (document.querySelector(".cookies-modal") === null) {
  } else {
    let CookiesBox = function(time) {
      if (CookiesStatus === "1" || CookiesStatus === 1) {
      } else {
        if (time) {
          setTimeout(() => {
            elCookies.classList.add("show");
          }, time);
        } else {
          elCookies.classList.add("show");
        }
      }
    };
    CookiesBox2 = CookiesBox;
    elCookies = document.getElementById("cookies-box");
    CookiesStatus = localStorage.getItem("MobilekitCookiesStatus");
    document.querySelectorAll(".accept-cookies").forEach(function(el) {
      el.addEventListener("click", function() {
        localStorage.setItem("MobilekitCookiesStatus", "1");
      });
    });
    document.querySelectorAll(".toggle-cookies").forEach(function(el) {
      el.addEventListener("click", function() {
        elCookies.classList.toggle("show");
      });
    });
  }
  var elCookies;
  var CookiesStatus;
  var CookiesBox2;
  function testMode() {
    var colorDanger = "color: #EC4433; font-weight:bold;";
    var colorSuccess = "color: #34C759; font-weight:bold;";
    console.clear();
    console.log("%cMobilekit (v" + Mobilekit.version + ")", "font-size: 1.3em; font-weight: bold; color: #FFF; background-color: #1E74FD; padding: 14px 70px; margin-bottom: 16px;");
    console.log("%c\u{1F680} TEST MODE ACTIVATED ..!", "font-size: 1em; font-weight: bold; margin: 4px 0;");
    function testModeMsg(value, msg) {
      if (value) {
        console.log("%c|%c " + msg + " : %cEnabled", "color: #444; font-size :1.2em; font-weight: bold;", "color: inherit", colorSuccess);
      } else if (value == false) {
        console.log("%c|%c " + msg + " : %cDisabled", "color: #444; font-size :1.2em; font-weight: bold;", "color: inherit", colorDanger);
      }
    }
    function testModeInfo(value, msg) {
      console.log("%c|%c " + msg + " : %c" + value, "color: #444; font-size :1.2em; font-weight: bold;", "color: inherit", "color:#1E74FD; font-weight: bold;");
    }
    function testModeSubtitle(msg) {
      console.log("%c # " + msg, "color: #FFF; background: #444; font-size: 1.2em; padding: 8px 16px; margin-top: 16px; border-radius: 12px 12px 0 0");
    }
    testModeSubtitle("THEME SETTINGS");
    testModeMsg(Mobilekit.PWA.enable, "PWA");
    testModeMsg(Mobilekit.Dark_Mode.default, "Set dark mode as default theme");
    testModeMsg(Mobilekit.Dark_Mode.night_mode.enable, "Night mode (between " + Mobilekit.Dark_Mode.night_mode.start_time + ":00 and " + Mobilekit.Dark_Mode.night_mode.end_time + ":00)");
    testModeMsg(Mobilekit.Dark_Mode.auto_detect.enable, "Auto detect dark mode");
    testModeMsg(Mobilekit.RTL.enable, "RTL");
    testModeMsg(Mobilekit.Test.enable, "Test mode");
    testModeMsg(Mobilekit.Test.alert, "Test mode alert");
    testModeSubtitle("PREVIEW INFOS");
    testModeInfo(window.screen.availWidth + " x " + window.screen.availHeight, "Resolution");
    if (iosDetection) {
      testModeInfo("iOS", "Device");
    } else if (androidDetection) {
      testModeInfo("Android", "Device");
    } else if (windowsPhoneDetection) {
      testModeInfo("Windows Phone", "Device");
    } else {
      testModeInfo("Not a Mobile Device", "Device");
    }
    testModeInfo(window.navigator.language, "Language");
    if (pageBody.classList.contains("dark-mode-active")) {
      testModeInfo("Dark Mode", "Current theme");
    } else {
      testModeInfo("Light Mode", "Current theme");
    }
    if (window.navigator.onLine) {
      testModeInfo("Online", "Internet connection");
    } else {
      testModeInfo("Offline", "Internet connection");
    }
  }
  function themeTesting() {
    var word = Mobilekit.Test.word;
    var value = "";
    window.addEventListener("keypress", function(e) {
      value = value + String.fromCharCode(e.keyCode).toLowerCase();
      if (value.length > word.length) {
        value = value.slice(1);
      }
      if (value == word || value === word) {
        value = "";
        if (Mobilekit.Test.alert) {
          var content = document.getElementById("appCapsule");
          content.appendChild(document.createElement("div")).className = "test-alert-wrapper";
          var alert = "<div id='alert-toast' class='toast-box toast-center tap-to-close'><div class='in'><div class='text'><h1 class='text-light mb-05'>\u{1F916}</h1><strong>" + Mobilekit.Test.alertMessage + "</strong></div></div></div>";
          var wrapper = document.querySelector(".test-alert-wrapper");
          wrapper.innerHTML = alert;
          toastbox("alert-toast");
          setTimeout(() => {
            this.document.getElementById("alert-toast").classList.remove("show");
          }, 4e3);
        }
        testMode();
      }
    });
  }
  if (Mobilekit.Test.enable) {
    themeTesting();
  }

  // app/javascript/application.js
  var import_progressbar_min = __toESM(require_progressbar_min());

  // app/javascript/mobilekit/plugins/splide/splide.min.js
  !function() {
    "use strict";
    var t = { d: function(n2, e2) {
      for (var i2 in e2)
        t.o(e2, i2) && !t.o(n2, i2) && Object.defineProperty(n2, i2, { enumerable: true, get: e2[i2] });
    }, o: function(t2, n2) {
      return Object.prototype.hasOwnProperty.call(t2, n2);
    }, r: function(t2) {
      "undefined" != typeof Symbol && Symbol.toStringTag && Object.defineProperty(t2, Symbol.toStringTag, { value: "Module" }), Object.defineProperty(t2, "__esModule", { value: true });
    } }, n = {};
    t.r(n), t.d(n, { CREATED: function() {
      return R;
    }, DESTROYED: function() {
      return X;
    }, IDLE: function() {
      return F;
    }, MOUNTED: function() {
      return B;
    }, MOVING: function() {
      return G;
    } });
    function e() {
      return (e = Object.assign || function(t2) {
        for (var n2 = 1; n2 < arguments.length; n2++) {
          var e2 = arguments[n2];
          for (var i2 in e2)
            Object.prototype.hasOwnProperty.call(e2, i2) && (t2[i2] = e2[i2]);
        }
        return t2;
      }).apply(this, arguments);
    }
    var i = Object.keys;
    function o(t2, n2) {
      i(t2).some(function(e2, i2) {
        return n2(t2[e2], e2, i2);
      });
    }
    function r(t2) {
      return i(t2).map(function(n2) {
        return t2[n2];
      });
    }
    function s(t2) {
      return "object" == typeof t2;
    }
    function a(t2, n2) {
      var i2 = e({}, t2);
      return o(n2, function(t3, n3) {
        s(t3) ? (s(i2[n3]) || (i2[n3] = {}), i2[n3] = a(i2[n3], t3)) : i2[n3] = t3;
      }), i2;
    }
    function u(t2) {
      return Array.isArray(t2) ? t2 : [t2];
    }
    function c(t2, n2, e2) {
      return Math.min(Math.max(t2, n2 > e2 ? e2 : n2), n2 > e2 ? n2 : e2);
    }
    function d(t2, n2) {
      var e2 = 0;
      return t2.replace(/%s/g, function() {
        return u(n2)[e2++];
      });
    }
    function f(t2) {
      var n2 = typeof t2;
      return "number" === n2 && t2 > 0 ? parseFloat(t2) + "px" : "string" === n2 ? t2 : "";
    }
    function l(t2) {
      return t2 < 10 ? "0" + t2 : t2;
    }
    function h(t2, n2) {
      if ("string" == typeof n2) {
        var e2 = m("div", {});
        E(e2, { position: "absolute", width: n2 }), w(t2, e2), n2 = e2.clientWidth, b(e2);
      }
      return +n2 || 0;
    }
    function p(t2, n2) {
      return t2 ? t2.querySelector(n2.split(" ")[0]) : null;
    }
    function g(t2, n2) {
      return v(t2, n2)[0];
    }
    function v(t2, n2) {
      return t2 ? r(t2.children).filter(function(t3) {
        return P(t3, n2.split(" ")[0]) || t3.tagName === n2;
      }) : [];
    }
    function m(t2, n2) {
      var e2 = document.createElement(t2);
      return o(n2, function(t3, n3) {
        return C(e2, n3, t3);
      }), e2;
    }
    function y(t2) {
      var n2 = m("div", {});
      return n2.innerHTML = t2, n2.firstChild;
    }
    function b(t2) {
      u(t2).forEach(function(t3) {
        if (t3) {
          var n2 = t3.parentElement;
          n2 && n2.removeChild(t3);
        }
      });
    }
    function w(t2, n2) {
      t2 && t2.appendChild(n2);
    }
    function x(t2, n2) {
      if (t2 && n2) {
        var e2 = n2.parentElement;
        e2 && e2.insertBefore(t2, n2);
      }
    }
    function E(t2, n2) {
      t2 && o(n2, function(n3, e2) {
        null !== n3 && (t2.style[e2] = n3);
      });
    }
    function _(t2, n2, e2) {
      t2 && u(n2).forEach(function(n3) {
        n3 && t2.classList[e2 ? "remove" : "add"](n3);
      });
    }
    function k(t2, n2) {
      _(t2, n2, false);
    }
    function S(t2, n2) {
      _(t2, n2, true);
    }
    function P(t2, n2) {
      return !!t2 && t2.classList.contains(n2);
    }
    function C(t2, n2, e2) {
      t2 && t2.setAttribute(n2, e2);
    }
    function z(t2, n2) {
      return t2 ? t2.getAttribute(n2) : "";
    }
    function I(t2, n2) {
      u(n2).forEach(function(n3) {
        u(t2).forEach(function(t3) {
          return t3 && t3.removeAttribute(n3);
        });
      });
    }
    function M(t2) {
      return t2.getBoundingClientRect();
    }
    var T = "slide", A = "loop", O = "fade", L = function(t2, n2) {
      var e2, i2;
      return { mount: function() {
        e2 = n2.Elements.list, t2.on("transitionend", function(t3) {
          t3.target === e2 && i2 && i2();
        }, e2);
      }, start: function(o2, r2, s2, a2, u2) {
        var c2 = t2.options, d2 = n2.Controller.edgeIndex, f2 = c2.speed;
        i2 = u2, t2.is(T) && (0 === s2 && r2 >= d2 || s2 >= d2 && 0 === r2) && (f2 = c2.rewindSpeed || f2), E(e2, { transition: "transform " + f2 + "ms " + c2.easing, transform: "translate(" + a2.x + "px," + a2.y + "px)" });
      } };
    }, W = function(t2, n2) {
      function e2(e3) {
        var i2 = t2.options;
        E(n2.Elements.slides[e3], { transition: "opacity " + i2.speed + "ms " + i2.easing });
      }
      return { mount: function() {
        e2(t2.index);
      }, start: function(t3, i2, o2, r2, s2) {
        var a2 = n2.Elements.track;
        E(a2, { height: f(a2.clientHeight) }), e2(i2), setTimeout(function() {
          s2(), E(a2, { height: "" });
        });
      } };
    };
    function H(t2) {
      console.error("[SPLIDE] " + t2);
    }
    function j(t2, n2) {
      if (!t2)
        throw new Error(n2);
    }
    var q = "splide", D = { active: "is-active", visible: "is-visible", loading: "is-loading" }, N = { type: "slide", rewind: false, speed: 400, rewindSpeed: 0, waitForTransition: true, width: 0, height: 0, fixedWidth: 0, fixedHeight: 0, heightRatio: 0, autoWidth: false, autoHeight: false, perPage: 1, perMove: 0, clones: 0, start: 0, focus: false, gap: 0, padding: 0, arrows: true, arrowPath: "", pagination: true, autoplay: false, interval: 5e3, pauseOnHover: true, pauseOnFocus: true, resetProgress: true, lazyLoad: false, preloadPages: 1, easing: "cubic-bezier(.42,.65,.27,.99)", keyboard: "global", drag: true, dragAngleThreshold: 30, swipeDistanceThreshold: 150, flickVelocityThreshold: 0.6, flickPower: 600, flickMaxPages: 1, direction: "ltr", cover: false, accessibility: true, slideFocus: true, isNavigation: false, trimSpace: true, updateOnMove: false, throttle: 100, destroy: false, breakpoints: false, classes: { root: q, slider: q + "__slider", track: q + "__track", list: q + "__list", slide: q + "__slide", container: q + "__slide__container", arrows: q + "__arrows", arrow: q + "__arrow", prev: q + "__arrow--prev", next: q + "__arrow--next", pagination: q + "__pagination", page: q + "__pagination__page", clone: q + "__slide--clone", progress: q + "__progress", bar: q + "__progress__bar", autoplay: q + "__autoplay", play: q + "__play", pause: q + "__pause", spinner: q + "__spinner", sr: q + "__sr" }, i18n: { prev: "Previous slide", next: "Next slide", first: "Go to first slide", last: "Go to last slide", slideX: "Go to slide %s", pageX: "Go to page %s", play: "Start autoplay", pause: "Pause autoplay" } }, R = 1, B = 2, F = 3, G = 4, X = 5;
    function V(t2, n2) {
      for (var e2 = 0; e2 < n2.length; e2++) {
        var i2 = n2[e2];
        i2.enumerable = i2.enumerable || false, i2.configurable = true, "value" in i2 && (i2.writable = true), Object.defineProperty(t2, i2.key, i2);
      }
    }
    var U = function() {
      function t2(t3, e3, i3) {
        var o2;
        void 0 === e3 && (e3 = {}), void 0 === i3 && (i3 = {}), this.root = t3 instanceof Element ? t3 : document.querySelector(t3), j(this.root, "An invalid element/selector was given."), this.Components = null, this.Event = function() {
          var t4 = [];
          function n2(t5) {
            t5.elm && t5.elm.removeEventListener(t5.event, t5.handler, t5.options);
          }
          return { on: function(n3, e4, i4, o3) {
            void 0 === i4 && (i4 = null), void 0 === o3 && (o3 = {}), n3.split(" ").forEach(function(n4) {
              i4 && i4.addEventListener(n4, e4, o3), t4.push({ event: n4, handler: e4, elm: i4, options: o3 });
            });
          }, off: function(e4, i4) {
            void 0 === i4 && (i4 = null), e4.split(" ").forEach(function(e5) {
              t4 = t4.filter(function(t5) {
                return !t5 || t5.event !== e5 || t5.elm !== i4 || (n2(t5), false);
              });
            });
          }, emit: function(n3) {
            for (var e4 = arguments.length, i4 = new Array(e4 > 1 ? e4 - 1 : 0), o3 = 1; o3 < e4; o3++)
              i4[o3 - 1] = arguments[o3];
            t4.forEach(function(t5) {
              t5.elm || t5.event.split(".")[0] !== n3 || t5.handler.apply(t5, i4);
            });
          }, destroy: function() {
            t4.forEach(n2), t4 = [];
          } };
        }(), this.State = (o2 = R, { set: function(t4) {
          o2 = t4;
        }, is: function(t4) {
          return t4 === o2;
        } }), this.STATES = n, this._o = a(N, e3), this._i = 0, this._c = i3, this._e = {}, this._t = null;
      }
      var e2, i2, s2, u2 = t2.prototype;
      return u2.mount = function(t3, n2) {
        var e3 = this;
        void 0 === t3 && (t3 = this._e), void 0 === n2 && (n2 = this._t), this.State.set(R), this._e = t3, this._t = n2, this.Components = function(t4, n3, e4) {
          var i4 = {};
          return o(n3, function(n4, e5) {
            i4[e5] = n4(t4, i4, e5.toLowerCase());
          }), e4 || (e4 = t4.is(O) ? W : L), i4.Transition = e4(t4, i4), i4;
        }(this, a(this._c, t3), n2);
        try {
          o(this.Components, function(t4, n3) {
            var i4 = t4.required;
            void 0 === i4 || i4 ? t4.mount && t4.mount() : delete e3.Components[n3];
          });
        } catch (t4) {
          return void H(t4.message);
        }
        var i3 = this.State;
        return i3.set(B), o(this.Components, function(t4) {
          t4.mounted && t4.mounted();
        }), this.emit("mounted"), i3.set(F), this.emit("ready"), E(this.root, { visibility: "visible" }), this.on("move drag", function() {
          return i3.set(G);
        }).on("moved dragged", function() {
          return i3.set(F);
        }), this;
      }, u2.sync = function(t3) {
        return this.sibling = t3, this;
      }, u2.on = function(t3, n2, e3, i3) {
        return void 0 === e3 && (e3 = null), void 0 === i3 && (i3 = {}), this.Event.on(t3, n2, e3, i3), this;
      }, u2.off = function(t3, n2) {
        return void 0 === n2 && (n2 = null), this.Event.off(t3, n2), this;
      }, u2.emit = function(t3) {
        for (var n2, e3 = arguments.length, i3 = new Array(e3 > 1 ? e3 - 1 : 0), o2 = 1; o2 < e3; o2++)
          i3[o2 - 1] = arguments[o2];
        return (n2 = this.Event).emit.apply(n2, [t3].concat(i3)), this;
      }, u2.go = function(t3, n2) {
        return void 0 === n2 && (n2 = this.options.waitForTransition), (this.State.is(F) || this.State.is(G) && !n2) && this.Components.Controller.go(t3, false), this;
      }, u2.is = function(t3) {
        return t3 === this._o.type;
      }, u2.add = function(t3, n2) {
        return void 0 === n2 && (n2 = -1), this.Components.Elements.add(t3, n2, this.refresh.bind(this)), this;
      }, u2.remove = function(t3) {
        return this.Components.Elements.remove(t3), this.refresh(), this;
      }, u2.refresh = function() {
        return this.emit("refresh:before").emit("refresh").emit("resize"), this;
      }, u2.destroy = function(t3) {
        var n2 = this;
        if (void 0 === t3 && (t3 = true), !this.State.is(R))
          return r(this.Components).reverse().forEach(function(n3) {
            n3.destroy && n3.destroy(t3);
          }), this.emit("destroy", t3), this.Event.destroy(), this.State.set(X), this;
        this.on("ready", function() {
          return n2.destroy(t3);
        });
      }, e2 = t2, (i2 = [{ key: "index", get: function() {
        return this._i;
      }, set: function(t3) {
        this._i = parseInt(t3);
      } }, { key: "length", get: function() {
        return this.Components.Elements.length;
      } }, { key: "options", get: function() {
        return this._o;
      }, set: function(t3) {
        var n2 = this.State.is(R);
        n2 || this.emit("update"), this._o = a(this._o, t3), n2 || this.emit("updated", this._o);
      } }, { key: "classes", get: function() {
        return this._o.classes;
      } }, { key: "i18n", get: function() {
        return this._o.i18n;
      } }]) && V(e2.prototype, i2), s2 && V(e2, s2), t2;
    }(), Y = function(t2) {
      var n2 = z(t2.root, "data-splide");
      if (n2)
        try {
          t2.options = JSON.parse(n2);
        } catch (t3) {
          H(t3.message);
        }
      return { mount: function() {
        t2.State.is(R) && (t2.index = t2.options.start);
      } };
    }, J = "rtl", K = "ttb", Q = "update.slide", Z = function(t2, n2) {
      var e2 = t2.root, i2 = t2.classes, s2 = [];
      if (!e2.id) {
        window.splide = window.splide || {};
        var a2 = window.splide.uid || 0;
        window.splide.uid = ++a2, e2.id = "splide" + l(a2);
      }
      var u2 = { mount: function() {
        var n3 = this;
        this.init(), t2.on("refresh", function() {
          n3.destroy(), n3.init();
        }).on("updated", function() {
          S(e2, c2()), k(e2, c2());
        });
      }, destroy: function() {
        s2.forEach(function(t3) {
          t3.destroy();
        }), s2 = [], S(e2, c2());
      }, init: function() {
        var t3 = this;
        !function() {
          u2.slider = g(e2, i2.slider), u2.track = p(e2, "." + i2.track), u2.list = g(u2.track, i2.list), j(u2.track && u2.list, "Track or list was not found."), u2.slides = v(u2.list, i2.slide);
          var t4 = d2(i2.arrows);
          u2.arrows = { prev: p(t4, "." + i2.prev), next: p(t4, "." + i2.next) };
          var n3 = d2(i2.autoplay);
          u2.bar = p(d2(i2.progress), "." + i2.bar), u2.play = p(n3, "." + i2.play), u2.pause = p(n3, "." + i2.pause), u2.track.id = u2.track.id || e2.id + "-track", u2.list.id = u2.list.id || e2.id + "-list";
        }(), k(e2, c2()), this.slides.forEach(function(n3, e3) {
          t3.register(n3, e3, -1);
        });
      }, register: function(n3, e3, i3) {
        var o2 = function(t3, n4, e4, i4) {
          var o3 = t3.options.updateOnMove, s3 = "ready.slide updated.slide resized.slide moved.slide" + (o3 ? " move.slide" : ""), a3 = { slide: i4, index: n4, realIndex: e4, container: g(i4, t3.classes.container), isClone: e4 > -1, mount: function() {
            var r2 = this;
            this.isClone || (i4.id = t3.root.id + "-slide" + l(n4 + 1)), t3.on(s3, function() {
              return r2.update();
            }).on(Q, c3).on("click", function() {
              return t3.emit("click", r2);
            }, i4), o3 && t3.on("move.slide", function(t4) {
              t4 === e4 && u3(true, false);
            }), E(i4, { display: "" }), this.styles = z(i4, "style") || "";
          }, destroy: function() {
            t3.off(s3).off(Q).off("click", i4), S(i4, r(D)), c3(), I(this.container, "style");
          }, update: function() {
            u3(this.isActive(), false), u3(this.isVisible(), true);
          }, isActive: function() {
            return t3.index === n4;
          }, isVisible: function() {
            var n5 = this.isActive();
            if (t3.is(O) || n5)
              return n5;
            var e5 = Math.ceil, o4 = M(t3.Components.Elements.track), r2 = M(i4);
            return t3.options.direction === K ? o4.top <= r2.top && r2.bottom <= e5(o4.bottom) : o4.left <= r2.left && r2.right <= e5(o4.right);
          }, isWithin: function(e5, i5) {
            var o4 = Math.abs(e5 - n4);
            return t3.is(T) || this.isClone || (o4 = Math.min(o4, t3.length - o4)), o4 < i5;
          } };
          function u3(n5, e5) {
            var o4 = e5 ? "visible" : "active", r2 = D[o4];
            n5 ? (k(i4, r2), t3.emit("" + o4, a3)) : P(i4, r2) && (S(i4, r2), t3.emit(e5 ? "hidden" : "inactive", a3));
          }
          function c3() {
            C(i4, "style", a3.styles);
          }
          return a3;
        }(t2, e3, i3, n3);
        o2.mount(), s2.push(o2);
      }, getSlide: function(t3) {
        return s2.filter(function(n3) {
          return n3.index === t3;
        })[0];
      }, getSlides: function(t3) {
        return t3 ? s2 : s2.filter(function(t4) {
          return !t4.isClone;
        });
      }, getSlidesByPage: function(e3) {
        var i3 = n2.Controller.toIndex(e3), o2 = t2.options, r2 = false !== o2.focus ? 1 : o2.perPage;
        return s2.filter(function(t3) {
          var n3 = t3.index;
          return i3 <= n3 && n3 < i3 + r2;
        });
      }, add: function(t3, n3, e3) {
        if ("string" == typeof t3 && (t3 = y(t3)), t3 instanceof Element) {
          var i3 = this.slides[n3];
          E(t3, { display: "none" }), i3 ? (x(t3, i3), this.slides.splice(n3, 0, t3)) : (w(this.list, t3), this.slides.push(t3)), function(t4, n4) {
            var e4 = t4.querySelectorAll("img"), i4 = e4.length;
            if (i4) {
              var r2 = 0;
              o(e4, function(t5) {
                t5.onload = t5.onerror = function() {
                  ++r2 === i4 && n4();
                };
              });
            } else
              n4();
          }(t3, function() {
            e3 && e3(t3);
          });
        }
      }, remove: function(t3) {
        b(this.slides.splice(t3, 1)[0]);
      }, each: function(t3) {
        s2.forEach(t3);
      }, get length() {
        return this.slides.length;
      }, get total() {
        return s2.length;
      } };
      function c2() {
        var n3 = i2.root, e3 = t2.options;
        return [n3 + "--" + e3.type, n3 + "--" + e3.direction, e3.drag ? n3 + "--draggable" : "", e3.isNavigation ? n3 + "--nav" : "", D.active];
      }
      function d2(t3) {
        return g(e2, t3) || g(u2.slider, t3);
      }
      return u2;
    }, $ = Math.floor, tt = function(t2, n2) {
      var e2, i2, o2 = { mount: function() {
        e2 = t2.options, i2 = t2.is(A), t2.on("move", function(n3) {
          t2.index = n3;
        }).on("updated refresh", function(n3) {
          e2 = n3 || e2, t2.index = c(t2.index, 0, o2.edgeIndex);
        });
      }, go: function(t3, e3) {
        var i3 = this.trim(this.parse(t3));
        n2.Track.go(i3, this.rewind(i3), e3);
      }, parse: function(n3) {
        var i3 = t2.index, r3 = String(n3).match(/([+\-<>]+)(\d+)?/), s2 = r3 ? r3[1] : "", a2 = r3 ? parseInt(r3[2]) : 0;
        switch (s2) {
          case "+":
            i3 += a2 || 1;
            break;
          case "-":
            i3 -= a2 || 1;
            break;
          case ">":
          case "<":
            i3 = function(t3, n4, i4) {
              if (t3 > -1)
                return o2.toIndex(t3);
              var r4 = e2.perMove, s3 = i4 ? -1 : 1;
              if (r4)
                return n4 + r4 * s3;
              return o2.toIndex(o2.toPage(n4) + s3);
            }(a2, i3, "<" === s2);
            break;
          default:
            i3 = parseInt(n3);
        }
        return i3;
      }, toIndex: function(n3) {
        if (r2())
          return n3;
        var i3 = t2.length, o3 = e2.perPage, s2 = n3 * o3;
        return i3 - o3 <= (s2 -= (this.pageLength * o3 - i3) * $(s2 / i3)) && s2 < i3 && (s2 = i3 - o3), s2;
      }, toPage: function(n3) {
        if (r2())
          return n3;
        var i3 = t2.length, o3 = e2.perPage;
        return $(i3 - o3 <= n3 && n3 < i3 ? (i3 - 1) / o3 : n3 / o3);
      }, trim: function(t3) {
        return i2 || (t3 = e2.rewind ? this.rewind(t3) : c(t3, 0, this.edgeIndex)), t3;
      }, rewind: function(t3) {
        var n3 = this.edgeIndex;
        if (i2) {
          for (; t3 > n3; )
            t3 -= n3 + 1;
          for (; t3 < 0; )
            t3 += n3 + 1;
        } else
          t3 > n3 ? t3 = 0 : t3 < 0 && (t3 = n3);
        return t3;
      }, isRtl: function() {
        return e2.direction === J;
      }, get pageLength() {
        var n3 = t2.length;
        return r2() ? n3 : Math.ceil(n3 / e2.perPage);
      }, get edgeIndex() {
        var n3 = t2.length;
        return n3 ? r2() || e2.isNavigation || i2 ? n3 - 1 : n3 - e2.perPage : 0;
      }, get prevIndex() {
        var n3 = t2.index - 1;
        return (i2 || e2.rewind) && (n3 = this.rewind(n3)), n3 > -1 ? n3 : -1;
      }, get nextIndex() {
        var n3 = t2.index + 1;
        return (i2 || e2.rewind) && (n3 = this.rewind(n3)), t2.index < n3 && n3 <= this.edgeIndex || 0 === n3 ? n3 : -1;
      } };
      function r2() {
        return false !== e2.focus;
      }
      return o2;
    }, nt = Math.abs, et = function(t2, n2) {
      var e2, i2, o2, r2 = t2.options.direction === K, s2 = t2.is(O), a2 = t2.options.direction === J, u2 = false, d2 = a2 ? 1 : -1, f2 = { sign: d2, mount: function() {
        i2 = n2.Elements, e2 = n2.Layout, o2 = i2.list;
      }, mounted: function() {
        var n3 = this;
        s2 || (this.jump(0), t2.on("mounted resize updated", function() {
          n3.jump(t2.index);
        }));
      }, go: function(e3, i3, o3) {
        var r3 = h2(e3), a3 = t2.index;
        t2.State.is(G) && u2 || (u2 = e3 !== i3, o3 || t2.emit("move", i3, a3, e3), Math.abs(r3 - this.position) >= 1 || s2 ? n2.Transition.start(e3, i3, a3, this.toCoord(r3), function() {
          l2(e3, i3, a3, o3);
        }) : e3 !== a3 && "move" === t2.options.trimSpace ? n2.Controller.go(e3 + e3 - a3, o3) : l2(e3, i3, a3, o3));
      }, jump: function(t3) {
        this.translate(h2(t3));
      }, translate: function(t3) {
        E(o2, { transform: "translate" + (r2 ? "Y" : "X") + "(" + t3 + "px)" });
      }, cancel: function() {
        t2.is(A) ? this.shift() : this.translate(this.position), E(o2, { transition: "" });
      }, shift: function() {
        var n3 = nt(this.position), e3 = nt(this.toPosition(0)), i3 = nt(this.toPosition(t2.length)), o3 = i3 - e3;
        n3 < e3 ? n3 += o3 : n3 > i3 && (n3 -= o3), this.translate(d2 * n3);
      }, trim: function(n3) {
        return !t2.options.trimSpace || t2.is(A) ? n3 : c(n3, d2 * (e2.totalSize() - e2.size - e2.gap), 0);
      }, toIndex: function(t3) {
        var n3 = this, e3 = 0, o3 = 1 / 0;
        return i2.getSlides(true).forEach(function(i3) {
          var r3 = i3.index, s3 = nt(n3.toPosition(r3) - t3);
          s3 < o3 && (o3 = s3, e3 = r3);
        }), e3;
      }, toCoord: function(t3) {
        return { x: r2 ? 0 : t3, y: r2 ? t3 : 0 };
      }, toPosition: function(t3) {
        var n3 = e2.totalSize(t3) - e2.slideSize(t3) - e2.gap;
        return d2 * (n3 + this.offset(t3));
      }, offset: function(n3) {
        var i3 = t2.options.focus, o3 = e2.slideSize(n3);
        return "center" === i3 ? -(e2.size - o3) / 2 : -(parseInt(i3) || 0) * (o3 + e2.gap);
      }, get position() {
        var t3 = r2 ? "top" : a2 ? "right" : "left";
        return M(o2)[t3] - (M(i2.track)[t3] - e2.padding[t3] * d2);
      } };
      function l2(n3, e3, i3, r3) {
        E(o2, { transition: "" }), u2 = false, s2 || f2.jump(e3), r3 || t2.emit("moved", e3, i3, n3);
      }
      function h2(t3) {
        return f2.trim(f2.toPosition(t3));
      }
      return f2;
    }, it = function(t2, n2) {
      var e2 = [], i2 = 0, o2 = n2.Elements, r2 = { mount: function() {
        var n3 = this;
        t2.is(A) && (s2(), t2.on("refresh:before", function() {
          n3.destroy();
        }).on("refresh", s2).on("resize", function() {
          i2 !== a2() && (n3.destroy(), t2.refresh());
        }));
      }, destroy: function() {
        b(e2), e2 = [];
      }, get clones() {
        return e2;
      }, get length() {
        return e2.length;
      } };
      function s2() {
        r2.destroy(), function(t3) {
          var n3 = o2.length, i3 = o2.register;
          if (n3) {
            for (var r3 = o2.slides; r3.length < t3; )
              r3 = r3.concat(r3);
            r3.slice(0, t3).forEach(function(t4, r4) {
              var s3 = u2(t4);
              w(o2.list, s3), e2.push(s3), i3(s3, r4 + n3, r4 % n3);
            }), r3.slice(-t3).forEach(function(o3, s3) {
              var a3 = u2(o3);
              x(a3, r3[0]), e2.push(a3), i3(a3, s3 - t3, (n3 + s3 - t3 % n3) % n3);
            });
          }
        }(i2 = a2());
      }
      function a2() {
        var n3 = t2.options;
        if (n3.clones)
          return n3.clones;
        var e3 = n3.autoWidth || n3.autoHeight ? o2.length : n3.perPage, i3 = n3.direction === K ? "Height" : "Width", r3 = h(t2.root, n3["fixed" + i3]);
        return r3 && (e3 = Math.ceil(o2.track["client" + i3] / r3)), e3 * (n3.drag ? n3.flickMaxPages + 1 : 1);
      }
      function u2(n3) {
        var e3 = n3.cloneNode(true);
        return k(e3, t2.classes.clone), I(e3, "id"), e3;
      }
      return r2;
    };
    function ot(t2, n2) {
      var e2;
      return function() {
        e2 || (e2 = setTimeout(function() {
          t2(), e2 = null;
        }, n2));
      };
    }
    var rt = function(t2, n2) {
      var e2, o2, r2 = n2.Elements, s2 = t2.options.direction === K, a2 = (e2 = { mount: function() {
        t2.on("resize load", ot(function() {
          t2.emit("resize");
        }, t2.options.throttle), window).on("resize", c2).on("updated refresh", u2), u2(), this.totalSize = s2 ? this.totalHeight : this.totalWidth, this.slideSize = s2 ? this.slideHeight : this.slideWidth;
      }, destroy: function() {
        I([r2.list, r2.track], "style");
      }, get size() {
        return s2 ? this.height : this.width;
      } }, o2 = s2 ? function(t3, n3) {
        var e3, i2, o3 = n3.Elements, r3 = t3.root;
        return { margin: "marginBottom", init: function() {
          this.resize();
        }, resize: function() {
          i2 = t3.options, e3 = o3.track, this.gap = h(r3, i2.gap);
          var n4 = i2.padding, s3 = h(r3, n4.top || n4), a3 = h(r3, n4.bottom || n4);
          this.padding = { top: s3, bottom: a3 }, E(e3, { paddingTop: f(s3), paddingBottom: f(a3) });
        }, totalHeight: function(n4) {
          void 0 === n4 && (n4 = t3.length - 1);
          var e4 = o3.getSlide(n4);
          return e4 ? M(e4.slide).bottom - M(o3.list).top + this.gap : 0;
        }, slideWidth: function() {
          return h(r3, i2.fixedWidth || this.width);
        }, slideHeight: function(t4) {
          if (i2.autoHeight) {
            var n4 = o3.getSlide(t4);
            return n4 ? n4.slide.offsetHeight : 0;
          }
          var e4 = i2.fixedHeight || (this.height + this.gap) / i2.perPage - this.gap;
          return h(r3, e4);
        }, get width() {
          return e3.clientWidth;
        }, get height() {
          var t4 = i2.height || this.width * i2.heightRatio;
          return j(t4, '"height" or "heightRatio" is missing.'), h(r3, t4) - this.padding.top - this.padding.bottom;
        } };
      }(t2, n2) : function(t3, n3) {
        var e3, i2 = n3.Elements, o3 = t3.root, r3 = t3.options;
        return { margin: "margin" + (r3.direction === J ? "Left" : "Right"), height: 0, init: function() {
          this.resize();
        }, resize: function() {
          r3 = t3.options, e3 = i2.track, this.gap = h(o3, r3.gap);
          var n4 = r3.padding, s3 = h(o3, n4.left || n4), a3 = h(o3, n4.right || n4);
          this.padding = { left: s3, right: a3 }, E(e3, { paddingLeft: f(s3), paddingRight: f(a3) });
        }, totalWidth: function(n4) {
          void 0 === n4 && (n4 = t3.length - 1);
          var e4 = i2.getSlide(n4), o4 = 0;
          if (e4) {
            var s3 = M(e4.slide), a3 = M(i2.list);
            o4 = r3.direction === J ? a3.right - s3.left : s3.right - a3.left, o4 += this.gap;
          }
          return o4;
        }, slideWidth: function(t4) {
          if (r3.autoWidth) {
            var n4 = i2.getSlide(t4);
            return n4 ? n4.slide.offsetWidth : 0;
          }
          var e4 = r3.fixedWidth || (this.width + this.gap) / r3.perPage - this.gap;
          return h(o3, e4);
        }, slideHeight: function() {
          var t4 = r3.height || r3.fixedHeight || this.width * r3.heightRatio;
          return h(o3, t4);
        }, get width() {
          return e3.clientWidth - this.padding.left - this.padding.right;
        } };
      }(t2, n2), i(o2).forEach(function(t3) {
        e2[t3] || Object.defineProperty(e2, t3, Object.getOwnPropertyDescriptor(o2, t3));
      }), e2);
      function u2() {
        a2.init(), E(t2.root, { maxWidth: f(t2.options.width) }), r2.each(function(t3) {
          t3.slide.style[a2.margin] = f(a2.gap);
        }), c2();
      }
      function c2() {
        var n3 = t2.options;
        a2.resize(), E(r2.track, { height: f(a2.height) });
        var e3 = n3.autoHeight ? null : f(a2.slideHeight());
        r2.each(function(t3) {
          E(t3.container, { height: e3 }), E(t3.slide, { width: n3.autoWidth ? null : f(a2.slideWidth(t3.index)), height: t3.container ? null : e3 });
        }), t2.emit("resized");
      }
      return a2;
    }, st = Math.abs, at = function(t2, n2) {
      var e2, i2, r2, s2, a2 = n2.Track, u2 = n2.Controller, d2 = t2.options.direction === K, f2 = d2 ? "y" : "x", l2 = { disabled: false, mount: function() {
        var e3 = this, i3 = n2.Elements, r3 = i3.track;
        t2.on("touchstart mousedown", h2, r3).on("touchmove mousemove", g2, r3, { passive: false }).on("touchend touchcancel mouseleave mouseup dragend", v2, r3).on("mounted refresh", function() {
          o(i3.list.querySelectorAll("img, a"), function(n3) {
            t2.off("dragstart", n3).on("dragstart", function(t3) {
              t3.preventDefault();
            }, n3, { passive: false });
          });
        }).on("mounted updated", function() {
          e3.disabled = !t2.options.drag;
        });
      } };
      function h2(t3) {
        l2.disabled || s2 || p2(t3);
      }
      function p2(t3) {
        e2 = a2.toCoord(a2.position), i2 = m2(t3, {}), r2 = i2;
      }
      function g2(n3) {
        if (i2)
          if (r2 = m2(n3, i2), s2) {
            if (n3.cancelable && n3.preventDefault(), !t2.is(O)) {
              var o2 = e2[f2] + r2.offset[f2];
              a2.translate(function(n4) {
                if (t2.is(T)) {
                  var e3 = a2.sign, i3 = e3 * a2.trim(a2.toPosition(0)), o3 = e3 * a2.trim(a2.toPosition(u2.edgeIndex));
                  (n4 *= e3) < i3 ? n4 = i3 - 7 * Math.log(i3 - n4) : n4 > o3 && (n4 = o3 + 7 * Math.log(n4 - o3)), n4 *= e3;
                }
                return n4;
              }(o2));
            }
          } else
            (function(n4) {
              var e3 = n4.offset;
              if (t2.State.is(G) && t2.options.waitForTransition)
                return false;
              var i3 = 180 * Math.atan(st(e3.y) / st(e3.x)) / Math.PI;
              d2 && (i3 = 90 - i3);
              return i3 < t2.options.dragAngleThreshold;
            })(r2) && (t2.emit("drag", i2), s2 = true, a2.cancel(), p2(n3));
      }
      function v2() {
        i2 = null, s2 && (t2.emit("dragged", r2), function(e3) {
          var i3 = e3.velocity[f2], o2 = st(i3);
          if (o2 > 0) {
            var r3 = t2.options, s3 = t2.index, d3 = i3 < 0 ? -1 : 1, l3 = s3;
            if (!t2.is(O)) {
              var h3 = a2.position;
              o2 > r3.flickVelocityThreshold && st(e3.offset[f2]) < r3.swipeDistanceThreshold && (h3 += d3 * Math.min(o2 * r3.flickPower, n2.Layout.size * (r3.flickMaxPages || 1))), l3 = a2.toIndex(h3);
            }
            l3 === s3 && o2 > 0.1 && (l3 = s3 + d3 * a2.sign), t2.is(T) && (l3 = c(l3, 0, u2.edgeIndex)), u2.go(l3, r3.isNavigation);
          }
        }(r2), s2 = false);
      }
      function m2(t3, n3) {
        var e3 = t3.timeStamp, i3 = t3.touches, o2 = i3 ? i3[0] : t3, r3 = o2.clientX, s3 = o2.clientY, a3 = n3.to || {}, u3 = a3.x, c2 = void 0 === u3 ? r3 : u3, d3 = a3.y, f3 = { x: r3 - c2, y: s3 - (void 0 === d3 ? s3 : d3) }, l3 = e3 - (n3.time || 0);
        return { to: { x: r3, y: s3 }, offset: f3, time: e3, velocity: { x: f3.x / l3, y: f3.y / l3 } };
      }
      return l2;
    }, ut = function(t2, n2) {
      var e2 = false;
      function i2(t3) {
        e2 && (t3.preventDefault(), t3.stopPropagation(), t3.stopImmediatePropagation());
      }
      return { required: t2.options.drag, mount: function() {
        t2.on("click", i2, n2.Elements.track, { capture: true }).on("drag", function() {
          e2 = true;
        }).on("dragged", function() {
          setTimeout(function() {
            e2 = false;
          });
        });
      } };
    }, ct = 1, dt = 2, ft = 3, lt = function(t2, n2, e2) {
      var i2, o2, r2, s2 = t2.classes, a2 = t2.root, u2 = n2.Elements;
      function c2() {
        var r3 = n2.Controller, s3 = r3.prevIndex, a3 = r3.nextIndex, u3 = t2.length > t2.options.perPage || t2.is(A);
        i2.disabled = s3 < 0 || !u3, o2.disabled = a3 < 0 || !u3, t2.emit(e2 + ":updated", i2, o2, s3, a3);
      }
      function d2(n3) {
        return y('<button class="' + s2.arrow + " " + (n3 ? s2.prev : s2.next) + '" type="button"><svg xmlns="http://www.w3.org/2000/svg"	viewBox="0 0 40 40"	width="40"	height="40"><path d="' + (t2.options.arrowPath || "m15.5 0.932-4.3 4.38 14.5 14.6-14.5 14.5 4.3 4.4 14.6-14.6 4.4-4.3-4.4-4.4-14.6-14.6z") + '" />');
      }
      return { required: t2.options.arrows, mount: function() {
        i2 = u2.arrows.prev, o2 = u2.arrows.next, i2 && o2 || !t2.options.arrows || (i2 = d2(true), o2 = d2(false), r2 = true, function() {
          var n3 = m("div", { class: s2.arrows });
          w(n3, i2), w(n3, o2);
          var e3 = u2.slider, r3 = "slider" === t2.options.arrows && e3 ? e3 : a2;
          x(n3, r3.firstElementChild);
        }()), i2 && o2 && t2.on("click", function() {
          t2.go("<");
        }, i2).on("click", function() {
          t2.go(">");
        }, o2).on("mounted move updated refresh", c2), this.arrows = { prev: i2, next: o2 };
      }, mounted: function() {
        t2.emit(e2 + ":mounted", i2, o2);
      }, destroy: function() {
        I([i2, o2], "disabled"), r2 && b(i2.parentElement);
      } };
    }, ht = "move.page", pt = "updated.page refresh.page", gt = function(t2, n2, e2) {
      var i2 = {}, o2 = n2.Elements, r2 = { mount: function() {
        var n3 = t2.options.pagination;
        if (n3) {
          i2 = function() {
            var n4 = t2.options, e4 = t2.classes, i3 = m("ul", { class: e4.pagination }), r3 = o2.getSlides(false).filter(function(t3) {
              return false !== n4.focus || t3.index % n4.perPage == 0;
            }).map(function(n5, r4) {
              var s3 = m("li", {}), a2 = m("button", { class: e4.page, type: "button" });
              return w(s3, a2), w(i3, s3), t2.on("click", function() {
                t2.go(">" + r4);
              }, a2), { li: s3, button: a2, page: r4, Slides: o2.getSlidesByPage(r4) };
            });
            return { list: i3, items: r3 };
          }();
          var e3 = o2.slider;
          w("slider" === n3 && e3 ? e3 : t2.root, i2.list), t2.on(ht, s2);
        }
        t2.off(pt).on(pt, function() {
          r2.destroy(), t2.options.pagination && (r2.mount(), r2.mounted());
        });
      }, mounted: function() {
        if (t2.options.pagination) {
          var n3 = t2.index;
          t2.emit(e2 + ":mounted", i2, this.getItem(n3)), s2(n3, -1);
        }
      }, destroy: function() {
        b(i2.list), i2.items && i2.items.forEach(function(n3) {
          t2.off("click", n3.button);
        }), t2.off(ht), i2 = {};
      }, getItem: function(t3) {
        return i2.items[n2.Controller.toPage(t3)];
      }, get data() {
        return i2;
      } };
      function s2(n3, o3) {
        var s3 = r2.getItem(o3), a2 = r2.getItem(n3), u2 = D.active;
        s3 && S(s3.button, u2), a2 && k(a2.button, u2), t2.emit(e2 + ":updated", i2, s3, a2);
      }
      return r2;
    }, vt = "data-splide-lazy", mt = "data-splide-lazy-srcset", yt = "aria-current", bt = "aria-controls", wt = "aria-label", xt = "aria-hidden", Et = "tabindex", _t = { ltr: { ArrowLeft: "<", ArrowRight: ">", Left: "<", Right: ">" }, rtl: { ArrowLeft: ">", ArrowRight: "<", Left: ">", Right: "<" }, ttb: { ArrowUp: "<", ArrowDown: ">", Up: "<", Down: ">" } }, kt = function(t2, n2) {
      var e2 = t2.i18n, i2 = n2.Elements, o2 = [xt, Et, bt, wt, yt, "role"];
      function r2(n3, e3) {
        C(n3, xt, !e3), t2.options.slideFocus && C(n3, Et, e3 ? 0 : -1);
      }
      function s2(t3, n3) {
        var e3 = i2.track.id;
        C(t3, bt, e3), C(n3, bt, e3);
      }
      function a2(n3, i3, o3, r3) {
        var s3 = t2.index, a3 = o3 > -1 && s3 < o3 ? e2.last : e2.prev, u3 = r3 > -1 && s3 > r3 ? e2.first : e2.next;
        C(n3, wt, a3), C(i3, wt, u3);
      }
      function u2(n3, i3) {
        i3 && C(i3.button, yt, true), n3.items.forEach(function(n4) {
          var i4 = t2.options, o3 = d(false === i4.focus && i4.perPage > 1 ? e2.pageX : e2.slideX, n4.page + 1), r3 = n4.button, s3 = n4.Slides.map(function(t3) {
            return t3.slide.id;
          });
          C(r3, bt, s3.join(" ")), C(r3, wt, o3);
        });
      }
      function c2(t3, n3, e3) {
        n3 && I(n3.button, yt), e3 && C(e3.button, yt, true);
      }
      function f2(t3) {
        i2.each(function(n3) {
          var i3 = n3.slide, o3 = n3.realIndex;
          h2(i3) || C(i3, "role", "button");
          var r3 = o3 > -1 ? o3 : n3.index, s3 = d(e2.slideX, r3 + 1), a3 = t3.Components.Elements.getSlide(r3);
          C(i3, wt, s3), a3 && C(i3, bt, a3.slide.id);
        });
      }
      function l2(t3, n3) {
        var e3 = t3.slide;
        n3 ? C(e3, yt, true) : I(e3, yt);
      }
      function h2(t3) {
        return "BUTTON" === t3.tagName;
      }
      return { required: t2.options.accessibility, mount: function() {
        t2.on("visible", function(t3) {
          r2(t3.slide, true);
        }).on("hidden", function(t3) {
          r2(t3.slide, false);
        }).on("arrows:mounted", s2).on("arrows:updated", a2).on("pagination:mounted", u2).on("pagination:updated", c2).on("refresh", function() {
          I(n2.Clones.clones, o2);
        }), t2.options.isNavigation && t2.on("navigation:mounted navigation:updated", f2).on("active", function(t3) {
          l2(t3, true);
        }).on("inactive", function(t3) {
          l2(t3, false);
        }), ["play", "pause"].forEach(function(t3) {
          var n3 = i2[t3];
          n3 && (h2(n3) || C(n3, "role", "button"), C(n3, bt, i2.track.id), C(n3, wt, e2[t3]));
        });
      }, destroy: function() {
        var t3 = n2.Arrows, e3 = t3 ? t3.arrows : {};
        I(i2.slides.concat([e3.prev, e3.next, i2.play, i2.pause]), o2);
      } };
    }, St = "move.sync", Pt = "mouseup touchend", Ct = [" ", "Enter", "Spacebar"], zt = { Options: Y, Breakpoints: function(t2) {
      var n2, e2, i2 = t2.options.breakpoints, o2 = ot(s2, 50), r2 = [];
      function s2() {
        var o3, s3 = (o3 = r2.filter(function(t3) {
          return t3.mql.matches;
        })[0]) ? o3.point : -1;
        if (s3 !== e2) {
          e2 = s3;
          var a2 = t2.State, u2 = i2[s3] || n2, c2 = u2.destroy;
          c2 ? (t2.options = n2, t2.destroy("completely" === c2)) : (a2.is(X) && t2.mount(), t2.options = u2);
        }
      }
      return { required: i2 && matchMedia, mount: function() {
        r2 = Object.keys(i2).sort(function(t3, n3) {
          return +t3 - +n3;
        }).map(function(t3) {
          return { point: t3, mql: matchMedia("(max-width:" + t3 + "px)") };
        }), this.destroy(true), addEventListener("resize", o2), n2 = t2.options, s2();
      }, destroy: function(t3) {
        t3 && removeEventListener("resize", o2);
      } };
    }, Controller: tt, Elements: Z, Track: et, Clones: it, Layout: rt, Drag: at, Click: ut, Autoplay: function(t2, n2, e2) {
      var i2, o2 = [], r2 = n2.Elements, s2 = { required: t2.options.autoplay, mount: function() {
        var n3 = t2.options;
        r2.slides.length > n3.perPage && (i2 = function(t3, n4, e3) {
          var i3, o3, r3, s3 = window.requestAnimationFrame, a3 = true, u2 = function u3(c2) {
            a3 || (i3 || (i3 = c2, r3 && r3 < 1 && (i3 -= r3 * n4)), r3 = (o3 = c2 - i3) / n4, o3 >= n4 && (i3 = 0, r3 = 1, t3()), e3 && e3(r3), s3(u3));
          };
          return { pause: function() {
            a3 = true, i3 = 0;
          }, play: function(t4) {
            i3 = 0, t4 && (r3 = 0), a3 && (a3 = false, s3(u2));
          } };
        }(function() {
          t2.go(">");
        }, n3.interval, function(n4) {
          t2.emit(e2 + ":playing", n4), r2.bar && E(r2.bar, { width: 100 * n4 + "%" });
        }), function() {
          var n4 = t2.options, e3 = t2.sibling, i3 = [t2.root, e3 ? e3.root : null];
          n4.pauseOnHover && (a2(i3, "mouseleave", ct, true), a2(i3, "mouseenter", ct, false));
          n4.pauseOnFocus && (a2(i3, "focusout", dt, true), a2(i3, "focusin", dt, false));
          r2.play && t2.on("click", function() {
            s2.play(dt), s2.play(ft);
          }, r2.play);
          r2.pause && a2([r2.pause], "click", ft, false);
          t2.on("move refresh", function() {
            s2.play();
          }).on("destroy", function() {
            s2.pause();
          });
        }(), this.play());
      }, play: function(n3) {
        void 0 === n3 && (n3 = 0), (o2 = o2.filter(function(t3) {
          return t3 !== n3;
        })).length || (t2.emit(e2 + ":play"), i2.play(t2.options.resetProgress));
      }, pause: function(n3) {
        void 0 === n3 && (n3 = 0), i2.pause(), -1 === o2.indexOf(n3) && o2.push(n3), 1 === o2.length && t2.emit(e2 + ":pause");
      } };
      function a2(n3, e3, i3, o3) {
        n3.forEach(function(n4) {
          t2.on(e3, function() {
            s2[o3 ? "play" : "pause"](i3);
          }, n4);
        });
      }
      return s2;
    }, Cover: function(t2, n2) {
      function e2(t3) {
        n2.Elements.each(function(n3) {
          var e3 = g(n3.slide, "IMG") || g(n3.container, "IMG");
          e3 && e3.src && i2(e3, t3);
        });
      }
      function i2(t3, n3) {
        E(t3.parentElement, { background: n3 ? "" : 'center/cover no-repeat url("' + t3.src + '")' }), E(t3, { display: n3 ? "" : "none" });
      }
      return { required: t2.options.cover, mount: function() {
        t2.on("lazyload:loaded", function(t3) {
          i2(t3, false);
        }), t2.on("mounted updated refresh", function() {
          return e2(false);
        });
      }, destroy: function() {
        e2(true);
      } };
    }, Arrows: lt, Pagination: gt, LazyLoad: function(t2, n2, e2) {
      var i2, r2, s2 = t2.options, a2 = "sequential" === s2.lazyLoad;
      function u2() {
        r2 = [], i2 = 0;
      }
      function c2(n3) {
        n3 = isNaN(n3) ? t2.index : n3, (r2 = r2.filter(function(t3) {
          return !t3.Slide.isWithin(n3, s2.perPage * (s2.preloadPages + 1)) || (d2(t3.img, t3.Slide), false);
        }))[0] || t2.off("moved." + e2);
      }
      function d2(n3, e3) {
        k(e3.slide, D.loading);
        var i3 = m("span", { class: t2.classes.spinner });
        w(n3.parentElement, i3), n3.onload = function() {
          l2(n3, i3, e3, false);
        }, n3.onerror = function() {
          l2(n3, i3, e3, true);
        }, C(n3, "srcset", z(n3, mt) || ""), C(n3, "src", z(n3, vt) || "");
      }
      function f2() {
        if (i2 < r2.length) {
          var t3 = r2[i2];
          d2(t3.img, t3.Slide);
        }
        i2++;
      }
      function l2(n3, i3, o2, r3) {
        S(o2.slide, D.loading), r3 || (b(i3), E(n3, { display: "" }), t2.emit(e2 + ":loaded", n3).emit("resize")), a2 && f2();
      }
      return { required: s2.lazyLoad, mount: function() {
        t2.on("mounted refresh", function() {
          u2(), n2.Elements.each(function(t3) {
            o(t3.slide.querySelectorAll("[data-splide-lazy], [" + mt + "]"), function(n3) {
              n3.src || n3.srcset || (r2.push({ img: n3, Slide: t3 }), E(n3, { display: "none" }));
            });
          }), a2 && f2();
        }), a2 || t2.on("mounted refresh moved." + e2, c2);
      }, destroy: u2 };
    }, Keyboard: function(t2) {
      var n2;
      return { mount: function() {
        t2.on("mounted updated", function() {
          var e2 = t2.options, i2 = t2.root, o2 = _t[e2.direction], r2 = e2.keyboard;
          n2 && (t2.off("keydown", n2), I(i2, Et)), r2 && ("focused" === r2 ? (n2 = i2, C(i2, Et, 0)) : n2 = document, t2.on("keydown", function(n3) {
            o2[n3.key] && t2.go(o2[n3.key]);
          }, n2));
        });
      } };
    }, Sync: function(t2) {
      var n2 = t2.sibling, e2 = n2 && n2.options.isNavigation;
      function i2() {
        t2.on(St, function(t3, e3, i3) {
          n2.off(St).go(n2.is(A) ? i3 : t3, false), o2();
        });
      }
      function o2() {
        n2.on(St, function(n3, e3, o3) {
          t2.off(St).go(t2.is(A) ? o3 : n3, false), i2();
        });
      }
      function r2() {
        n2.Components.Elements.each(function(n3) {
          var e3 = n3.slide, i3 = n3.index;
          t2.off(Pt, e3).on(Pt, function(t3) {
            t3.button && 0 !== t3.button || s2(i3);
          }, e3), t2.off("keyup", e3).on("keyup", function(t3) {
            Ct.indexOf(t3.key) > -1 && (t3.preventDefault(), s2(i3));
          }, e3, { passive: false });
        });
      }
      function s2(e3) {
        t2.State.is(F) && n2.go(e3);
      }
      return { required: !!n2, mount: function() {
        i2(), o2(), e2 && (r2(), t2.on("refresh", function() {
          setTimeout(function() {
            r2(), n2.emit("navigation:updated", t2);
          });
        }));
      }, mounted: function() {
        e2 && n2.emit("navigation:mounted", t2);
      } };
    }, A11y: kt };
    var It = function(t2) {
      var n2, e2;
      function i2(n3, e3) {
        return t2.call(this, n3, e3, zt) || this;
      }
      return e2 = t2, (n2 = i2).prototype = Object.create(e2.prototype), n2.prototype.constructor = n2, n2.__proto__ = e2, i2;
    }(U);
    window.Splide = It;
  }();
})();
/*!
  * Bootstrap v5.1.3 (https://getbootstrap.com/)
  * Copyright 2011-2021 The Bootstrap Authors (https://github.com/twbs/bootstrap/graphs/contributors)
  * Licensed under MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)
  */
/*!
  * Bootstrap v5.3.3 (https://getbootstrap.com/)
  * Copyright 2011-2024 The Bootstrap Authors (https://github.com/twbs/bootstrap/graphs/contributors)
  * Licensed under MIT (https://github.com/twbs/bootstrap/blob/main/LICENSE)
  */
/*!
 * Splide.js
 * Version  : 2.4.20
 * License  : MIT
 * Copyright: 2020 Naotoshi Fujita
 */
//# sourceMappingURL=/assets/application.js.map
