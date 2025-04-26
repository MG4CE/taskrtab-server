// @title Swagger Example API
// @version 1.0

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	httpSwagger "github.com/swaggo/http-swagger"

	_ "github.com/MG4CE/taskrpad/swagger"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func verifyEnv(env ...string) error {
	for _, str := range env {
		if str == "" {
			return fmt.Errorf("failed to import an environment variable")
		}
	}
	return nil
}

func main() {
	r := chi.NewRouter()

	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})

	log.Info().Msg("Starting Server...")

	log.Info().Msg("Fetching enviroment varibles")
	//clientID := os.Getenv("GOOGLE_CLIENTID")
	// clientSecret := os.Getenv("GOOGLE_SECRET")
	// gitCollabSecret := os.Getenv("SECRET")
	//gitRedirect := os.Getenv("REACT_APP_REDIRECT_URI")
	httpPort := "" //os.Getenv("HTTP_PORT")

	// if err := verifyEnv(clientID, gitRedirect); err != nil {
	// 	log.Panic().Err(err).Msg("")
	// 	return
	// }

	// register middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(middleware.StripSlashes)

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET", "PATCH", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300, // Maximum value not ignored by any of major browsers
	}))

	// create oauth config for github
	// var GitOauthConfig = &oauth2.Config{
	// 	ClientID:     clientID,
	// 	ClientSecret: clientSecret,
	// 	Scopes:       []string{"user:email", "user:name"},
	// 	Endpoint:     githuboauth.Endpoint,
	// }

	// create gitcollab jwt conf, for midddleware
	//jwtConf := jwt.NewGitCollabJwtConf(gitCollabSecret)

	// create db drivers
	// dbDriver, err := db.NewPostgresDriver(dbUrl, logger)
	// if err != nil {
	// 	logger.Error(err)
	// 	return
	// }
	// defer dbDriver.Pool.Close()

	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		_, err := w.Write([]byte("hi from taskrpad"))
		if err != nil {
			log.Panic().Err(err).Msg("")
		}
	})

	r.Get("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, err := w.Write([]byte("pong!"))
		if err != nil {
			log.Panic().Err(err).Msg("")
		}
	})

	r.Get("/swagger/*", httpSwagger.WrapHandler)

	// register all sub routers under /api
	// r.Route("/api", func(r chi.Router) {
	// 	r.Use(middleware.AllowContentEncoding("application/json"))

	// 	// authentication subrouter
	// 	auth := authHandlers.NewAuth(dbDriver, logger, GitOauthConfig, gitRedirect, gitCollabSecret)
	// 	r.Mount("/auth", authRouter.AuthRouter(auth))

	// 	// profiles subrouter
	// 	pd := data.NewProfileData(dbDriver)
	// 	profiles := profilesHandlers.NewProfiles(logger, pd)
	// 	r.Mount("/profile", profilesRouter.ProfileRouter(profiles, jwtConf))

	// 	projectD := projectData.NewProjectData(dbDriver)
	// 	p := project.NewProjects(dbDriver, projectD, logger)
	// 	r.Mount("/project", projectsRouter.ProjectRouter(p, pd, jwtConf))

	// 	// test routes
	// 	r.Route("/test", func(r chi.Router) {
	// 		r.Use(jwt.JWTBlackList(dbDriver))
	// 		r.Get("/test-blacklist", func(w http.ResponseWriter, r *http.Request) {
	// 			_, err := w.Write([]byte("cheese"))
	// 			if err != nil {
	// 				logger.Info("Burgre King")
	// 			}
	// 		})
	// 	})
	// })

	// Start server
	if httpPort == "" {
		httpPort = ":8080"
	}

	//TODO: add debug flag condition for this
	r.Mount("/debug", middleware.Profiler())

	s := http.Server{
		Addr:         httpPort,
		Handler:      r,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second, // max time for connections using TCP Keep-Alive
	}

	go func() {
		log.Info().Msgf("Starting server on port %s", httpPort)

		err := s.ListenAndServe()
		if err != nil {
			log.Error().Msgf("Error starting server: %s\n", err)
			os.Exit(1)
		}
	}()

	// Trap interupt signal
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)

	// Block until a signal is received
	sig := <-c
	log.Info().Msgf("Got interrupt signal: %s", sig)

	// Gracefully server shutdown wait 30 seconds for any ongoing operations to complete
	// Check if the docker container is killed in away that allows for this to happen
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	err := s.Shutdown(ctx)
	if err != nil {
		log.Panic().Err(err).Msg("")
	}
}
