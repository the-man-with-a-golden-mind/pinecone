# Pinecone 🌲

### A tiny web framework for CHICKEN Scheme (SSE-first, Datastar-friendly)

**Pinecone** is a minimal, composable web framework for **CHICKEN Scheme**, designed around:

* simple routing
* explicit middleware
* built-in **Server-Sent Events (SSE)**
* optional helpers for the **Datastar** SSE protocol

---

## Features

* HTTP routing with method + path matching
* Middleware pipeline (explicit and ordered)
* Native **Server-Sent Events** support
* JSON helpers for APIs
* Optional **Datastar protocol helpers**
* Very small surface area, easy to read and extend

---

## Requirements

Pinecone is built on standard CHICKEN tooling and depends on:

* spiffy
* intarweb
* uri-common
* srfi-1
* srfi-13
* srfi-18
* srfi-69
* medea (JSON)

---

## Installation

### Install as an egg (local)

From the project directory (where `pinecone.egg` is located):

```
chicken-install -s .
```

This will compile Pinecone with `-O3` and install the exported modules.

---


## Quick Start

```
(import pinecone)

(define app
  (create-app
    #:port 8080
    #:root-path "."))

(app-add-route! app "GET" '("health")
  (lambda (req)
    (send-json 200 '((ok . #t)))))

(app-start! app)
```

Open:

```
http://localhost:8080/health
```

---

## Application Model

A Pinecone application consists of:

* a route table
* a middleware chain
* an SSE manager
* a server configuration (port, root path)

Everything is explicit and mutable by design.

---

## Routing

Routes are defined by:

* HTTP method (string)
* path pattern (list of segments)
* handler procedure

Example:

```
(app-add-route! app "GET" '("users" ":id")
  (lambda (req)
    (let ((params (extract-params req)))
      (send-json 200 params))))
```

Routing helpers live in **core.scm**.

---

## Middleware

Middleware is applied in order and wraps the handler pipeline.

```
(app-use! app my-middleware)
```

Middleware is typically used for:

* logging
* CORS
* authentication
* request decoration
* static files

Implementation lives in **middleware.scm**.

---

## Server-Sent Events (SSE)

Pinecone includes native SSE support.

Each app owns an **SSE manager** which:

* tracks connected clients
* allows broadcasting events
* is thread-safe (mutex-protected)

You can access it via:

```
(app-sse-manager app)
```

SSE primitives are implemented in **sse.scm**.

---

## Datastar (Optional)

Pinecone includes an optional **Datastar helper module**.

It provides helpers to emit Datastar-compatible SSE messages such as:

* signals
* DOM patches
* class/style updates
* teleport / replace / remove
* event dispatch

Available helpers include:

* ds-event
* ds-response
* ds-signals
* ds-elements
* ds-attributes
* ds-properties
* ds-classes
* ds-style
* ds-events
* ds-teleport
* ds-remove
* ds-replace

This logic lives in **datastar.scm** and can be installed separately via `datastar.egg`.

---

## File Layout

```
.
├── pinecone.scm      ; public umbrella module
├── core.scm          ; routing, params, JSON helpers
├── middleware.scm    ; middleware pipeline
├── sse.scm           ; Server-Sent Events manager
├── app.scm           ; application record + server startup
├── pinecone.egg      ; egg definition
│
├── datastar.scm      ; Datastar SSE helpers (optional)
└── datastar.egg
```

---

## Public API (via `(import pinecone)`)

### App

* create-app
* app-add-route!
* app-use!
* app-start!
* app-handler
* app-sse-manager

### Routing / Core

* make-route
* match-route
* extract-params
* send-json
* send-error
* get-post-json
* log-error

### SSE

* make-sse-manager
* client registration & broadcast helpers

---

## Philosophy

Pinecone is intentionally:

* small
* readable
* synchronous where possible
* explicit over clever

It is meant to be **read**, **modified**, and **embedded**, not hidden behind layers.

---

## License

MIT

---

## Status

Pinecone is stable for small services, APIs, and SSE-driven applications.
The codebase is intentionally compact and easy to audit.

Pull requests and forks are welcome.
