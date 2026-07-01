// Command hello is a tiny HTTP server (built by JOBS via the go-build plugin)
// that depends on gorilla/mux + urfave/cli/v2 and returns "hello world". It uses
// urfave/cli/v2 for its flags and slog for structured request/startup logging —
// which also makes the example exercise multi-module fetching (urfave/cli/v2
// pulls in go-md2man, blackfriday, smetrics).
package main

import (
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	"github.com/urfave/cli/v2"
)

func main() {
	app := &cli.App{
		Name:  "hello",
		Usage: "a tiny gorilla/mux HTTP server that logs with slog",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "addr",
				Aliases: []string{"a"},
				Value:   ":8080",
				Usage:   "address to listen on",
				EnvVars: []string{"HELLO_ADDR"},
			},
			&cli.StringFlag{
				Name:    "log-level",
				Value:   "info",
				Usage:   "log level: debug, info, warn, error",
				EnvVars: []string{"HELLO_LOG_LEVEL"},
			},
		},
		Action: serve,
	}
	if err := app.Run(os.Args); err != nil {
		slog.Error("exited with error", "err", err)
		os.Exit(1)
	}
}

// serve configures slog and runs the HTTP server until it errors.
func serve(c *cli.Context) error {
	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
		Level: parseLevel(c.String("log-level")),
	}))
	slog.SetDefault(logger)

	addr := c.String("addr")
	r := mux.NewRouter()
	r.Use(requestLogger)
	r.HandleFunc("/", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte("hello world\n"))
	})

	slog.Info("starting server2", "addr", addr)
	return http.ListenAndServe(addr, r)
}

// requestLogger logs one line per request: method, path, status, and duration.
func requestLogger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		start := time.Now()
		sw := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(sw, req)
		slog.Info("request",
			"method", req.Method,
			"path", req.URL.Path,
			"status", sw.status,
			"duration", time.Since(start),
			"remote", req.RemoteAddr,
		)
	})
}

// statusRecorder captures the response status code for logging.
type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func parseLevel(s string) slog.Level {
	switch s {
	case "debug":
		return slog.LevelDebug
	case "warn":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
