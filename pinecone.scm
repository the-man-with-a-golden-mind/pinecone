(module pinecone
  (;; Core exports
   make-route
   route-method
   route-pattern
   route-handler
   extract-params
   match-route
   send-json
   send-error
   log-error
   get-post-json
   ;; SSE exports
   make-sse-manager
   sse-manager-mutex
   sse-manager-clients
   sse-manager-clients-set!
   sse-manager-register!
   sse-manager-unregister!
   sse-manager-broadcast!
   sse-manager-handler
   send-sse
   sse-comment
   ;; Middleware exports
   make-middleware
   middleware?
   middleware-handler
   middleware-name
   chain-middlewares
   logging-middleware
   cors-middleware
   cookie-parser-middleware
   session-middleware
   get-cookie
   set-cookie!
   get-session
   create-session!
   get-or-create-session!
   session-get
   session-set!
   session-delete!
   destroy-session!
   ;; App exports
   create-app
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
        (chicken module)
        core
        sse
        middleware
        app)

(reexport core)
(reexport sse)
(reexport middleware)
(reexport app)

) ; end module
