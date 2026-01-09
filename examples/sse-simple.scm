#!/usr/bin/env csi -s

(import scheme
        (chicken base)
        (chicken time)
        (chicken time posix)
        (chicken string)
        (chicken format)
        (chicken gc)
        srfi-18
        spiffy
        intarweb
        pinecone)

(import core sse datastar middleware app)

;; Create application (no static files)
(define my-app (create-app port: 8080 root-path: "./nonexistent"))

;; Format current timestamp - simple version with string-append
(define (current-timestamp)
  (let* ((tm (seconds->local-time (current-seconds)))
         (year (+ 1900 (vector-ref tm 5)))
         (month (+ 1 (vector-ref tm 4)))
         (day (vector-ref tm 3))
         (hour (vector-ref tm 2))
         (minute (vector-ref tm 1))
         (second (vector-ref tm 0)))
    (string-append
      (number->string year) "-"
      (if (< month 10) "0" "") (number->string month) "-"
      (if (< day 10) "0" "") (number->string day) " "
      (if (< hour 10) "0" "") (number->string hour) ":"
      (if (< minute 10) "0" "") (number->string minute) ":"
      (if (< second 10) "0" "") (number->string second))))

;; Broadcast thread that sends timestamps every second
(define (start-broadcast-thread! app)
  (thread-start!
    (make-thread
      (lambda ()
        (let loop ((counter 0))
          (let* ((ts (current-timestamp))
                 (mgr (app-sse-manager app))
                 (ds-update (ds-signals
                              (string-append
                                "{\"timestamp\":\""
                                ts
                                "\",\"counter\":"
                                (number->string counter)
                                ",\"connected\":true}"))))

            ;; Broadcast to all connected clients
            (sse-manager-broadcast! mgr ds-update)

            (print "Broadcast #" counter " to " (length (sse-manager-clients mgr)) " clients")

            (thread-sleep! 1)
            (loop (+ counter 1)))))
      'broadcast-thread)))

;; Main page with Datastar
(define (index-handler params)
  (send-response
    status: 'ok
    headers: '((content-type text/html))
    body: "<!DOCTYPE html>
<html>
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>SSE + Datastar - Timestamp Example</title>
  <script type=\"module\" src=\"https://cdn.jsdelivr.net/gh/starfederation/datastar@1.0.0-RC.7/bundles/datastar.js\"></script>
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      max-width: 800px;
      margin: 50px auto;
      padding: 20px;
      background: #f5f5f5;
    }
    .container {
      background: white;
      border-radius: 10px;
      padding: 30px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    h1 {
      color: #333;
      margin-bottom: 10px;
    }
    .subtitle {
      color: #666;
      margin-bottom: 30px;
    }
    .timestamp-display {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      border-radius: 8px;
      text-align: center;
      font-size: 2em;
      font-weight: bold;
      font-family: 'Courier New', monospace;
      box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
      margin-bottom: 20px;
    }
    .info {
      background: #e3f2fd;
      border-left: 4px solid #2196F3;
      padding: 15px;
      border-radius: 4px;
      margin-top: 20px;
    }
    .status {
      margin-top: 20px;
      padding: 10px;
      background: #f0f0f0;
      border-radius: 4px;
      font-size: 0.9em;
    }
    .status.connected {
      background: #c8e6c9;
      color: #2e7d32;
    }
    .counter {
      color: #888;
      font-size: 0.8em;
      margin-top: 10px;
    }
  </style>
</head>
<body>
  <div class=\"container\">
    <h1>🕐 SSE + Datastar Timestamp</h1>
    <p class=\"subtitle\">Real-time updates every second via Server-Sent Events</p>

    <div
      data-signals=\"{timestamp: 'Connecting...', counter: 0, connected: false}\"
      data-init=\"@get('/stream')\">

      <button data-on:click=\"@get('/stream')\">Reconnect</button>

      <div class=\"timestamp-display\" data-text=\"$timestamp\"></div>

      <div class=\"status\" data-class=\"{connected: $connected}\">
        <span data-text=\"$connected ? '🟢 Connected' : '🔴 Disconnected'\"></span>
      </div>

      <div class=\"counter\" data-text=\"'Updates received: ' + $counter\"></div>

      <div class=\"info\">
        <strong>How it works:</strong>
        <ul>
          <li>Server sends timestamp every second via SSE</li>
          <li>Datastar automatically receives and updates the view</li>
          <li>SSE Manager handles multiple clients efficiently</li>
        </ul>
      </div>
    </div>
  </div>
</body>
</html>"))

;; SSE stream handler using sse-manager
(define (stream-handler params)
  (let ((mgr (app-sse-manager my-app)))
    ((sse-manager-handler mgr))))

;; Add routes
(app-add-route! my-app 'GET '("sse") index-handler)
(app-add-route! my-app 'GET '("stream") stream-handler)

;; Start broadcast thread
(start-broadcast-thread! my-app)

;; Disable GC reports
(set-gc-report! #f)

;; Start server
(print "")
(print "========================================")
(print "🚀 Starting Timestamp SSE Example")
(print "========================================")
(print "Open http://localhost:8080/sse in your browser")
(print "Press Ctrl+C to stop")
(print "========================================")
(print "")

(app-start! my-app)
