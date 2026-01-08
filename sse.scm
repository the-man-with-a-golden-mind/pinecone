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
   sse-comment)

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

;; [cały kod bez zmian]
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
  (mutex-lock! (client-mx c))
  (client-q-set! c (append (client-q c) (list chunk)))
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
  "Create a handler for permanent SSE connections"
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

          (let loop ((last-ping (current-seconds)))
            (let ((chunk (try-dequeue! c)))
              (cond
                (chunk
                 (if (sse-write-raw! out chunk)
                     (loop last-ping)
                     (sse-manager-unregister! mgr c)))
                (else
                 (let ((now (current-seconds)))
                   (if (>= (- now last-ping) 15)
                       (if (sse-write-raw! out (sse-comment "ping"))
                           (begin
                             (thread-sleep! 0.05)
                             (loop now))
                           (sse-manager-unregister! mgr c))
                       (begin
                         (thread-sleep! 0.05)
                         (loop last-ping)))))))))))))

) ; end module
