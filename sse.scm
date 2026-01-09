(module sse
  (make-sse-manager
   sse-manager-mutex
   sse-manager-clients
   sse-manager-clients-set!
   sse-manager-register!
   sse-manager-unregister!
   sse-manager-broadcast!
   sse-manager-handler
   send-sse
   sse-comment
   MAX-QUEUE-SIZE
   MAX-CLIENT-LIFETIME
   PING-INTERVAL)

(import scheme
        (chicken base)
        (chicken string)
        (chicken io)
        (chicken condition)
        (chicken time)
        srfi-1
        srfi-18
        spiffy
        intarweb)

;; Configuration constants
(define MAX-QUEUE-SIZE 100)        ; Max events in queue per client
(define MAX-CLIENT-LIFETIME 3600)  ; Max connection time (1 hour)
(define PING-INTERVAL 10)          ; Ping every 10 seconds (faster detection)

(define-record sse-manager mutex clients)

(define (make-client)
  (vector (make-mutex 'client) '()))

(define (client-mx c) (vector-ref c 0))
(define (client-q  c) (vector-ref c 1))
(define (client-q-set! c v) (vector-set! c 1 v))

(define (sse-manager-register! mgr)
  "Register a new SSE client"
  (let ((c (make-client)))
    (mutex-lock! (sse-manager-mutex mgr))
    (sse-manager-clients-set! mgr (cons c (sse-manager-clients mgr)))
    (mutex-unlock! (sse-manager-mutex mgr))
    (print "SSE client registered. Total: " (length (sse-manager-clients mgr)))
    c))

(define (sse-manager-unregister! mgr c)
  "Unregister an SSE client"
  (mutex-lock! (sse-manager-mutex mgr))
  (sse-manager-clients-set! mgr
    (filter (lambda (x) (not (eq? x c))) (sse-manager-clients mgr)))
  (mutex-unlock! (sse-manager-mutex mgr))
  (print "SSE client unregistered. Total: " (length (sse-manager-clients mgr))))

(define (enqueue! c chunk)
  "Add chunk to client queue with size limit to prevent memory leaks"
  (mutex-lock! (client-mx c))
  (let ((q (client-q c)))
    (if (>= (length q) MAX-QUEUE-SIZE)
        ;; Queue full - drop oldest event
        (begin
          (client-q-set! c (append (cdr q) (list chunk)))
          (print "WARNING: Client queue full, dropping oldest event"))
        ;; Queue has space - append normally
        (client-q-set! c (append q (list chunk)))))
  (mutex-unlock! (client-mx c)))

(define (try-dequeue! c)
  (mutex-lock! (client-mx c))
  (let ((q (client-q c)))
    (if (pair? q)
        (let ((m (car q)))
          (client-q-set! c (cdr q))
          (mutex-unlock! (client-mx c))
          m)
        (begin
          (mutex-unlock! (client-mx c))
          #f))))

(define (sse-manager-broadcast! mgr chunk)
  "Broadcast message to all connected SSE clients"
  (mutex-lock! (sse-manager-mutex mgr))
  (let ((cs (sse-manager-clients mgr)))
    (mutex-unlock! (sse-manager-mutex mgr))
    (for-each (lambda (c) (enqueue! c chunk)) cs)))

(define (sse-write-raw! out s)
  "Write to SSE stream, return #f on error (closed connection)"
  (handle-exceptions _ #f
    (begin
      (display s out)
      (flush-output out)
      #t)))

(define (sse-comment msg)
  (string-append ": " msg "\n\n"))

(define (send-sse body)
  "Send SSE response"
  (handle-exceptions exn
    (begin
      (print "SSE send error")
      #f)
    (with-headers
      '((content-type text/event-stream)
        (cache-control no-cache)
        (connection close))
      (lambda ()
        (write-logged-response)
        (let ((out (response-port (current-response))))
          (display body out)
          (flush-output out))))))

(define (sse-manager-handler mgr)
  "Create a handler for permanent SSE connections
   - Pings every PING-INTERVAL seconds to detect closed connections
   - Disconnects after MAX-CLIENT-LIFETIME
   - Queue limited to MAX-QUEUE-SIZE"
  (lambda ()
    (print "SSE connection opened")
    (with-headers
      '((content-type text/event-stream)
        (cache-control no-cache)
        (connection keep-alive))
      (lambda ()
        (write-logged-response)
        (let* ((out (response-port (current-response)))
               (c (sse-manager-register! mgr)))

          (sse-write-raw! out (sse-comment "connected"))

          (let loop ((last-ping (current-seconds)) (start-time (current-seconds)))
            (let ((chunk (try-dequeue! c))
                  (now (current-seconds)))

              ;; Disconnect after MAX-CLIENT-LIFETIME
              (if (>= (- now start-time) MAX-CLIENT-LIFETIME)
                  (begin
                    (print "SSE: Client lifetime exceeded, disconnecting")
                    (sse-manager-unregister! mgr c))

                  (cond
                    ;; Got a chunk to send
                    (chunk
                     (if (sse-write-raw! out chunk)
                         (loop now start-time)  ; Update last-ping when we write
                         (begin
                           (print "SSE: Write failed, client disconnected")
                           (sse-manager-unregister! mgr c))))

                    ;; No chunk - check if we need to ping
                    (else
                     (if (>= (- now last-ping) PING-INTERVAL)
                         ;; Time to ping
                         (if (sse-write-raw! out (sse-comment "ping"))
                             (begin
                               (thread-sleep! 0.05)
                               (loop now start-time))
                             (begin
                               (print "SSE: Ping failed, client disconnected")
                               (sse-manager-unregister! mgr c)))
                         ;; Not time to ping yet
                         (begin
                           (thread-sleep! 0.05)
                           (loop last-ping start-time)))))))))))))

) ; end module
