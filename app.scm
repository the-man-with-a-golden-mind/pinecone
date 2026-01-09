(module app
  (create-app
   app-routes
   app-routes-set!
   app-middlewares
   app-middlewares-set!
   app-sse-manager
   app-port
   app-root-path
   app-add-route!
   app-use!
   app-handler
   app-start!)

(import scheme
        (chicken base)
        (chicken gc)
        (chicken condition)
        srfi-1
        srfi-13
        srfi-18
        spiffy
        intarweb
        uri-common
        core
        sse
        middleware)

(define-record app routes middlewares sse-manager port root-path)

(define (create-app #!key (port 8080) (root-path "./static"))
  "Create a new Pinecone application"
  (make-app '() '() (make-sse-manager (make-mutex 'sse) '()) port root-path))

(define (app-add-route! app method pattern handler)
  "Add a route to the application"
  (app-routes-set! app
    (append (app-routes app)
            (list (make-route method pattern handler)))))

(define (app-use! app middleware)
  "Add a middleware to the application"
  (app-middlewares-set! app
    (append (app-middlewares app) (list middleware))))

(define (safe-handler handler route-name)
  "Wrap handler in error handling"
  (lambda (params)
    (handle-exceptions exn
      (begin
        (print "==============================================")
        (print "ERROR in route handler: " route-name)
        (log-error route-name exn)
        (print "Route params: " params)
        (print "==============================================")
        (send-error 'internal-server-error
                    (string-append "Error in route: " route-name)))
      (handler params))))

(define (app-handler app)
  "Create main request handler for the application"
  (lambda (continue)
    (handle-exceptions exn
      (begin
        (print "==============================================")
        (log-error "app-handler (routing)" exn)
        (print "==============================================")
        (send-error 'internal-server-error "Internal Server Error"))

      (let* ((req (current-request))
             (path-raw (uri-path (request-uri req)))
             (path (cdr path-raw))
             (method (request-method req))
             (match (match-route method path (app-routes app))))

        (if match
            (let* ((route (car match))
                   (params (cdr match))
                   (route-name (string-append
                                 (symbol->string method)
                                 " /"
                                 (string-join (route-pattern route) "/")))
                   (base-handler (safe-handler (route-handler route) route-name))
                   ;; Chain middlewares with the route handler
                   (final-handler (chain-middlewares
                                    (app-middlewares app)
                                    base-handler)))
              (print method " /" (string-join path "/") " -> matched")
              (final-handler params))
            (begin
              (print method " /" (string-join path "/") " -> static")
              (continue)))))))

(define (app-start! app)
  "Start the Pinecone application"
  (server-port (app-port app))
  (root-path (app-root-path app))
  (vhost-map `((".*" . ,(app-handler app))))
  (set-gc-report! #f)
  (gc #t)
  (print "==============================================")
  (print "🌲 Pinecone server starting on port " (app-port app))
  (print "Middlewares: " (length (app-middlewares app)))
  (print "Routes:")
  (for-each
    (lambda (r)
      (print "  " (route-method r) " /" (string-join (route-pattern r) "/")))
    (app-routes app))
  (print "==============================================")
  (start-server))

) ; end module
