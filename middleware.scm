(module middleware
  (make-middleware
   middleware?
   middleware-handler
   middleware-name
   chain-middlewares
   ;; Built-in middlewares
   logging-middleware
   cors-middleware
   cookie-parser-middleware
   session-middleware
   ;; Cookie functions
   get-cookie
   set-cookie!
   get-response-cookies
   clear-response-cookies!
   ;; Session functions
   get-session
   create-session!
   get-or-create-session!
   session-get
   session-set!
   session-delete!
   destroy-session!)

(import scheme
        (chicken base)
        (chicken time)
        (chicken time.posix)
        (chicken random)
        (chicken condition)
        (chicken string)
        srfi-1
        srfi-13
        srfi-69  ; hash tables for sessions
        spiffy
        intarweb
        uri-common
        core)

;; ============================================================================
;; Middleware Record
;; ============================================================================
(define-record middleware handler name)

;; ============================================================================
;; Middleware Chaining
;; ============================================================================
(define (chain-middlewares middlewares final-handler)
  "Chain multiple middlewares together"
  (if (null? middlewares)
      final-handler
      (let ((mw (car middlewares))
            (rest (cdr middlewares)))
        (lambda (params)
          ((middleware-handler mw)
           params
           (chain-middlewares rest final-handler))))))

;; ============================================================================
;; Cookie Utilities
;; ============================================================================
(define (parse-cookies cookie-header)
  "Parse Cookie header into alist"
  (if (not cookie-header)
      '()
      (map (lambda (cookie)
             (let ((parts (string-split cookie "=")))
               (if (= (length parts) 2)
                   (cons (string-trim-both (car parts))
                         (string-trim-both (cadr parts)))
                   (cons (string-trim-both (car parts)) ""))))
           (string-split cookie-header ";"))))

(define (get-cookie name)
  "Get cookie value from current request"
  (let* ((req (current-request))
         (headers (request-headers req))
         (cookie-header (header-value 'cookie headers #f)))
    (if cookie-header
        (let ((cookies (parse-cookies cookie-header)))
          (alist-ref name cookies equal?))
        #f)))

(define (set-cookie! name value #!key
                     (max-age #f)
                     (path "/")
                     (domain #f)
                     (secure #f)
                     (http-only #t))
  "Set a cookie in the response (call this before sending response)"
  (let* ((cookie-parts (list (string-append name "=" value)
                             (string-append "Path=" path)))
         (cookie-parts (if max-age
                          (append cookie-parts
                                  (list (string-append "Max-Age="
                                        (number->string max-age))))
                          cookie-parts))
         (cookie-parts (if domain
                          (append cookie-parts (list (string-append "Domain=" domain)))
                          cookie-parts))
         (cookie-parts (if secure
                          (append cookie-parts (list "Secure"))
                          cookie-parts))
         (cookie-parts (if http-only
                          (append cookie-parts (list "HttpOnly"))
                          cookie-parts))
         (cookie-string (string-join cookie-parts "; ")))
    (set-response-cookie! cookie-string)))

;; Simple list to accumulate cookies (no parameters)
(define response-cookies-list '())

(define (set-response-cookie! cookie)
  (set! response-cookies-list (cons cookie response-cookies-list)))

(define (get-response-cookies)
  response-cookies-list)

(define (clear-response-cookies!)
  (set! response-cookies-list '()))

;; ============================================================================
;; Session Management
;; ============================================================================
(define sessions #f)
(define session-timeout 3600) ; 1 hour

(define (ensure-sessions!)
  "Lazy initialization of sessions hash table"
  (when (not sessions)
    (set! sessions (make-hash-table equal?))))

(define-record session id data created last-access)

(define (generate-session-id)
  "Generate a random session ID"
  (let ((chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
    (list->string
     (map (lambda (_)
            (string-ref chars (pseudo-random-integer (string-length chars))))
          (iota 32)))))

(define (get-session)
  "Get current session"
  (ensure-sessions!)
  (let ((session-id (get-cookie "session-id")))
    (if session-id
        (hash-table-ref/default sessions session-id #f)
        #f)))

(define (create-session!)
  "Create a new session"
  (ensure-sessions!)
  (let* ((session-id (generate-session-id))
         (now (current-seconds))
         (session (make-session session-id (make-hash-table) now now)))
    (hash-table-set! sessions session-id session)
    (set-cookie! "session-id" session-id max-age: session-timeout http-only: #t)
    session))

(define (get-or-create-session!)
  "Get existing session or create new one"
  (or (get-session) (create-session!)))

(define (session-get key #!optional default)
  "Get value from session"
  (let ((session (get-session)))
    (if session
        (hash-table-ref/default (session-data session) key default)
        default)))

(define (session-set! key value)
  "Set value in session"
  (let ((session (get-or-create-session!)))
    (hash-table-set! (session-data session) key value)
    (session-last-access-set! session (current-seconds))))

(define (session-delete! key)
  "Delete key from session"
  (let ((session (get-session)))
    (when session
      (hash-table-delete! (session-data session) key))))

(define (destroy-session!)
  "Destroy current session"
  (ensure-sessions!)
  (let ((session-id (get-cookie "session-id")))
    (when session-id
      (hash-table-delete! sessions session-id)
      (set-cookie! "session-id" "" max-age: 0))))

(define (cleanup-sessions!)
  "Remove expired sessions"
  (ensure-sessions!)
  (let ((now (current-seconds)))
    (hash-table-walk sessions
      (lambda (id session)
        (when (> (- now (session-last-access session)) session-timeout)
          (hash-table-delete! sessions id))))))

;; ============================================================================
;; Built-in Middlewares
;; ============================================================================

(define (logging-middleware params next)
  "Log all requests"
  (let* ((req (current-request))
         (method (request-method req))
         (uri (request-uri req))
         (start (current-seconds)))
    (print "[" (time->string (seconds->local-time (current-seconds))) "] "
           method " " (uri->string uri))
    (let ((result (next params)))
      (let ((duration (- (current-seconds) start)))
        (print "  -> Completed in " duration "s"))
      result)))

(define (cors-middleware params next)
  "Add CORS headers"
  (let* ((req (current-request))
         (origin (header-value 'origin (request-headers req) "*")))
    (next params)))

(define (cookie-parser-middleware params next)
  "Parse cookies and make them available"
  (clear-response-cookies!)
  (next params))

(define (session-middleware params next)
  "Initialize session support"
  (get-or-create-session!)
  (cleanup-sessions!)
  (next params))

) ; end module
