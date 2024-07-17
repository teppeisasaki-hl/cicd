package main

import (
	"fmt"
	"net/http"
	"os"

	"test/handlers"
	"test/models"
	"test/repositories"

	"test/api"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	db := newDB()
	r := chi.NewRouter()
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: false,
		MaxAge:           300,
	}))
	r.Get("/hc", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("healthy")) })
	r.Get("/hc/hc", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("healthy")) })
	api.HandlerFromMuxWithBaseURL(
		handlers.NewUserHandler(repositories.NewUserRepository(db)), r, "/v1",
	)
	if err := http.ListenAndServe(fmt.Sprintf(":%s", os.Getenv("PORT")), r); err != nil {
		panic(fmt.Sprintf("cannot start server / %v", err))
	}
}

func newDB() *gorm.DB {
	db, err := gorm.Open(
		postgres.Open(
			fmt.Sprintf(
				"postgres://%s:%s@%s:%s/%s",
				os.Getenv("DB_USER"),
				os.Getenv("DB_PASSWORD"),
				os.Getenv("DB_HOST"),
				os.Getenv("DB_PORT"),
				os.Getenv("DB_NAME"),
			),
		),
		&gorm.Config{},
	)

	if err != nil {
		panic(err)
	}

	if err := db.AutoMigrate(&models.User{}); err != nil {
		panic(err)
	}

	return db
}
