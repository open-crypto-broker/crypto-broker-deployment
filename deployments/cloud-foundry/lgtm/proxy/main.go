package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
)

func newProxy(target string) *httputil.ReverseProxy {
	u, err := url.Parse(target)
	if err != nil {
		log.Fatalf("invalid proxy target %q: %v", target, err)
	}
	p := httputil.NewSingleHostReverseProxy(u)
	// Return 503 while upstream is warming up instead of a raw 502
	p.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("[cf-proxy] upstream error (%s): %v", r.URL.Path, err)
		w.Header().Set("Retry-After", "10")
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprintln(w, "LGTM stack is starting up, please retry in a few seconds.")
	}
	return p
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	otlp := newProxy("http://127.0.0.1:4318")
	grafana := newProxy("http://127.0.0.1:3000")
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/v1/") {
			otlp.ServeHTTP(w, r)
		} else {
			grafana.ServeHTTP(w, r)
		}
	})
	addr := "0.0.0.0:" + port
	log.Printf("[cf-proxy] listening on %s", addr)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("[cf-proxy] fatal: %v", err)
	}
}
