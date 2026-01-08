(module core
  (make-route
   route-method
   route-pattern
   route-handler
   extract-params
   match-route
   send-json
   send-error
   log-error
   get-post-json)

(import scheme
        (chicken base)
        (chicken string)
        (chicken io)
        (chicken condition)
        (chicken port)
        srfi-1
        srfi-13
        spiffy
        intarweb
        uri-common
        medea)

(define-record route method pattern handler)

(define (log-error context exn)
  "Log detailed error information"
  (print "ERROR in " context ":")
  (print "  Message: " ((condition-property-accessor 'exn 'message) exn))
  (let ((location ((condition-property-accessor 'exn 'location) exn)))
    (when location
      (print "  Location: " location)))
  (let ((args ((condition-property-accessor 'exn 'arguments) exn)))
    (when args
      (print "  Arguments: " args))))

(define (get-post-json)
  "Parse JSON from POST body"
  (handle-exceptions exn
    (begin
      (log-error "get-post-json" exn)
      #f)
    (let* ((req (current-request))
           (content-length (header-value 'content-length (request-headers req) 0)))
      (if (> content-length 0)
          (read-json (read-string content-length (request-port req)))
          #f))))

(define (send-json data)
  "Send JSON response - closes connection immediately"
  (handle-exceptions exn
    (begin
      (log-error "send-json" exn)
      (send-response
        status: 'internal-server-error
        body: "JSON encoding error"))
    (let ((json-body (with-output-to-string
                       (lambda ()
                         (write-json data)))))
      (send-response
        status: 'ok
        headers: `((content-type application/json)
                   (content-length ,(string-length json-body)))
        body: json-body))))

(define (send-error status-code message)
  "Send error response - closes connection immediately"
  (send-response
    status: status-code
    headers: `((content-type text/plain)
               (content-length ,(string-length message)))
    body: message))

(define (extract-params pattern path)
  "Extract parameters from path based on pattern"
  (let loop ((pattern pattern)
             (path path)
             (params '()))
    (cond
      ((and (null? pattern) (null? path))
       (reverse params))
      ((or (null? pattern) (null? path))
       #f)
      (else
       (let ((p-seg (car pattern))
             (path-seg (car path)))
         (if (and (> (string-length p-seg) 0)
                  (char=? (string-ref p-seg 0) #\:))
             (let ((param-name (string->symbol (substring p-seg 1))))
               (loop (cdr pattern)
                     (cdr path)
                     (cons (cons param-name path-seg) params)))
             (if (string=? p-seg path-seg)
                 (loop (cdr pattern) (cdr path) params)
                 #f)))))))

(define (match-route method path routes)
  "Find matching route and extract parameters"
  (let loop ((routes routes))
    (if (null? routes)
        #f
        (let* ((route (car routes))
               (pattern (route-pattern route)))
          (if (and (eq? (route-method route) method)
                   (= (length pattern) (length path)))
              (let ((params (extract-params pattern path)))
                (if params
                    (cons route params)
                    (loop (cdr routes))))
              (loop (cdr routes)))))))

) ; end module
